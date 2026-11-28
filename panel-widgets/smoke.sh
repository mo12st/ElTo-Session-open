#!/bin/bash
# Smoke test only: proves the QML parses and the Quickshell modules resolve. It does not prove the
# widgets show real data (no pipewire/upower/bluez/NetworkManager in this container).
set -u
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland
cd /tmp
kwin_wayland --virtual --width 1280 --height 720 --socket wayland-pw --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 8
pgrep -f '^kwin_wayland' >/dev/null || { echo KWIN-DIED; tail -30 /tmp/kwin.log; exit 1; }
export WAYLAND_DISPLAY=wayland-pw
quickshell -p /src/panel-widgets/shell-spike.qml > /tmp/qs.log 2>&1 &
QS=$!
sleep 12
echo "== quickshell log"; cat /tmp/qs.log
if ! kill -0 $QS 2>/dev/null; then echo "QUICKSHELL-EXITED"; exit 1; fi
if grep -aE 'is not a type|is not installed|unavailable|ReferenceError|TypeError|Cannot assign|Unable to assign|module .* not found|Unexpected token|Expected token|SyntaxError' /tmp/qs.log; then echo "QML-LOAD-ERRORS"; exit 1; fi
echo "QML-LOADED-OK"
