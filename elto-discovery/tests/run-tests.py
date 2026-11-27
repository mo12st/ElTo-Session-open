#!/usr/bin/env python3
"""Tests for elto-discovery's pkgcli parsing and error mapping.

Runs the helper against a stub `pkgcli` placed first on PATH. The stub prints
recorded outputs whose formats are modeled on PackageKit v1.4.1 client source
(pkgc-util.c / pkgc-context.c / pkgc-manage.c; see VERIFICATION.md for the
exact source lines). The search JSON shape, the {"error":...} shape and the
exit codes 4/5 were additionally observed live by the implementer's VM run.
These tests verify OUR parsing and exit behavior only. They do NOT verify
that real pkgcli output matches the fixtures: that is the VM test's job.

Run: python3 tests/run-tests.py   (from the elto-discovery/ directory)
Exit 0 = all passed.
"""

import json
import os
import stat
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "elto-discovery")

# --- stub pkgcli fixtures -------------------------------------------------
# Formats: PackageKit v1.4.1
#  - package object (pkgc-util.c pkgc_print_package, JSON branch):
#    {"name","version","arch","repo","state"}, one compact JSON per line
#  - detail object (pkgc_print_package_detail, JSON branch):
#    {"name","version","summary","description","license","url",
#     "install_size","download_size"}
#  - errors (pkgc_print_error): {"error": "..."} on stdout
#  - exit codes (pkgc-context.h): 1 failure, 2 syntax, 3 permission,
#    4 not-found, 5 transaction-failed
#  - JSON mode emits no progress (pkgc-context.c on_progress_cb early return)
#  - plain show labels (pkgc_print_package_detail, non-JSON branch)

SEARCH_OUT = """\
{"name":"vim","version":"9.1.190-1","arch":"x86_64","repo":"extra","state":"available"}
{"name":"flatpak","version":"1:1.18.6-1","arch":"x86_64","repo":"extra","state":"installed"}
{"name":"lib32-glibc","version":"2.40+r123+gc567890-1","arch":"x86_64","repo":"core","state":"available"}
{"name":"python","version":"3.14.0-1","arch":"x86_64","repo":"extra","state":"available"}
"""

SEARCH_EMPTY_OUT = ""

SHOW_JSON_OUT = """\
{"name":"vim","version":"9.1.190-1","arch":"x86_64","repo":"extra","state":"available"}
{"name":"vim","version":"9.1.190-1","summary":"Vi Improved, a highly configurable, improved version of the vi text editor","description":"Vim is an advanced text editor that seeks to provide the power of the de-facto Unix editor","license":"custom:vim","url":"https://www.vim.org","install_size":4194304,"download_size":2306867}
"""

SHOW_PLAIN_OUT = """\
Package: vim
Version: 9.1.190-1
Summary: Vi Improved, a highly configurable, improved version of the vi text editor
Description: Vim is an advanced text editor that seeks to provide the power of the de-facto Unix editor
License: custom:vim
URL: https://www.vim.org
Group: editors
Installed Size: 4.0 MiB
Download Size: 2.2 MiB
"""

INSTALL_OK_OUT = """\
{"name":"sl","version":"5.05-3","arch":"x86_64","repo":"extra","state":"installing"}
{"name":"sl","version":"5.05-3","arch":"x86_64","repo":"installed","state":"installed"}
"""

INSTALL_ALREADY_OUT = """\
{"info":"The selected package is already installed."}
"""

INSTALL_NOT_FOUND_ERR = "Could not find any available package: No packages were found"

INSTALL_CANCELLED_ERR = "The transaction was cancelled by the user."

INSTALL_AUTH_ERR = "Polkit authorization failed: not authorized"

REMOVE_NOT_FOUND_ERR = "Could not find installed packages: No packages were found"

SEARCH_DAEMON_ERR = "Failed to connect to PackageKit: Could not activate remote peer"

BACKEND_OUT = """\
{"backend":{"name":"alpm","description":"Arch Linux Package Management (ALPM) backend","author":"..."},"roles":"search-name;install-packages;remove-packages"}
"""

