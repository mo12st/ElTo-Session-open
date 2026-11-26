#!/bin/bash
# Why is nested KWin not visible in the outer compositor? Trace its Wayland client traffic.
set -x
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
cd /tmp
env -u WAYLAND_DISPLAY labwc > /tmp/labwc.log 2>&1 &
sleep 4
WAYLAND_DISPLAY=wayland-0 wayland-info 2>&1 | grep -E "interface: '(wl_output|xdg_wm_base|wl_shm|zwp_linux_dmabuf_v1|wp_viewporter)'" | head
KWIN_COMPOSE=Q LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland WAYLAND_DEBUG=client WAYLAND_DISPLAY=wayland-0 kwin_wayland --wayland-display wayland-0 --width 1280 --height 720 --socket wayland-spike --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 12
pgrep -af kwin_wayland
echo "== kscreen-doctor outputs"; WAYLAND_DISPLAY=wayland-spike kscreen-doctor -o 2>&1 | head -20
O=$(WAYLAND_DISPLAY=wayland-spike kscreen-doctor -o 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | awk '/^Output:/{print $3; exit}'); echo "first output name: $O"
[ -n "$O" ] && WAYLAND_DISPLAY=wayland-spike kscreen-doctor output.$O.enable output.$O.mode.1280x720@60 2>&1 | head
sleep 5
WAYLAND_DISPLAY=wayland-spike kscreen-doctor -o 2>&1 | head -12
quickshell -p /spike/shell.qml > /tmp/qs.log 2>&1 &
foot -e sh -c 'echo hello from foot; sleep 300' > /tmp/foot.log 2>&1 &
sleep 8
echo "== counts"; for k in xdg_toplevel xdg_surface 'wl_surface@[0-9]*.commit' 'wl_surface@[0-9]*.attach' 'wl_shm_pool' 'zwp_linux_dmabuf' 'set_title' 'ack_configure' 'configure'; do echo "$k: $(grep -a -c "$k" /tmp/kwin.log)"; done
echo "== kwin non-wayland-debug lines"; grep -a -v -E '^\[ *[0-9.]+\]' /tmp/kwin.log | head -60
echo "== toplevel lines"; grep -a -E 'xdg_toplevel|set_title|set_app_id' /tmp/kwin.log | head -12
WAYLAND_DISPLAY=wayland-0 grim /tmp/shot1.png; ls -la /tmp/shot1.png
echo "===== BEGIN-SHOT shot1 ====="; base64 -w0 /tmp/shot1.png; echo
