# ElTo Core manifest — every file, its target, its reason

Phase A: identity + defaults. Behavior (systemd presets, environment.d) is Phase B, not here yet.

| File | Installs to | Reason |
| --- | --- | --- |
| identity/os-release | /usr/lib/os-release, with /etc/os-release as a relative symlink (freedesktop spec) | System identity. KDE About page, hostnamectl, boot menu and every "what OS is this" answer ElTo. ID_LIKE=arch keeps pacman, AUR helpers, distrobox and flatpak treating the system as Arch-family. |
| identity/hostname | /etc/hostname | Source of truth for the machine name. The kernel's CONFIG_DEFAULT_HOSTNAME="elto" (kernel track) stays as a fallback only. |
| identity/issue, issue.net | /etc/issue, /etc/issue.net | Console login banner says ElTo 2026.11 instead of Arch. |
| identity/elto-logo.png | /usr/share/icons/hicolor/256x256/apps/elto-logo.png and /usr/share/pixmaps/elto-logo.png | The icon os-release LOGO=elto-logo resolves. Copy of lock/assets/snail.png: his snail artwork, all rights reserved per the repo LICENSE. |
| defaults/kdeglobals | /etc/xdg/kdeglobals | ElTo colors + breeze icons for every KDE app. Generated from palette/elto-palette.json via theme/gen_colors.py (single color source), plus the [Icons] line. Regenerate when the palette changes. |
| defaults/kwinrc | /etc/xdg/kwinrc | ElToClassic aurorae window decoration, same as session/install.sh today. |
| defaults/plasmashellrc | /etc/xdg/plasmashellrc | org.elto.shell lock screen package, same as session/install.sh today. |
| defaults/mimeapps.list | /etc/xdg/mimeapps.list | Default apps matching the dock's pinned set: dolphin, firefox, kate, gwenview, thunderbird. |
| defaults/sddm.conf.d/elto.conf | /etc/sddm.conf.d/elto.conf | elto-classic SDDM theme on the kwin_wayland greeter, same as session/install.sh today. |

Precedence contract: user ~/.config > world-applied state (Theme/World track) > /etc/xdg (admin; where Phase A installs) > upstream KDE defaults. Core owns the floor, never the user's choices. A later move of the KDE defaults from /etc/xdg to /usr/share/elto/defaults (cleaner layering behind the admin layer) needs one XDG_CONFIG_DIRS line in session/elto-session, which the implementer owns.
| behavior/00-elto.preset | /usr/lib/systemd/system-preset/00-elto.preset | Enables at first boot / preset-all exactly the services panel-widgets consumes: sddm, NetworkManager, bluetooth. Vendor preset, so admin overrides win. PipeWire/WirePlumber are user-session socket-activated and need no preset. |
| behavior/90-elto.conf | /usr/lib/environment.d/90-elto.conf | QT_QPA_PLATFORMTHEME=kde for Qt apps launched outside elto-session's env (user services, D-Bus activation). The session script keeps owning the in-session env; no second source of truth. |
