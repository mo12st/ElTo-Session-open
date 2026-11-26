#!/bin/bash
# Variant: KWin --virtual with OpenGL on software Mesa (surfaceless EGL), screenshot with spectacle
set -x
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=wayland-spike
export EGL_PLATFORM=surfaceless MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
cd /tmp
kwin_wayland --virtual --width 1280 --height 720 --socket wayland-spike --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 10
pgrep -af '^kwin_wayland|^/usr/bin/kwin_wayland' || { echo KWIN-DIED; tail -30 /tmp/kwin.log; }
quickshell -p /spike/shell.qml > /tmp/qs.log 2>&1 &
sleep 6
foot -e sh -c 'echo hello from foot; sleep 300' > /tmp/foot.log 2>&1 &
sleep 5
sleep 6
grep SPIKE /tmp/qs.log
pgrep -f '^kwin_wayland|^/usr/bin/kwin_wayland' >/dev/null && echo "ALIVE-kwin" || echo "KWIN-DEAD"
for n in bg panel; do ls -la /tmp/qs-$n.png; echo "===== BEGIN-SHOT qs$n ====="; base64 -w0 /tmp/qs-$n.png; echo; done
echo "== kwin log"; tail -20 /tmp/kwin.log; echo "== qs log"; tail -8 /tmp/qs.log
