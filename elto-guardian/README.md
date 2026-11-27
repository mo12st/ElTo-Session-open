# elto-guardian — protection, recovery and diagnosis for ElTo

Guardian is **not a service and not an engine**. It is a small set of mature,
standard mechanisms, each independently removable:

| Piece | What it is | Phase |
|---|---|---|
| `elto-doctor` | One read-only diagnostic command: services, journal errors, shell health, graphics/drivers, sound, network, package integrity, disk, snapshots. One plain-language report. | **1 (this PR)** |
| Log & crash retention | journald `Storage=persistent` (capped at 500M) + systemd-coredump with hard caps. Two config drop-ins. | **1 (this PR)** |
| Session hardening | Limited Quickshell respawn inside `session/elto-session`. Owned by the session track — see `SESSION-HARDENING.md` (request, not an edit). | **1 (this PR, via session track)** |
| Recovery session entry | `ElTo Recovery` in the SDDM menu: KWin + foot + Doctor, no Quickshell/QML, so a broken shell can never lock the user out. | 2 |
| Snapshots & rollback | snapper + snap-pac on btrfs (decided), ~10 rolling snapshots, grub-btrfs bootable snapshot entries (GRUB confirmed). | 3 |

Owner decisions folded in (2026-11-27): direction approved, Doctor merged
into Guardian, btrfs, GRUB, Doctor is a command first (shell page later,
alongside ElTo Control), ~10 rolling snapshots.

## Design rules

1. **No daemon.** Everything is on-demand reads, pacman hooks, or stock
   systemd configuration (governance rules 7 and 10).
2. **Read-only Doctor.** It never installs, removes, restarts or edits
   anything. Fix advice is printed as text for the user to choose.
3. **Graceful failure.** If an ElTo component fails, the user keeps a working
   path back: session log → Doctor → Recovery session → snapshot rollback.
4. **Free only.** All tools are from the official Arch repos.
5. **Safe to share.** The default report contains no IPs, MACs, serials or
   tokens; `--full` adds identifying detail and says so.

## Usage

```
sudo ./elto-guardian/install.sh        # install Phase 1
elto-doctor                            # full report
elto-doctor --short                    # only problems
elto-doctor --save                     # also save ~/elto-doctor-<date>.txt
sudo ./elto-guardian/install.sh --uninstall
```

## Optional tool dependencies

Doctor degrades gracefully when a tool is missing (the check is skipped with
a note). For full coverage these Arch packages help and are requested from
the packages track: `pciutils` (lspci), `mesa-demos` (glxinfo),
`vulkan-tools` (vulkaninfo), `pacman-contrib` (checkupdates). Everything else
Doctor uses is already required by the session/package layers (systemd,
journalctl, pacman, df, wpctl via wireplumber, pactl via libpulse, nmcli via
networkmanager).

## Layout

- `elto-doctor` — the diagnostic command (bash, no dependencies beyond bash + the tools above)
- `install.sh` — installs/removes Phase 1; touches nothing outside Guardian
- `config/journald-persistent.conf` — persistent, capped system journal
- `config/coredump-elto.conf` — capped crash collection
- `SESSION-HARDENING.md` — requested `session/elto-session` changes (session track applies)
- `VERIFICATION.md` — exactly what is verified and what is not
