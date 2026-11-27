# elto-packages — curated package selection for the ElTo system

This directory owns **which packages an ElTo system installs**: what is
essential, what is optional, and what is deliberately excluded. It shares
no files with the shell track (Quickshell QML), the kernel track
(`elto-kernel/`) or the Windows-compat track (`elto-windows-compat/`).

## Layout

| File | Layer | Installed by default? |
|---|---|---|
| `lists/00-base.packages` | Minimal Arch base system | yes |
| `lists/10-session.packages` | The ElTo session runtime (KWin, Quickshell, kscreenlocker, SDDM) | yes |
| `lists/20-services.packages` | Services the shell widgets talk to (PipeWire, NetworkManager, BlueZ, UPower, playerctl, polkit) | yes |
| `lists/30-fonts.packages` | Fonts (Nunito + Noto Serif Display for the SDDM theme) | yes |
| `lists/40-apps.packages` | Optional user apps (foot, konsole, dolphin, kate, gwenview, okular, kcalc) | `--with-apps` |
| `lists/50-windows-compat.packages` | Optional Windows .exe support (wine, winetricks, umu-launcher, icoutils). Owner-approved 2026-11-27; consumed by `elto-windows-compat/` | `--with-windows` |
| `lists/90-build.packages` | Build-time only (elto-windowlist helper, qemu spikes) | `--with-build` |

`AVOIDED.md` — packages deliberately excluded (anything that pulls in the
Plasma Shell, duplicates an ElTo shell widget, or is non-free), with the
dependency evidence.

`VERIFICATION.md` — exactly what is verified and what is not.

## Selection policy

1. **No Plasma Shell.** ElTo is KWin + Quickshell. Any package that depends
   on `plasma-workspace` is rejected (see AVOIDED.md).
2. **Grounded in the code.** Session/service packages trace to the repo:
   the QML imports in `panel-widgets/` (Quickshell PipeWire/UPower/
   Bluetooth/Networking services, playerctl), `session/install.sh`
   (aurorae decoration, breeze icons, SDDM config, QT_QPA_PLATFORMTHEME),
   and the union of the VM-proven spike boot lists in `spike/qemu/`.
3. **Free only.** Official Arch repos, no AUR, no proprietary drivers.
4. **Scope discipline.** The apps layer is exactly the VM-proven set; new
   apps or new layers need the owner's approval first.
5. **Kernel choice belongs to the kernel track.** 00-base lists the stock
   `linux` kernel with a comment to drop it when `elto-kernel/` lands.

## Usage

```sh
./install.sh                 # base + session + services + fonts
./install.sh --with-apps     # plus user applications
./install.sh --with-windows  # plus Windows .exe support (needs [multilib])
./install.sh --with-build    # plus build-time packages
./install.sh --dry-run ...   # print the package set, change nothing
./verify.sh                  # re-check every name against the live Arch repos
```