STUB = r"""#!/bin/sh
# stub pkgcli: prints fixtures by argument signature. The helper always calls
# 'pkgcli --json --no-color <cmd> ...' except the plain-show fallback.
case "$*" in
  "--json --no-color search name vim") cat <<'EOF'
@SEARCH_OUT@EOF
    exit 0;;
  "--json --no-color search name zzz-nothing") exit 0;;
  "--json --no-color search name daemonfail")
    printf '%s\n' '{"error":"@SEARCH_DAEMON_ERR@"}'
    exit 1;;
  "--json --no-color show vim;9.1.190-1;x86_64;extra") cat <<'EOF'
@SHOW_JSON_OUT@EOF
    exit 0;;
  "--json --no-color show plainpkg;1-1;x86_64;extra") exit 0;;  # empty, as the VM saw
  "--no-color show plainpkg;1-1;x86_64;extra") cat <<'EOF'
@SHOW_PLAIN_OUT@EOF
    exit 0;;
  "--json --no-color show nope;1-1;x86_64;extra")
    printf '%s\n' '{"error":"Could not find packages: No packages were found"}'
    exit 1;;
  "--json --no-color -y install sl;5.05-3;x86_64;extra") cat <<'EOF'
@INSTALL_OK_OUT@EOF
    exit 0;;
  "--json --no-color -y install installed-pkg;1-1;x86_64;extra")
    printf '%s\n' '{"info":"The selected package is already installed."}'
    exit 0;;
  "--json --no-color -y install nope;0-1;x86_64;extra")
    printf '%s\n' '{"error":"@INSTALL_NOT_FOUND_ERR@"}'
    exit 4;;
  "--json --no-color -y install bad;1-1;x86_64;extra")
    printf '%s\n' '{"error":"@INSTALL_CANCELLED_ERR@"}'
    exit 5;;
  "--json --no-color -y install denied;1-1;x86_64;extra")
    printf '%s\n' '{"error":"@INSTALL_AUTH_ERR@"}'
    exit 5;;
  "--json --no-color -y remove nope;0-1;x86_64;installed")
    printf '%s\n' '{"error":"@REMOVE_NOT_FOUND_ERR@"}'
    exit 1;;
  "--json --no-color backend") cat <<'EOF'
@BACKEND_OUT@EOF
    exit 0;;
  *) echo "stub pkgcli: unhandled args: $*" >&2; exit 42;;
esac
"""


def write_stub(dirpath):
    body = STUB
    for token, fixture in [
        ("@SEARCH_OUT@", SEARCH_OUT),
        ("@SEARCH_DAEMON_ERR@", SEARCH_DAEMON_ERR),
        ("@SHOW_JSON_OUT@", SHOW_JSON_OUT),
        ("@SHOW_PLAIN_OUT@", SHOW_PLAIN_OUT),
        ("@INSTALL_OK_OUT@", INSTALL_OK_OUT),
        ("@INSTALL_NOT_FOUND_ERR@", INSTALL_NOT_FOUND_ERR),
        ("@INSTALL_CANCELLED_ERR@", INSTALL_CANCELLED_ERR),
        ("@INSTALL_AUTH_ERR@", INSTALL_AUTH_ERR),
        ("@REMOVE_NOT_FOUND_ERR@", REMOVE_NOT_FOUND_ERR),
        ("@BACKEND_OUT@", BACKEND_OUT),
    ]:
        body = body.replace(token, fixture)
    path = os.path.join(dirpath, "pkgcli")
    with open(path, "w") as f:
        f.write(body)
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP
             | stat.S_IXOTH)
    return path


def run_helper(env, *args, expect_exit=None):
    proc = subprocess.run(
        [sys.executable, HELPER] + list(args),
        capture_output=True, text=True, env=env)
    events = []
    for line in proc.stdout.splitlines():
        events.append(json.loads(line))
    assert events, "no JSON output for %r (stderr: %s)" % (args, proc.stderr)
    assert events[-1]["event"] == "done", "last event must be done: %r" % args
    if expect_exit is not None:
        assert proc.returncode == expect_exit, (
            "%r exit %d != %d (stderr: %s)"
            % (args, proc.returncode, expect_exit, proc.stderr))
    return events, proc


FAILURES = []


def check(label, cond, detail=""):
    if cond:
        print("ok   - %s" % label)
    else:
        FAILURES.append(label)
        print("FAIL - %s  %s" % (label, detail))


