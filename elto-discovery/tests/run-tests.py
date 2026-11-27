#!/usr/bin/env python3
"""Tests for elto-discovery's pkcon parsing and error mapping.

Runs the helper against a stub `pkcon` placed first on PATH. The stub prints
recorded outputs whose line formats are modeled on PackageKit v1.4.1
client/pkcon/pk-console.c (see VERIFICATION.md for the exact source lines).
These tests verify OUR parsing and exit behavior only. They do NOT verify that
real pkcon output matches the fixtures: that is the VM test's job.

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

# --- stub pkcon fixtures -------------------------------------------------
# Formats: pk-console.c v1.4.1
#  - package line (non-console): "%s %s\n", info word padded to 12, then
#    "name-version.arch (data)"                        (lines ~114-126)
#  - progress: "Transaction:\t", "Package:\t", "Percentage:\t", "Status: \t"
#                                                       (lines ~603, ~619, ~636, ~661)
#  - error: "The transaction failed: <enum>, <details>" (line ~734)
#  - get-details block                                 (lines ~510-520)
# Info words are LC_ALL=C English: Available / Installed.

SEARCH_OUT = """\
Transaction:\tsearch-name
Status: \tQuery
Percentage:\t10
Percentage:\t50
Percentage:\t100
Results:
Available    vim-9.1.190-1.x86_64 (extra)
Installed    flatpak-1:1.18.6-1.x86_64 (extra)
Available    lib32-glibc-2.40+r123+gc567890-1.x86_64 (core)
Available    python-3.14.0-1.x86_64 (extra)
"""

SEARCH_EMPTY_OUT = """\
Transaction:\tsearch-name
Status: \tQuery
Results:
"""

DETAILS_OUT = """\
Transaction:\tget-details
Status: \tQuery
Results:
Package description
  package:       vim-9.1.190-1.x86_64 (extra)
  summary:       Vi Improved, a highly configurable, improved version of the vi text editor
  license:       custom:vim
  group:         editors
  download size: 2.3 megabytes
  size:          4.1 megabytes
  url:           https://www.vim.org
  description:   Vim is an advanced text editor that seeks to provide the power of the de-facto Unix editor
"""

INSTALL_OK_OUT = """\
Transaction:\tinstall-packages
Status: \tResolving dependencies
Package:\tsl-5.05-3.x86_64 (extra)
Status: \tDownloading
Percentage:\t10
Percentage:\t90
Percentage:\t100
Status: \tInstalling
Status: \tFinished
Results:
"""

INSTALL_CANCELLED_OUT = """\
Transaction:\tinstall-packages
Status: \tWaiting for authentication
The transaction failed: transaction-cancelled, The transaction was cancelled
"""

INSTALL_NOT_AUTH_OUT = """\
Transaction:\tinstall-packages
The transaction failed: not-authorized, Polkit authorization failed
"""

SEARCH_DAEMON_ERR_OUT = """\
Command failed: Could not activate remote peer: activation request failed
"""

STUB = """#!/bin/sh
# stub pkcon: prints fixtures by argument signature
case "$*" in
  "--plain search name vim") cat <<'EOF'\n%sEOF
    exit 0;;
  "--plain search name zzz-nothing") cat <<'EOF'\n%sEOF
    exit 0;;
  "--plain get-details vim;9.1.190-1;x86_64;extra") cat <<'EOF'\n%sEOF
    exit 0;;
  "--plain get-details nope;1-1;x86_64;extra")
    echo "Command failed: could not find nope;1-1;x86_64;extra"
    exit 1;;
  "--plain install sl;5.05-3;x86_64;extra") cat <<'EOF'\n%sEOF
    exit 0;;
  "--plain install bad;1-1;x86_64;extra") cat <<'EOF'\n%sEOF
    exit 7;;
  "--plain install denied;1-1;x86_64;extra") cat <<'EOF'\n%sEOF
    exit 7;;
  "--plain search name daemonfail") cat <<'EOF'\n%sEOF
    exit 1;;
  "--plain backend-details")
    echo "Backend:"
    echo "  name:           alpm"
    exit 0;;
  *) echo "stub pkcon: unhandled args: $*" >&2; exit 42;;
