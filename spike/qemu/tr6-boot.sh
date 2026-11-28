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
echo "== TRAIL v1"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
$S 'sudo pacman -S --noconfirm --needed udisks2 xdg-utils 2>&1 | tail -1; sudo systemctl start udisks2; sudo install -d /opt/elto-session; sudo rm -rf /opt/elto-session/elto-files; sudo cp -r /tmp/repo/elto-files /opt/elto-session/elto-files; ls /opt/elto-session/elto-files | head -20; lsblk -o NAME,SIZE,RM,TRAN,LABEL,FSTYPE,MOUNTPOINT; pacman -Q quickshell'
cat > /tmp/t0.sh <<'EOS'
for s in $(loginctl list-sessions --no-legend | awk '$3=="dev"{print $1}'); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && S=$s; done
SCOPE=$(loginctl show-session $S -p Scope --value); echo $$ > /sys/fs/cgroup/user.slice/user-1000.slice/$SCOPE/cgroup.procs
D=$(lsblk -nrpo NAME,LABEL | awk '$2=="Backup"{print $1}'); echo usbdev=$D
sudo -u dev udisksctl mount -b $D 2>&1
sudo -u dev mkdir -p /home/dev/Documents/"Garden plan" /home/dev/Documents/Letters /home/dev/Documents/Recipes /home/dev/Downloads /home/dev/Pictures /home/dev/Music /home/dev/Videos
sudo -u dev sh -c 'cd /home/dev/Documents; echo hello > Notes.md; echo lease > Lease.txt; printf "%%PDF-1.4\n" > Lease.pdf; echo z > Backup.zip; echo a > /home/dev/Downloads/a.txt'
sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=kde XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HOME=/home/dev TRAIL_START=$1 setsid quickshell -p /opt/elto-session/elto-files/trail.qml > /tmp/trail.log 2>&1 < /dev/null &
sleep 18
EOS
$SC /tmp/t0.sh dev@127.0.0.1:/tmp/
$S 'pkill -f welcome.qml; sudo bash /tmp/t0.sh /home/dev/Documents; cat /tmp/trail.log | grep -a -v "Unable to assign" | head -30; pgrep -a quickshell | cut -c1-90'
shot /tmp/tr1.ppm tr1_trail_documents
$S 'pkill -u dev -f "[e]lto-files/trail.qml"; sleep 2'
$S 'sudo bash /tmp/t0.sh computer; grep -a -v "Unable to assign" /tmp/trail.log | head -20'
shot /tmp/tr2.ppm tr2_this_computer


chk() { $S 'echo "-- procs"; pgrep -a -f "elto-files/trail.qml" | cut -c1-120; echo "-- trail.log"; grep -a -v -E "Unable to assign|locale|UTF-8|more information|Qt 6.12" /tmp/trail.log | tail -15 | cut -c1-260; echo "-- journal"; sudo journalctl -b --no-pager | grep -a -i -E "segfault|coredump|core dumped|quickshell.*(abort|fatal)" | tail -5 | cut -c1-240'; }
cat > /tmp/wa.sh <<'EOS'
W=$1
sudo -u dev env HOME=/home/dev XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ASSIGN=1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus python3 /tmp/repo/elto-worlds/elto-world apply /tmp/repo/elto-worlds/worlds/$W 2>&1 | tail -3 | cut -c1-200
sleep 5
EOS
$SC /tmp/wa.sh dev@127.0.0.1:/tmp/
echo "== A: fresh Trail on This computer, no world change"
$S 'pkill -u dev -f "[e]lto-files/trail.qml"; sleep 2; sudo bash /tmp/t0.sh computer'
chk
shot /tmp/a1.ppm a1_computer_default
echo "== B: apply aero while open"
$S 'sudo bash /tmp/wa.sh aero'
chk
shot /tmp/a2.ppm a2_after_aero
echo "== C: apply retro95 while open"
$S 'sudo bash /tmp/wa.sh retro95'
chk
shot /tmp/a3.ppm a3_after_retro95
echo "== D: Documents path start"
$S 'pkill -u dev -f "[e]lto-files/trail.qml"; sleep 2; sudo bash /tmp/t0.sh /home/dev/Documents'
chk
shot /tmp/a4.ppm a4_documents_retro95
