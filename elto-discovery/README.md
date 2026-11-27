# elto-discovery (Phase 1 spike)

ElTo Discovery: find and install apps on the ElTo base system. Phase 1 is this
helper only: a machine-facing CLI over PackageKit's pacman (alpm) backend, via
`pkgcli` (the only CLI Arch's packagekit 1.4.1 ships: `/usr/bin/pkgcli`). The
ElTo shell spawns one process per operation and reads JSON Lines from stdout;
nothing runs in the background, no daemon, no state.

Approved scope (2026-11-27): pacman via PackageKit only. Flatpak/Flathub is a
separate later decision. Worlds land after the World Engine schema is approved.
Extensions are deferred until a concrete use case exists.

## Dependencies

- `packagekit` (provides `/usr/bin/pkgcli` and the alpm backend; Arch `extra`)
- `python3` (stdlib only)
- polkit for install/remove authorization, through PackageKit itself. Which
  agent answers prompts in the ElTo session is an open decision being taken to
  the user (see VERIFICATION.md).

## Usage

```
elto-discovery search <text>            # find packages by name
elto-discovery info <package-id>        # details for one package
elto-discovery install <package-id>     # install
elto-discovery remove <package-id>      # remove
elto-discovery selftest                 # pkgcli + daemon availability
```

`<package-id>` is the full PackageKit ID assembled from a search result's
fields: `name;version;arch;data` (e.g. `vim;9.1.190-1;x86_64;extra`). Full IDs
are required for install/remove: pkgcli resolves bare names with an interactive
multiple-match prompt on stdin, and this helper deliberately closes stdin.

pkgcli search returns installed entries too (repo `installed`). Each result
carries `install_id`: the id to pass to `install`, or `null` when the entry
is already installed. The UI must use `install_id`, never an installed
entry's `id`. Installing an installed id is an idempotent no-op that returns
`done.ok` with `"note": "already-installed"` (installed ids are exactly
what `remove` expects).

install/remove run pkgcli with `-y` (non-interactive): without it pkgcli
simulates the transaction and asks for confirmation on stdin, which we
close, and the VM run showed that ending as `transaction-failed` with
"user declined simulation". `-y` skips pkgcli's own confirmation only;
`only-trusted` stays on and polkit authorization is unaffected.

## Output contract

One JSON object per line on stdout; the last line is always a `done` event.
stderr carries human diagnostics only.

search:

```
{"event": "results", "query": "vim", "results": [{"id": "vim;9.1.190-1;x86_64;extra", "name": "vim", "version": "9.1.190-1", "arch": "x86_64", "repo": "extra", "status": "available"}, ...]}
{"event": "done", "ok": true, "count": 4}
```

Note: pkgcli's JSON package object carries no summary (name, version, arch,
repo, state only), so search results have no summary in Phase 1. `info`
returns the summary, description, license, sizes and url for one package.
If `show --json` yields no detail object (observed on the VM once), `info`
falls back to parsing plain `pkgcli show` output and marks the result with
`"_source": "plain"`.

info:

```
{"event": "info", "info": {"name": "vim", "version": "9.1.190-1", "summary": "...", "description": "...", "license": "...", "url": "...", "install_size": 4194304, "download_size": 2306867, "_source": "json", "status": "available", "id": "vim;9.1.190-1;x86_64;extra"}}
{"event": "done", "ok": true}
```

install / remove:

```
{"event": "package", "package": {"id": "sl;5.05-3;x86_64;installed", "name": "sl", ..., "status": "installed"}}
{"event": "done", "ok": true, "command": "install", "package": "sl;5.05-3;x86_64;extra"}
```

pkgcli emits no progress events in JSON mode (its progress callback returns
early), so install/remove stream only the processed-package objects pkgcli
prints at the end, plus `info`/`warning`/`success` passthrough events. There
are no `progress`/`status` percentage events in Phase 1; a mid-transaction
progress bar is a later UI decision (e.g. `pkgcli monitor` or D-Bus).

failure:

```
{"event": "done", "ok": false, "error": {"code": "cancelled", "message": "The transaction was cancelled by the user."}}
```

Error codes: `usage`, `cli-missing`, `daemon-error`, `not-found`,
`cancelled`, `not-authorized`, `transaction-failed`, `timeout`,
`parse-error`, `cli-error` (fallback). The raw pkgcli message is always kept
in `message`. Codes map from pkgcli's exit codes (3 permission, 4 not-found,
5 transaction-failed; the 4 and 5 paths were observed live on the VM) and
message wording; exact wording per real failure is confirmed in the VM test.

Exit codes: 0 success, 1 operational error, 2 usage error. The JSON `done.ok`
flag is the primary signal; exit codes are for shell scripting.

## Safety properties

- `-y` is passed only for install/remove and only suppresses pkgcli's own
  confirmation/simulation; signature trust (`only-trusted`) and polkit
  authorization still apply.
- stdin is closed for every pkgcli call: pkgcli can never block on a prompt.
- pkgcli runs with `LC_ALL=C` and `--no-color` (+ `NO_COLOR=1`): parsing does
  not depend on locale or color codes.
- install/remove refuse bare package names (see above).
- pkgcli runs in its own process group; on Ctrl-C the helper SIGINTs the
  group first (pkgcli's own handler cancels the PackageKit transaction
  properly) and only SIGKILLs after a 10s grace. On-disk state after a hard
  kill is a VM-test item.
- No downloads from anywhere except the configured pacman repos, via
  PackageKit. No `curl | sh`. Root authorization goes through polkit only.

## Tests

```
python3 tests/run-tests.py
```

Runs the helper against a stub `pkgcli` with recorded outputs. This verifies
our parsing, JSON contract and error mapping (29 checks). It does not verify
real pkgcli behavior beyond what the implementer's VM run already observed;
see VERIFICATION.md for the honest verification level and the VM test list.
