# elto-discovery (Phase 1 spike)

ElTo Discovery: find and install apps on the ElTo base system. Phase 1 is this
helper only: a machine-facing CLI over PackageKit's pacman (alpm) backend, via
`pkcon`. The ElTo shell spawns one process per operation and reads JSON Lines
from stdout; nothing runs in the background, no daemon, no state.

Approved scope (2026-11-27): pacman via PackageKit only. Flatpak/Flathub is a
separate later decision. Worlds land after the World Engine schema is approved.
Extensions are deferred until a concrete use case exists.

## Dependencies

- `packagekit` (provides `pkcon` and the alpm backend; Arch `extra`)
- `python3` (stdlib only)
- polkit for install/remove authorization, through PackageKit itself. Which
  agent answers prompts in the ElTo session is an open VM-test item (see
  VERIFICATION.md).

## Usage

```
elto-discovery search <text>            # find packages by name
elto-discovery info <package-id>        # details for one package
elto-discovery install <package-id>     # install, streaming progress
elto-discovery remove <package-id>      # remove, streaming progress
elto-discovery selftest                 # pkcon + daemon availability
```

`<package-id>` is the full PackageKit ID from a search result's `id` field:
`name;version;arch;data` (e.g. `vim;9.1.190-1;x86_64;extra`). Full IDs are
required for install/remove: pkcon resolves bare names with an interactive
prompt on stdin, and this helper deliberately closes stdin.

## Output contract

One JSON object per line on stdout; the last line is always a `done` event.
stderr carries human diagnostics only.

search:

```
{"event": "results", "query": "vim", "results": [{"id": "vim;9.1.190-1;x86_64;extra", "name": "vim", "version": "9.1.190-1", "arch": "x86_64", "repo": "extra", "status": "available"}, ...]}
{"event": "done", "ok": true, "count": 4}
```

Note: pkcon does not print package summaries in non-console (piped) mode, so
search results carry no summary in Phase 1. `info` returns the summary,
license, sizes, url and full description for one package.

info:

```
{"event": "info", "info": {"package": "vim-9.1.190-1.x86_64 (extra)", "summary": "...", "license": "...", "group": "...", "download_size": "...", "size": "...", "url": "...", "description": "...", "status": "available", "id": "vim;9.1.190-1;x86_64;extra"}}
{"event": "done", "ok": true}
```

install / remove:

```
{"event": "transaction", "role": "install-packages"}
{"event": "status", "status": "Downloading"}
{"event": "package", "package": "sl-5.05-3.x86_64 (extra)"}
{"event": "progress", "percent": 90}
{"event": "done", "ok": true, "command": "install", "package": "sl;5.05-3;x86_64;extra"}
```

failure:

```
{"event": "done", "ok": false, "error": {"code": "cancelled", "message": "The transaction failed: transaction-cancelled, The transaction was cancelled"}}
```

Error codes: `usage`, `pkcon-missing`, `daemon-error`, `not-found`,
`cancelled`, `not-authorized`, `transaction-failed`, `timeout`,
`parse-error`, `pkcon-error` (fallback). The raw pkcon message is always kept
in `message`. Codes are mapped from pkcon's documented output formats; the
exact wording per real failure is confirmed in the VM test.

Exit codes: 0 success, 1 operational error, 2 usage error. The JSON `done.ok`
flag is the primary signal; exit codes are for shell scripting.

## Safety properties

- stdin is closed for every pkcon call: pkcon can never block on a prompt.
- pkcon runs with `LC_ALL=C`: output parsing does not depend on locale.
- install/remove refuse bare package names (see above).
- pkcon runs in its own process group; Ctrl-C / SIGTERM to the helper kills
  the whole group (exact on-disk transaction state after a mid-install kill is
  a VM-test item).
- No downloads from anywhere except the configured pacman repos, via
  PackageKit. No `curl | sh`. Root authorization goes through polkit only.

## Tests

```
python3 tests/run-tests.py
```

Runs the helper against a stub `pkcon` with recorded outputs. This verifies
our parsing, JSON contract and error mapping. It does not verify real pkcon
behavior; see VERIFICATION.md for the honest verification level and the VM
test list.
