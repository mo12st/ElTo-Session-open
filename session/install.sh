#!/bin/bash
# Installs the ElTo session system-wide (run as root, from the repo root). CONCEPT / SPIKE.
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
install -d /opt/elto-session
cp -r "$R/panel-widgets" "$R/wallpaper" "$R/palette" /opt/elto-session/
install -m755 "$R/session/elto-session" /usr/local/bin/elto-session
install -m644 "$R/session/elto.desktop" /usr/share/wayland-sessions/elto.desktop
(cd "$R/plugin/windowlist" && make >/dev/null && install -m755 elto-windowlist /usr/local/bin/elto-windowlist)
# defaults every KDE app reads from XDG_CONFIG_DIRS: ElTo colors, Breeze icons, ElTo window decoration
install -d /etc/xdg /usr/share/aurorae/themes
{ cat "$R/theme/ElTo.colors"; printf '\n[Icons]\nTheme=breeze\n'; } > /etc/xdg/kdeglobals
cp -r "$R/aurorae/ElToClassic" /usr/share/aurorae/themes/
printf '[org.kde.kdecoration2]\nlibrary=org.kde.kwin.aurorae\ntheme=__aurorae__svg__ElToClassic\n' > /etc/xdg/kwinrc
# login screen
install -d /usr/share/sddm/themes /etc/sddm.conf.d
cp -r "$R/spike/sddm/elto-classic" /usr/share/sddm/themes/
printf '[Theme]\nCurrent=elto-classic\n[General]\nDisplayServer=wayland\n[Wayland]\nCompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1\n' > /etc/sddm.conf.d/elto.conf
# lock screen greeter (kscreenlocker picks it from plasmashellrc ShellPackage)
D=/usr/share/plasma/shells/org.elto.shell; install -d $D/contents/lockscreen
cp "$R/lock/metadata.json" $D/; cp -r "$R/lock/LockScreen.qml" "$R/lock/Exec.qml" "$R/lock/assets" $D/contents/lockscreen/
printf '[Shell]\nShellPackage=org.elto.shell\n' > /etc/xdg/plasmashellrc
echo installed
