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
(cd $REPO/pr && tar --exclude=.git -czf /tmp/repo.tgz .) && $SC /tmp/repo.tgz dev@127.0.0.1:/tmp/ 2>&1 | tail -2
$S 'sudo pacman -Syu --noconfirm --needed sddm kwin quickshell foot qt6-wayland qt6-svg qt6-declarative mesa libglvnd ttf-dejavu noto-fonts noto-fonts-extra ttf-nunito base-devel wayland plasma-wayland-protocols wayland-protocols libnotify kcalc dolphin kate gwenview okular konsole plasma-integration breeze kscreenlocker playerctl python >/tmp/pacman.log 2>&1; tail -2 /tmp/pacman.log
sudo pacman -S --noconfirm --needed plasma5support 2>&1 | tail -4; pacman -Q plasma5support
mkdir -p /tmp/repo && tar -xzf /tmp/repo.tgz -C /tmp/repo && sudo bash /tmp/repo/session/install.sh 2>&1 | tail -5
ls -la /usr/local/bin/elto-session /usr/local/bin/elto-windowlist /usr/share/wayland-sessions/elto.desktop /etc/xdg/kdeglobals /etc/xdg/kwinrc
sudo systemctl disable --now getty@tty1 2>&1 | tail -1
sudo systemctl enable sddm 2>&1 | tail -1
sudo systemctl start sddm; sleep 30
systemctl is-active sddm; cat /etc/sddm.conf.d/elto.conf'
shot /tmp/vm1.ppm full1_greeter
key() { qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$1\"}]}}" >/dev/null; sleep 0.4; }
$S "mkdir -p ~/.config/elto; echo {} > ~/.config/elto/theme.json"
echo "== wrong password"
for k in x x x ret; do key $k; done; sleep 3
shot /tmp/vm2.ppm full2_wrong
echo "== right password"
sleep 20
$S 'for s in $(loginctl list-sessions --no-legend | cut -d" " -f1); do loginctl show-session $s -p Name -p Type -p Class -p State -p Desktop; done; pgrep -a "kwin|quickshell|elto|foot" | cut -c1-110; echo --- log; tail -15 ~/.local/state/elto-session.log 2>&1; sudo cat /home/dev/.local/state/elto-session.log 2>&1 | tail -12'
shot /tmp/vm3.ppm full3_session
U='sudo -u dev WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus'
click() { # x y in 1280x800
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"abs","data":{"axis":"x","value":'$(($1*32767/1280))'}},{"type":"abs","data":{"axis":"y","value":'$(($2*32767/800))'}}]}}' >/dev/null
sleep 1
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":true,"button":"left"}}]}}' >/dev/null
sleep 0.3
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":false,"button":"left"}}]}}' >/dev/null
sleep 3; }
lockit() { $S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver Lock 2>&1; sleep 8"; }

move() { qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"abs","data":{"axis":"x","value":'$(($1*32767/1280))'}},{"type":"abs","data":{"axis":"y","value":'$(($2*32767/800))'}}]}}' >/dev/null; sleep 1.5; }
rclick() { move $1 $2
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":true,"button":"right"}}]}}' >/dev/null; sleep 0.3
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":false,"button":"right"}}]}}' >/dev/null; sleep 2; }
echo "== default dock"
$S 'qmlfile=/opt/elto-session/panel-widgets/DockWindow.qml; ls /opt/elto-session/panel-widgets | grep -i dock; find / -name "*.qmltypes" 2>/dev/null | xargs grep -l BackgroundEffect 2>/dev/null | head -3; pacman -Q quickshell kwin'
shot /tmp/k1.ppm dk1_default

echo "== relogin"
$S 'sudo loginctl terminate-user dev; sleep 3; sudo systemctl restart sddm; sleep 25; systemctl is-active sddm'
shot /tmp/pk0.ppm pk0_greeter
for k in d e v p a s s ret; do key $k; done; for i in $(seq 1 40); do $S 'pgrep -u dev quickshell >/dev/null' && break; sleep 5; done; sleep 5
$S 'pkill -f welcome.qml; sleep 2; pgrep -a quickshell | cut -c1-80'
echo "== DOCK 58+68"
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
