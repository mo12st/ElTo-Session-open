#!/bin/bash
# Throwaway CI VM: Arch cloud image, password login for a throwaway user, no keys, no network exposure beyond the runner.
set -x
REPO=$PWD; cd /tmp
curl -sSL -o arch.qcow2 https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2; ls -la arch.qcow2
qemu-img resize arch.qcow2 12G
cat > user-data <<'UD'
#cloud-config
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - {name: dev, password: devpass, type: text}
users:
  - {name: dev, sudo: "ALL=(ALL) NOPASSWD:ALL", shell: /bin/bash, lock_passwd: false}
UD
echo "instance-id: spike1" > meta-data
cloud-localds seed.img user-data meta-data
truncate -s 256M /tmp/usb.img; mkfs.ext4 -q -L Backup /tmp/usb.img; ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
echo "ACCEL=$ACCEL"
qemu-system-x86_64 -accel $ACCEL -m 4096 -smp 2 -cpu max \
  -drive file=arch.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw \
  -device qemu-xhci -drive file=/tmp/usb.img,if=none,id=usb0,format=raw -device usb-storage,drive=usb0 -device virtio-vga -display none -serial file:/tmp/serial.log \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 \
  -qmp unix:/tmp/qmp.sock,server,nowait -daemonize
START=$(date +%s)
for i in $(seq 1 90); do
  if sshpass -p devpass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p 2222 dev@127.0.0.1 'echo SSH-UP; uname -r' 2>/dev/null; then echo "booted in $(( $(date +%s) - START )) s with $ACCEL"; break; fi
  sleep 8
done
tail -20 /tmp/serial.log
S="sshpass -p devpass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 dev@127.0.0.1"
$S 'cat /etc/os-release | head -2; ls /dev/dri; df -h / | tail -1' 

shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert "$1" /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot /tmp/vm1.ppm vm1
qmp() { python3 - "$@" <<'PY'
import socket,json,sys
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
for a in sys.argv[1:]:
    f.write(a+"\n");f.flush();print(f.readline().strip())
PY
}
echo "== provision full session"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
cat > /tmp/d.sh <<'EOS'
export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus QT_QPA_PLATFORMTHEME=kde
LOG=$HOME/.local/state/elto-session.log
setov() { echo "$1" > ~/.config/elto/theme.json; sleep 7; }
chk() { echo "[$1] log:"; grep -a -i -e "ELTODOCK" -e "is not a type" -e "Cannot load" -e ReferenceError -e "Cannot read property" -e "TypeError" $LOG | cut -c1-200 | tail -5; echo "qs=$(pgrep -c quickshell)"; }
case "$1" in
 desk) dbus-send --session --print-reply --dest=org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.createDesktop uint32:1 string:Personal 2>&1 | tail -1
       dbus-send --session --print-reply --dest=org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.createDesktop uint32:2 string:Work 2>&1 | tail -1
       sleep 2; python3 /opt/elto-session/panel-widgets/dock-desktops.py;;
 sw) python3 /opt/elto-session/panel-widgets/dock-desktops.py switch $2; sleep 4; python3 /opt/elto-session/panel-widgets/dock-desktops.py | head -3;;
 pager) setov "{\"options\":{\"dock\":\"bar\"},\"dock\":{\"workspaceStyle\":\"$2\"}}"; chk pager_$2;;
 island) setov "{\"dock\":{\"workspaceStyle\":\"$2\"}}"; chk island_$2;;
 rail) setov "{\"options\":{\"dock\":\"rail-dock\"},\"dock\":{\"edge\":\"$2\",\"workspaceStyle\":\"numbers\"}}"; chk rail_$2;;
 strip) setov '{"options":{"dock":"bar"},"dock":{"secondSurface":"top","workspaceStyle":"numbers"}}'; chk strip;;
 stripnotch) setov '{"options":{"dock":"island"},"dock":{"secondSurface":"top"}}'; chk stripisland;;
 reset) setov '{}'; chk reset;;
esac
EOS
cat > /tmp/apps.sh <<'EOS'
for s in $(loginctl list-sessions --no-legend | awk '$3=="dev"{print $1}'); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && S=$s; done
SCOPE=$(loginctl show-session $S -p Scope --value); echo $$ > /sys/fs/cgroup/user.slice/user-1000.slice/$SCOPE/cgroup.procs
for a in kate dolphin; do sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=kde XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HOME=/home/dev setsid $a >/dev/null 2>&1 </dev/null & sleep 4; done
sleep 12
EOS
$SC /tmp/d.sh /tmp/apps.sh dev@127.0.0.1:/tmp/
D() { $S "bash /tmp/d.sh $1 $2 2>&1 | cut -c1-220"; }
$S 'pkill -f welcome.qml; sleep 2; pgrep -a quickshell | cut -c1-100; ls /opt/elto-session/panel-widgets | grep -i -E "dock-desk|DockRail|DockStrip|DockPager"'
D reset; shot /tmp/s0.ppm s0_island_default
$S 'sudo bash /tmp/apps.sh; pgrep -a "kate|dolphin" | cut -c1-60'
echo "== one desktop: pager must draw nothing"
D pager numbers; shot /tmp/s1.ppm s1_one_desktop_numbers
echo "== create 2 more desktops (3 total)"
D desk
shot /tmp/s2.ppm s2_numbers_3desk
D pager text; shot /tmp/s3.ppm s3_text
D pager dots; shot /tmp/s4.ppm s4_dots
D pager numbers; shot /tmp/s4b.ppm s4b_numbers
echo "== switch via helper (KWin write) then read back"
D sw 2; shot /tmp/s5.ppm s5_after_switch2
echo "== island with pager"
D island numbers; shot /tmp/s6.ppm s6_island_numbers
echo "== rail left / right"
D rail left; shot /tmp/s7.ppm s7_rail_left
D rail right; shot /tmp/s8.ppm s8_rail_right
echo "== second top strip + bar, then + island, Notch on top edge"
D strip; shot /tmp/s9.ppm s9_strip_bar
click 640 10; sleep 3; shot /tmp/s9b.ppm s9b_strip_click_center_top
D stripnotch; shot /tmp/s10.ppm s10_strip_island
$S 'grep -a -i -E "ELTODOCK|Cannot|is not a type|ReferenceError|TypeError|ERROR" ~/.local/state/elto-session.log | cut -c1-200 | sort | uniq -c | sort -rn | head -14'
