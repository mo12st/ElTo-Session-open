#!/bin/bash
# ElTo Core installer, Phases A+B: identity + system defaults + behavior. Run as root, from the repo root.
# Replaces the settings writes in session/install.sh; session/install.sh still owns the session
# itself (shell, KWin, SDDM greeter config, lock package, /opt/elto-session).
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
C="$R/elto-core"

# --- identity ---
install -m644 "$C/identity/os-release" /usr/lib/os-release
ln -srf /usr/lib/os-release /etc/os-release   # relative symlink, per the freedesktop spec
install -m644 "$C/identity/issue" /etc/issue
install -m644 "$C/identity/issue.net" /etc/issue.net
install -m644 "$C/identity/hostname" /etc/hostname
install -d /usr/share/icons/hicolor/256x256/apps /usr/share/pixmaps
install -m644 "$C/identity/elto-logo.png" /usr/share/icons/hicolor/256x256/apps/elto-logo.png
install -m644 "$C/identity/elto-logo.png" /usr/share/pixmaps/elto-logo.png

# --- system defaults (same targets session/install.sh writes today; behavior unchanged) ---
install -d /etc/xdg /etc/sddm.conf.d
install -m644 "$C/defaults/kdeglobals" /etc/xdg/kdeglobals
install -m644 "$C/defaults/kwinrc" /etc/xdg/kwinrc
install -m644 "$C/defaults/plasmashellrc" /etc/xdg/plasmashellrc
install -m644 "$C/defaults/mimeapps.list" /etc/xdg/mimeapps.list
install -m644 "$C/defaults/sddm.conf.d/elto.conf" /etc/sddm.conf.d/elto.conf

# --- behavior ---
# Vendor preset: takes effect at first boot or `systemctl preset-all`, never forced here.
install -d /usr/lib/systemd/system-preset
install -m644 "$C/behavior/00-elto.preset" /usr/lib/systemd/system-preset/00-elto.preset
# environment.d contract for the systemd user manager.
install -d /usr/lib/environment.d
install -m644 "$C/behavior/90-elto.conf" /usr/lib/environment.d/90-elto.conf
echo "elto-core installed: identity + defaults + behavior"
