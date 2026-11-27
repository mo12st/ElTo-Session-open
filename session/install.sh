#!/bin/bash
# Installs the ElTo session system-wide (run as root, from the repo root). CONCEPT / SPIKE.
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
install -d /opt/elto-session
cp -r "$R/panel-widgets" "$R/wallpaper" "$R/wallpapers" "$R/palette" "$R/themes" "$R/icons" "$R/textures" /opt/elto-session/
install -d /opt/elto-session/lock; cp -r "$R/lock/assets" /opt/elto-session/lock/
install -m644 "$R/session/elto-customize.desktop" /usr/share/applications/elto-customize.desktop
install -m755 "$R/session/elto-session" /usr/local/bin/elto-session
install -m644 "$R/session/elto.desktop" /usr/share/wayland-sessions/elto.desktop
(cd "$R/plugin/windowlist" && make >/dev/null && install -m755 elto-windowlist /usr/local/bin/elto-windowlist)
install -d /usr/share/aurorae/themes
cp -r "$R/aurorae/ElToClassic" /usr/share/aurorae/themes/
# login screen
install -d /usr/share/sddm/themes
cp -r "$R/spike/sddm/elto-classic" /usr/share/sddm/themes/
# lock screen greeter (kscreenlocker picks it from plasmashellrc ShellPackage)
D=/usr/share/plasma/shells/org.elto.shell; install -d $D/contents/lockscreen
cp "$R/lock/metadata.json" $D/; cp -r "$R/lock/LockScreen.qml" "$R/lock/Exec.qml" "$R/lock/assets" $D/contents/lockscreen/
# identity + system defaults (kdeglobals, kwinrc, plasmashellrc, mimeapps, sddm conf) live in elto-core/
# welcome (first-run tour)
install -d /opt/elto-session/welcome
cp "$R/welcome/welcome.qml" "$R/welcome/LIcon.qml" "$R/welcome/elto-welcome-autostart.sh" /opt/elto-session/welcome/
chmod 755 /opt/elto-session/welcome/elto-welcome-autostart.sh
install -m644 "$R/welcome/elto-welcome.desktop" /usr/share/applications/elto-welcome.desktop
install -d /etc/xdg/autostart
install -m644 "$R/welcome/elto-welcome-autostart.desktop" /etc/xdg/autostart/elto-welcome-autostart.desktop
# elto-control (settings center)
install -d /opt/elto-session/elto-control
cp -rL "$R"/elto-control/*.qml "$R/elto-control/theme-tool.py" "$R/elto-control/i18n.json" "$R/elto-control/icons" /opt/elto-session/elto-control/
install -m755 "$R/elto-control/elto-control" /usr/local/bin/elto-control
install -m644 "$R/elto-control/elto-control.desktop" /usr/share/applications/elto-control.desktop
bash "$R/elto-core/install.sh"
echo installed
