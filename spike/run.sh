#!/bin/bash
set -x
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export KWIN_COMPOSE=Q LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=wayland-spike
cd /tmp
# Outer compositor (labwc, headless, pixman) only exists so we can screenshot KWin; the thing under test is KWin 6.8.3 nested inside it.
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
env -u WAYLAND_DISPLAY labwc > /tmp/labwc.log 2>&1 &
sleep 5
ls $XDG_RUNTIME_DIR; head -20 /tmp/labwc.log
echo '== control: plain foot in outer labwc'
WAYLAND_DISPLAY=wayland-0 foot -e sh -c 'echo control; sleep 100' > /tmp/foot0.log 2>&1 &
sleep 3
WAYLAND_DISPLAY=wayland-0 grim /tmp/shot0.png; ls -la /tmp/shot0.png; echo '===== BEGIN-SHOT shot0 ====='; base64 -w0 /tmp/shot0.png; echo
pkill -f 'foot -e sh -c echo control'
WAYLAND_DISPLAY=wayland-0 gdb -batch -ex 'handle SIGPIPE nostop noprint' -ex run -ex 'bt 25' --args /usr/bin/kwin_wayland --wayland-display wayland-0 --width 1280 --height 720 --socket wayland-spike --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 8
alive() { pgrep -f '^/usr/bin/kwin_wayland' >/dev/null && echo "ALIVE-after: $1" || echo "KWIN-DEAD-after: $1"; }
sleep 8
echo "== kwin alive?"; pgrep -af '^/usr/bin/kwin_wayland' || { echo KWIN-DIED; tail -40 /tmp/kwin.log; }
echo "== wayland globals (wayland-info)"
wayland-info 2>&1 | grep -E "^interface" | sed -E "s/interface: '([^']+)'.*version: +([0-9]+).*/\1 v\2/" | sort | tee /tmp/globals.txt | head -120
for g in zwlr_layer_shell_v1 ext_session_lock_manager_v1 zwlr_foreign_toplevel_manager_v1 ext_foreign_toplevel_list_v1 org_kde_plasma_window_management org_kde_plasma_shell zkde_screencast_unstable_v1 ext_workspace_manager_v1 zwlr_screencopy_manager_v1 ext_image_copy_capture_manager_v1; do
  if grep -q "^$g " /tmp/globals.txt; then echo "GLOBAL-PRESENT $g"; else echo "GLOBAL-ABSENT  $g"; fi
done
echo "== quickshell"
quickshell -p /spike/shell.qml > /tmp/qs.log 2>&1 &
sleep 8
pgrep -a quickshell || { echo QS-DIED; }
cat /tmp/qs.log | head -40
alive quickshell-started
echo "== start a normal Wayland app (foot)"
foot -e sh -c 'echo hello from foot; sleep 300' > /tmp/foot.log 2>&1 &
sleep 6
cat /tmp/foot.log | head -5
alive foot-started; grep SPIKE /tmp/qs.log
echo "== screenshot 1 (shell + app)"
WAYLAND_DISPLAY=wayland-0 grim /tmp/shot1.png; ls -la /tmp/shot1.png; echo '===== BEGIN-SHOT shot1 ====='; base64 -w0 /tmp/shot1.png; echo
echo "== KWin script bridge test: list windows through KWin scripting"
alive screenshot1
cat > /tmp/list.js <<'JS'
const ws = workspace.windowList();
for (const w of ws) { print("KWINWIN caption=" + w.caption + " class=" + w.resourceClass + " normal=" + w.normalWindow); }
JS
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/list.js spikelist 2>&1 | head -3
qdbus6 org.kde.KWin /Scripting/Script0 org.kde.kwin.Script.run 2>&1 | head -3
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start 2>&1 | head -3
sleep 3
echo '== direct plasma_window_management client (C)'; WAYLAND_DISPLAY=wayland-spike /tmp/pwm 2>&1 | head -20
echo '== second client binding while first still exists'; WAYLAND_DISPLAY=wayland-spike /tmp/pwm 2>&1 | head -5
grep -a KWINWIN /tmp/kwin.log | head; journalctl --no-pager 2>/dev/null | grep -a KWINWIN | head -3
echo "== lock test with the stock kscreenlocker"
dbus-send --session --print-reply --dest=org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Lock 2>&1 | head -3
sleep 6
pgrep -af kscreenlocker_greet || echo "NO-GREETER"
qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>&1 | head -2
WAYLAND_DISPLAY=wayland-0 grim /tmp/shot2.png; ls -la /tmp/shot2.png; echo '===== BEGIN-SHOT shot2 ====='; base64 -w0 /tmp/shot2.png; echo
echo "== kwin log tail (with gdb backtrace if it crashed)"; tail -50 /tmp/kwin.log
echo "== qs log tail"; tail -20 /tmp/qs.log