def main():
    tmp = tempfile.mkdtemp(prefix="elto-discovery-test-")
    write_stub(tmp)
    env = dict(os.environ)
    env["PATH"] = tmp + os.pathsep + env.get("PATH", "")

    # search: results parsing
    events, _ = run_helper(env, "search", "vim", expect_exit=0)
    check("search returns results event", events[0]["event"] == "results")
    results = events[0]["results"]
    check("search parses 4 packages", len(results) == 4, repr(results))
    by_name = {r["name"]: r for r in results}
    vim = by_name.get("vim", {})
    check("vim id assembled", vim.get("id") == "vim;9.1.190-1;x86_64;extra",
          repr(vim))
    check("vim status available", vim.get("status") == "available")
    check("vim version", vim.get("version") == "9.1.190-1")
    check("flatpak epoch version", by_name.get("flatpak", {}).get("version")
          == "1:1.18.6-1", repr(by_name.get("flatpak")))
    check("flatpak installed via state",
          by_name.get("flatpak", {}).get("status") == "installed")
    check("dashed name parsed", by_name.get("lib32-glibc", {}).get("version")
          == "2.40+r123+gc567890-1", repr(by_name.get("lib32-glibc")))
    check("available entry has install_id",
          vim.get("install_id") == "vim;9.1.190-1;x86_64;extra", repr(vim))
    check("installed entry has no install_id",
          by_name.get("flatpak", {}).get("install_id") is None,
          repr(by_name.get("flatpak")))

    # search: empty
    events, _ = run_helper(env, "search", "zzz-nothing", expect_exit=0)
    check("empty search ok with 0 results",
          events[-1]["ok"] is True and events[-1]["count"] == 0)

    # search: daemon failure mapping ({"error":...} + exit 1)
    events, _ = run_helper(env, "search", "daemonfail", expect_exit=1)
    check("daemon error mapped", events[-1]["error"]["code"] == "daemon-error",
          repr(events[-1]))

    # info: JSON details parsing
    events, _ = run_helper(env, "info", "vim;9.1.190-1;x86_64;extra",
                           expect_exit=0)
    info = events[0]["info"]
    check("info summary parsed", info.get("summary", "").startswith("Vi Improved"),
          repr(info))
    check("info url parsed", info.get("url") == "https://www.vim.org")
    check("info status available", info.get("status") == "available")
    check("info source json", info.get("_source") == "json")

    # info: empty JSON falls back to plain show (the VM-observed case)
    events, _ = run_helper(env, "info", "plainpkg;1-1;x86_64;extra",
                           expect_exit=0)
    info = events[0]["info"]
    check("info plain fallback used", info.get("_source") == "plain", repr(info))
    check("info plain summary parsed",
          info.get("summary", "").startswith("Vi Improved"), repr(info))

    # info: not found ({"error":...} + exit 1, "Could not find packages")
    events, _ = run_helper(env, "info", "nope;1-1;x86_64;extra", expect_exit=1)
    check("info not-found mapped", events[-1]["error"]["code"] == "not-found",
          repr(events[-1]))

    # install: success with package events, no progress events in JSON mode
    events, _ = run_helper(env, "install", "sl;5.05-3;x86_64;extra",
                           expect_exit=0)
    kinds = [e["event"] for e in events]
    check("install streams package events", "package" in kinds, repr(kinds))
    check("install emits no progress events (pkgcli JSON mode)",
          "progress" not in kinds and "status" not in kinds, repr(kinds))
    check("install done ok", events[-1]["ok"] is True)

    # install: already installed is success with an info message
    events, _ = run_helper(env, "install", "installed-pkg;1-1;x86_64;extra",
                           expect_exit=0)
    check("already-installed is ok with info event",
          events[-1]["ok"] is True and events[0]["event"] == "info",
          repr(events))

    # install: not found (exit 4)
    events, _ = run_helper(env, "install", "nope;0-1;x86_64;extra",
                           expect_exit=1)
    check("install not-found mapped (exit 4)",
          events[-1]["error"]["code"] == "not-found", repr(events[-1]))

    # install: cancelled (exit 5 + cancel wording)
    events, _ = run_helper(env, "install", "bad;1-1;x86_64;extra",
                           expect_exit=1)
    check("cancel mapped", events[-1]["error"]["code"] == "cancelled",
          repr(events[-1]))

    # install: polkit denial (exit 5 + auth wording, as observed on the VM)
    events, _ = run_helper(env, "install", "denied;1-1;x86_64;extra",
                           expect_exit=1)
    check("not-authorized mapped",
          events[-1]["error"]["code"] == "not-authorized", repr(events[-1]))

    # remove: not-installed failure (exit 1 + wording) maps to not-found
    events, _ = run_helper(env, "remove", "nope;0-1;x86_64;installed",
                           expect_exit=1)
    check("remove not-found mapped", events[-1]["error"]["code"] == "not-found",
          repr(events[-1]))

    # install: bare name refused before touching pkgcli
    events, _ = run_helper(env, "install", "sl", expect_exit=2)
    check("bare name refused with usage",
          events[-1]["error"]["code"] == "usage", repr(events[-1]))

    # install: an installed repo id is an idempotent no-op (no pkgcli call:
    # the stub has no matching pattern and would exit 42)
    events, _ = run_helper(env, "install", "vim;9.1.190-1;x86_64;installed",
                           expect_exit=0)
    check("installed id is already-installed no-op",
          events[-1]["ok"] is True
          and events[-1].get("note") == "already-installed", repr(events[-1]))

    # selftest against stub
    events, _ = run_helper(env, "selftest", expect_exit=0)
    check("selftest ok", events[-1]["ok"] is True
          and events[0]["info"].get("backend", {}).get("name") == "alpm",
          repr(events))

    # selftest with pkgcli missing entirely
    env2 = dict(env)
    env2["PATH"] = "/nonexistent-only"
    events, _ = run_helper(env2, "selftest", expect_exit=1)
    check("selftest cli-missing", events[-1]["error"]["code"] == "cli-missing",
          repr(events[-1]))

    # usage
    events, _ = run_helper(env, expect_exit=2)
    check("no args is usage error", events[-1]["error"]["code"] == "usage")

    print()
    if FAILURES:
        print("%d FAILURES: %s" % (len(FAILURES), ", ".join(FAILURES)))
        return 1
    print("all tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
