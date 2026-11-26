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
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
echo "ACCEL=$ACCEL"
qemu-system-x86_64 -accel $ACCEL -m 4096 -smp 2 -cpu max \
  -drive file=arch.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw \
  -device virtio-vga -device qemu-xhci -device usb-tablet -display none -serial file:/tmp/serial.log \
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
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot /tmp/vm1.ppm vm1
shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
echo "== provision lockfix"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
$SC -r $REPO/spike/lock dev@127.0.0.1:/tmp/ 2>&1 | tail -2
inst() { $S "sudo pacman -S --noconfirm --needed $1 >/tmp/pacman2.log 2>&1; tail -1 /tmp/pacman2.log"; }
rep() { $S 'echo "-- plasma-workspace?"; pacman -Q plasma-workspace 2>&1; pacman -Qi plasma-workspace 2>/dev/null | grep -E "^(Version|Install Reason|Required By)"; echo "installed total: $(pacman -Qq | wc -l)"'; }
$S 'sudo pacman -Syu --noconfirm --needed kwin foot qt6-wayland mesa libglvnd ttf-dejavu kscreenlocker >/tmp/pacman.log 2>&1; tail -1 /tmp/pacman.log'
echo "== STEP base (kwin kscreenlocker foot)"; rep
echo "== STEP + kcalc"; inst kcalc; rep
echo "== STEP + plasma-integration breeze"; inst "plasma-integration breeze"; rep
echo "== STEP + dolphin"; inst dolphin; rep
$S 'pacman -Qi plasma-workspace 2>/dev/null | grep -E "^Depends On"; for p in dolphin kcalc plasma-integration breeze kscreenlocker; do echo "$p depends on plasma*:"; pacman -Qi $p | grep -E "^Depends On" | tr " " "\n" | grep -i plasma; done'
$S 'D=~/.local/share/plasma/shells/org.elto.shell; mkdir -p $D/contents/lockscreen ~/.config; cp /tmp/lock/metadata.json $D/; cp /tmp/lock/LockScreen.qml $D/contents/lockscreen/
L=~/.local/share/plasma/look-and-feel/org.elto.lockscreen; mkdir -p $L/contents/lockscreen
printf "{\"KPlugin\":{\"Id\":\"org.elto.lockscreen\",\"Name\":\"ElTo spike lock\"},\"KPackageStructure\":\"Plasma/LookAndFeel\"}\n" > $L/metadata.json
cp /tmp/lock/LockScreen.qml $L/contents/lockscreen/
printf "[Greeter]\nTheme=org.elto.shell\n" > ~/.config/kscreenlockerrc
cat > /tmp/lsession.sh <<EOS
#!/bin/bash
exec > /tmp/session.log 2>&1
export XDG_RUNTIME_DIR=/run/user/\$(id -u) XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus QT_LOGGING_RULES="*kscreenlocker*=true"
kwin_wayland --socket wayland-0 &
sleep 8
export WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland
foot -e sh -c "sleep 3000" &
wait
EOS
chmod +x /tmp/lsession.sh
echo "[ \"\$(tty)\" = /dev/tty1 ] && exec bash /tmp/lsession.sh" > /home/dev/.bash_profile
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
printf "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin dev --noclear %%I linux\n" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
sudo systemctl daemon-reload; sudo systemctl restart getty@tty1; sleep 30'
qmp() { python3 - "$@" <<'PY'
import socket,json,sys
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
for a in sys.argv[1:]:
    f.write(a+"\n");f.flush();print(f.readline().strip())
PY
}
click() { # x y in 1280x800
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"abs","data":{"axis":"x","value":'$(($1*32767/1280))'}},{"type":"abs","data":{"axis":"y","value":'$(($2*32767/800))'}}]}}' >/dev/null
sleep 1
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":true,"button":"left"}}]}}' >/dev/null
sleep 0.3
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":false,"button":"left"}}]}}' >/dev/null
sleep 3; }
U='sudo -u dev XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus'
echo "== LOCK 1: Theme=org.elto.shell (Plasma/Shell package)"
$S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver Lock 2>&1; sleep 8; grep -a -i -E 'SPIKELOCK|greeter|theme|lookandfeel|look-and-feel' /tmp/session.log | tail -8"
shot /tmp/vm1.ppm vm1
$S 'sudo loginctl unlock-sessions; sleep 3; printf "[Greeter]\nTheme=org.elto.lockscreen\n" > ~/.config/kscreenlockerrc; : > /tmp/mark'
echo "== LOCK 2: Theme=org.elto.lockscreen (Plasma/LookAndFeel package)"
$S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver Lock 2>&1; sleep 8; grep -a -i -E 'SPIKELOCK|greeter|theme|lookandfeel|look-and-feel' /tmp/session.log | tail -8"
shot /tmp/vm2.ppm vm2
