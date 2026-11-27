# elto-discovery - verification status

Per the governance directive, this file states exactly what was verified and
what was not. Nothing in this directory has touched a live PackageKit, a live
Arch system, a VM, or hardware.

## Verified (with proof)

1. **Implemented**: `elto-discovery` (Python 3, stdlib only), `tests/run-tests.py`.
2. **Parser, JSON contract and error mapping tested**: 23 assertions pass
   against a stub `pkcon` with recorded outputs. Output of the run in the
   author's sandbox: `all tests passed` (23 checks). The stub's line formats
   are modeled on PackageKit v1.4.1 source, not on a live run:
   - package result line, non-console: `client/pkcon/pk-console.c`,
     `pk_console_package_cb`, lines ~92-132 (`g_print("%s %s\n", info_pad,
     printable)`, printable = `name-version.arch (data)`, info word padded
     to 12);
   - summary absent in non-console mode: same function, line 125 vs 132;
   - progress lines `Transaction:\t`, `Package:\t`, `Percentage:\t`,
     `Status: \t` (note the extra space): lines ~603, ~619, ~636, ~661;
   - error lines `The transaction failed: <enum>, <details>` and
     `Fatal error: <message>`: lines ~700, ~734; `Command failed: <message>`
     in `main`, line ~2620;
   - get-details block: `pk_console_details_cb`, lines ~470-520;
   - exit codes: pk-console.c lines 38-42 (3 syntax, 4 file-not-found,
     5 nothing-useful, 6 cannot-setup, 7 transaction-failed);
   - full package IDs skip interactive resolution
     (`pk_package_id_check`): lines 913-915; the multiple-match path prompts
     on stdin ("Please choose the correct package:"), which is why stdin is
     closed and bare names are refused.
   Source fetched 2026-11-27 from
   https://github.com/hughsie/PackageKit/blob/v1.4.1/client/pkcon/pk-console.c
3. **Component availability**: `packagekit` 1.4.1 is in Arch `extra` and ships
   the alpm backend (`usr/lib/packagekit-backend/libpk_backend_alpm.so`),
   checked live on archlinux.org 2026-11-27.

## NOT verified

- **Not launched against real pkcon.** No live PackageKit output has been
  parsed. The fixtures above come from source reading; real output may differ
  in padding, wording, or locale edge cases.
- **Not functionally tested**: no real search, install, or remove ran.
- **Not tested in a session, VM, or hardware.**
- Exact error wording for each real failure (offline, polkit denial, polkit
  cancel, missing daemon, GPG key prompt) is unconfirmed; `classify_error()`
  patterns are educated mappings that the VM test must confirm or correct.
- polkit behavior in the ElTo session is unknown: there is no polkit
  authentication agent in the session today. Whether `install` as the session
  user prompts, is denied, or is allowed (e.g. wheel membership) must be
  observed on the VM and may become a Core/session-track decision.
- Cancellation semantics mid-transaction (what state pacman is left in if the
  helper kills pkcon's process group mid-install) are untested.

## VM test list (for the implementer)

1. Install `packagekit` if the base image lacks it: `pacman -S packagekit`.
2. `./elto-discovery selftest` -> expect `done.ok == true`, backend details
   naming `alpm`. Failure here means the daemon/activation path is broken.
3. `./elto-discovery search firefox` -> expect results including `firefox`
   with repo `extra`, correct version/arch, status `available`. Compare the
   raw `pkcon --plain search name firefox` output side by side to confirm the
   fixture formats match reality (padding, info words).
4. `./elto-discovery info <full-id-from-search>` -> expect summary, license,
   sizes, url, description.
5. `./elto-discovery install <full-id of a small package, e.g. sl>` as the
   regular session user. Record exactly what polkit does: allowed without
   prompt, prompted (which agent answered?), or denied. This is decision
   input for the Core track (polkit agent/rule in the session).
6. `./elto-discovery remove <same id>` -> expect success.
7. `./elto-discovery install nope;0-1;x86_64;extra` -> expect
   `error.code == "not-found"`.
8. Network down: `search` should still succeed from the local pacman db;
   `install` should fail with a clean error JSON (record the code it maps to).
9. Cancel/deny the polkit prompt during step 5 -> record the actual pkcon
   wording and the mapped code (`cancelled` / `not-authorized`).
10. `pkcon` absent (simulate by PATH): `selftest` -> `pkcon-missing`.

Report each step's raw output as proof; update this file's levels after the
run.
