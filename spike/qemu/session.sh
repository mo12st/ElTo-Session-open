#!/bin/bash
# runs inside the VM as user dev, on tty1 via a systemd unit (real logind session, real DRM)
exec > /tmp/session.log 2>&1
set -x
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export QT_LOGGING_RULES='*kscreenlocker*=true;*screenlocker*=true' QT_FORCE_STDERR_LOGGING=1
export XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
kwin_wayland --socket wayland-0 &
sleep 8
export WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland
quickshell -p /tmp/shell.qml > /tmp/qs.log 2>&1 &
sleep 4
foot -e sh -c 'echo hello from foot; sleep 3000' > /tmp/foot.log 2>&1 &
wait