esac
"""


def write_stub(dirpath):
    body = STUB % (
        SEARCH_OUT, SEARCH_EMPTY_OUT, DETAILS_OUT, INSTALL_OK_OUT,
        INSTALL_CANCELLED_OUT, INSTALL_NOT_AUTH_OUT, SEARCH_DAEMON_ERR_OUT,
    )
    path = os.path.join(dirpath, "pkcon")
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
    results = events[0]["results"]
    check("search returns results event", events[0]["event"] == "results")
    check("search parses 4 packages", len(results) == 4, repr(results))
    by_name = {r["name"]: r for r in results}
    vim = by_name.get("vim", {})
    check("vim id assembled", vim.get("id") == "vim;9.1.190-1;x86_64;extra",
          repr(vim))
    check("vim status available", vim.get("status") == "available")
    check("vim version", vim.get("version") == "9.1.190-1")
    check("flatpak epoch version", by_name.get("flatpak", {}).get("version")
          == "1:1.18.6-1", repr(by_name.get("flatpak")))
    check("flatpak installed via word", by_name.get("flatpak", {}).get("status")
          == "installed")
    check("dashed name parsed", by_name.get("lib32-glibc", {}).get("version")
          == "2.40+r123+gc567890-1", repr(by_name.get("lib32-glibc")))

    # search: empty
    events, _ = run_helper(env, "search", "zzz-nothing", expect_exit=0)
    check("empty search ok with 0 results",
          events[-1]["ok"] is True and events[-1]["count"] == 0)

    # search: daemon failure mapping
    events, _ = run_helper(env, "search", "daemonfail", expect_exit=1)
    check("daemon error mapped", events[-1]["error"]["code"] == "daemon-error",
          repr(events[-1]))

    # info: details parsing
    events, _ = run_helper(env, "info", "vim;9.1.190-1;x86_64;extra",
                           expect_exit=0)
    info = events[0]["info"]
    check("info summary parsed", info.get("summary", "").startswith("Vi Improved"),
          repr(info))
    check("info url parsed", info.get("url") == "https://www.vim.org")
    check("info status available", info.get("status") == "available")

    # info: not found
    events, _ = run_helper(env, "info", "nope;1-1;x86_64;extra", expect_exit=1)
    check("info not-found mapped", events[-1]["error"]["code"] == "not-found",
          repr(events[-1]))

    # install: success with progress events
    events, _ = run_helper(env, "install", "sl;5.05-3;x86_64;extra",
                           expect_exit=0)
    kinds = [e["event"] for e in events]
    check("install streams progress",
          "progress" in kinds and "status" in kinds and "package" in kinds,
          repr(kinds))
    percents = [e["percent"] for e in events if e["event"] == "progress"]
    check("install percents parsed", percents == [10, 90, 100], repr(percents))
    check("install done ok", events[-1]["ok"] is True)

    # install: cancelled
    events, _ = run_helper(env, "install", "bad;1-1;x86_64;extra",
                           expect_exit=1)
    check("cancel mapped", events[-1]["error"]["code"] == "cancelled",
          repr(events[-1]))

    # install: not authorized (polkit denial)
    events, _ = run_helper(env, "install", "denied;1-1;x86_64;extra",
                           expect_exit=1)
    check("not-authorized mapped",
          events[-1]["error"]["code"] == "not-authorized", repr(events[-1]))

    # install: bare name refused before touching pkcon
    events, _ = run_helper(env, "install", "sl", expect_exit=2)
    check("bare name refused with usage",
          events[-1]["error"]["code"] == "usage", repr(events[-1]))

    # selftest against stub
    events, _ = run_helper(env, "selftest", expect_exit=0)
    check("selftest ok", events[-1]["ok"] is True
          and events[0]["info"]["pkcon_path"].endswith("pkcon"))

    # selftest with pkcon missing entirely
    env2 = dict(env)
    env2["PATH"] = os.pathsep.join(
        p for p in env["PATH"].split(os.pathsep) if p != tmp) or "/nonexistent"
    env2["PATH"] = "/nonexistent-only"
    events, _ = run_helper(env2, "selftest", expect_exit=1)
    check("selftest pkcon-missing", events[-1]["error"]["code"]
          == "pkcon-missing", repr(events[-1]))

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
