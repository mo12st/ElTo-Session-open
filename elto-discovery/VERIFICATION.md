# elto-discovery - verification status

Per the governance directive, this file states exactly what was verified and
what was not. Nothing in this directory has been run by its author against a
live PackageKit, a live Arch system, a VM, or hardware.

History: v1 of this helper wrapped `pkcon`. The implementer's VM run
(2026-11-27) found Arch packagekit 1.4.1 ships only `/usr/bin/pkgcli` (no
pkcon/pkmon), so the helper was ported to pkgcli. The Arch package file list
confirms `usr/bin/pkgcli` is the sole binary (archlinux.org, 2026-11-27).

## Verified (with proof)

1. **Implemented**: `elto-discovery` (Python 3, stdlib only), `tests/run-tests.py`.
2. **Parser, JSON contract and error mapping tested**: 32 assertions pass
   against a stub `pkgcli` with recorded outputs. Output of the run in the
   author's sandbox: `all tests passed` (32 checks).
3. **Implementer VM observations incorporated** (reported 2026-11-27):
   `pkgcli --json search` prints one JSON object per package with fields
   name, version, arch, repo, state; errors print as `{"error": ...}`;
   exit 4 for not-found and 5 for the auth path; `show --json` produced
   empty output while plain `show` worked (the helper therefore falls back
   to parsing plain `show` labels when JSON yields no detail object).
   Second VM run: search/info/not-found/usage confirmed working; two bugs
   found and fixed: (a) install failed as `transaction-failed` "user
   declined simulation" because pkgcli simulates and confirms on stdin
   unless `-y` (`pkgc-context.c pkgc_context_apply_settings`, lines
   ~210-227: simulate = !noninteractive, interactive = !noninteractive);
   install/remove now pass `-y`, which leaves `only-trusted` and polkit
   untouched; (b) search returns installed entries with repo `installed`,
   so results now carry `install_id` (null for installed entries) and
   install of an installed id is an idempotent already-installed no-op.
4. **Remaining formats modeled on PackageKit v1.4.1 source**, fetched
   2026-11-27 from github.com/hughsie/PackageKit (tag v1.4.1):
   - JSON package object fields: `client/pkgc-util.c`
     `pkgc_print_package()` JSON branch (lines ~540-548);
   - JSON detail object fields: `pkgc_print_package_detail()` JSON branch
     (lines ~612-634); plain-mode labels (`Package:`, `Summary:`, ...) in
     the same function's non-JSON branch (lines ~636-710);
   - error/warning/info/success JSON shapes `{"error":...}` etc.:
     `pkgc_print_error/warning/info/success` (lines ~256-370);
   - no progress output in JSON mode: `client/pkgc-context.c`
     `pkgc_context_on_progress_cb` early return for PKGCLI_MODE_JSON
     (lines ~306-316);
   - exit codes 0/1/2/3/4/5: `client/pkgc-context.h` lines 32-37;
   - install: name resolution with ARCH+NOT_SOURCE+NEWEST+NOT_INSTALLED
     filters, "Could not find any available package" exit 4, already
     installed -> `{"info": ...}` exit 0: `client/pkgc-manage.c`
     `pkgc_install()` (lines ~239-355); remove: INSTALLED filter,
     "Could not find installed packages" exit 1: `pkgc_remove()`
     (lines ~357-417); transaction failure -> `{"error": ...}` exit 5:
     `pkgc_manage_on_task_finished_cb()` (lines ~122-172);
   - full package IDs skip interactive resolution
     (`pk_package_id_check`): `pkgc-util.c` `pkgc_resolve_package()`
     (lines ~1104-1120); the multiple-match path prompts via scanf on
     stdin, which is why stdin is closed and bare names are refused;
   - SIGINT cancels the transaction via the cancellable:
     `client/pkgcli.c` `pkc_handle_sigint()` (lines ~42-56);
   - backend selftest object: `client/pkgc-query.c` `pkgc_backend_info()`
     JSON branch (lines ~184-204).

## NOT verified

- **Not launched against real pkgcli.** Apart from the implementer's
  observations above, no live pkgcli output has been parsed by this code.
- **Not functionally tested**: no real search, show, install, or remove ran
  against this helper.
- **Not tested in a session, VM, or hardware.**
- Install success is unproven until the polkit decision (with the user).
- Exact error wording for each real failure (offline, polkit denial, polkit
  cancel, missing daemon, GPG key prompt) is unconfirmed; `classify_error()`
  patterns are educated mappings that the VM test must confirm or correct.
- Why `show --json` was empty on the VM is unexplained; the helper treats it
  as a possible outcome and falls back to plain `show`. The VM test should
  note whether the JSON or plain path gets used.
- On-disk state after a mid-install SIGKILL (post-grace) is untested.

## VM test list (for the implementer)

1. `pacman -S packagekit` if the base image lacks it.
2. `./elto-discovery selftest` -> expect `done.ok == true` with
   `backend.name == "alpm"`. Failure here means the daemon/activation path
   is broken.
3. `./elto-discovery search firefox` -> expect results including `firefox`
   with repo `extra`, correct version/arch, status `available`. Compare raw
   `pkgcli --json search name firefox` side by side (fields, one object per
   line).
4. `./elto-discovery info <full-id-from-search>` -> expect summary,
   description, license, sizes, url. Record whether `_source` is `json` or
   `plain` (see the `show --json` note above).
5. `./elto-discovery install <full-id of a small package, e.g. sl>` as the
   regular session user. Expect no more "user declined simulation": `-y`
   skips pkgcli's own confirmation. Record exactly what polkit does:
   allowed without prompt, prompted (which agent answered?), or denied.
   Decision input for the Core track (polkit agent/rule in the session).
5b. `./elto-discovery search firefox` entries with status `installed`
   (after step 5) must have `install_id: null`; installing an installed id
   returns ok with note `already-installed`.
6. `./elto-discovery remove <same id>` -> expect success.
7. `./elto-discovery install nope;0-1;x86_64;extra` -> expect
   `error.code == "not-found"` (pkgcli exit 4, observed on the VM).
8. `./elto-discovery remove nope;0-1;x86_64;installed` -> expect
   `error.code == "not-found"` (pkgcli exit 1 with "Could not find
   installed packages" wording).
9. Network down: `search` should still succeed from the local pacman db;
   `install` should fail with a clean error JSON (record the mapped code).
10. Cancel/deny the polkit prompt during step 5 -> record the actual pkgcli
    wording and the mapped code (`cancelled` / `not-authorized`).
11. `pkgcli` absent (simulate by PATH): `selftest` -> `cli-missing`.

Report each step's raw output as proof; update this file's levels after the
run.
