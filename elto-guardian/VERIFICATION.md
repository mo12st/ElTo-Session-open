# VERIFICATION — elto-guardian Phase 1

Honest status per the governance directive's verification levels.
Date: 2026-11-27.

## Verified (real, reproducible)

- `bash -n` syntax check passes on `elto-doctor` and `install.sh`.
- `elto-doctor` **runs end-to-end** in the agent sandbox (a non-Arch,
  non-systemd container): all 9 checks execute, report renders in the
  approved format, exit code is 1 when a problem is found and 0 otherwise.
- Degradation paths exercised for real in that sandbox: no systemctl →
  "cannot talk to systemd, skipped"; no lspci → "pciutils not installed,
  skipped"; no pacman → "not an Arch system, skipped"; pactl present but no
  audio server → reported as a problem with evidence; snapshots →
  "not set up yet (Phase 3)". Missing tools never abort the report.
- `--short` prints only the Problems section (verified).
- `--save` writes the exact shown report to `$HOME/elto-doctor-<date>.txt`
  (verified with a test HOME; file contents diff-match stdout).
- `--help` / `--version` / unknown-flag handling verified.
- `install.sh` and `--uninstall` logic reviewed line-by-line; touches only
  `/usr/local/bin/elto-doctor` and the two `/etc/systemd/*.d/elto*` drop-ins.

## NOT verified (the implementer's VM test list)

Nothing below has run on Arch, on ElTo, or against real systemd:

1. Fresh ElTo VM: `sudo ./elto-guardian/install.sh` from the repo root →
   check `/usr/local/bin/elto-doctor`,
   `/etc/systemd/journald.conf.d/elto-persistent.conf`,
   `/etc/systemd/coredump.conf.d/elto.conf` exist; `systemd-analyze cat-config
   systemd/journald.conf` shows Storage=persistent.
2. Healthy VM: `elto-doctor` exits 0, every section prints a verdict, the OK
   section lists services/journal/shell/graphics/sound/network/packages/disk.
3. Break a service on purpose (e.g. create a bogus failing unit) → next
   `elto-doctor` run lists it under PROBLEMS with evidence.
4. Kill Quickshell (`pkill -SEGV quickshell`) → crash recorded; next run
   shows it under PROBLEMS (coredumpctl evidence).
5. Reboot twice → `journalctl -b -1` shows the previous boot (persistent
   journal working); disk usage of `/var/log/journal` respects the 500M cap.
6. Read-only proof: run `elto-doctor` before and after `find / -newer
   <marker>` shows no system files changed by the script (only `--save`'s
   home file when asked).
7. Session hardening (session track applies `SESSION-HARDENING.md`): kill
   Quickshell once → it respawns; kill it 4 times → respawns stop and the
   failure hint is in `~/.local/state/elto-session.log`.
8. `sudo ./elto-guardian/install.sh --uninstall` removes the three installed
   files cleanly.

## Known limitations

- `pacman -Qkk` can take tens of seconds on a system with many packages; the
  report just takes that long (no timeout yet).
- Verdict lines are English only in this PR; the message-catalog localization
  (Arabic + English) from the approved report-format draft is follow-up work.
- btrfs `filesystem df` needs root; without it the btrfs detail is skipped
  (Doctor is meant to run as the normal user).
- shellcheck was not available in the authoring sandbox; syntax was checked
  with `bash -n` and the script was reviewed for quoting/arrays, but a
  shellcheck pass on the VM is a good extra.
