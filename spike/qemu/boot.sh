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
  -device virtio-vga -display none -serial file:/tmp/serial.log \
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

echo "== provision"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
$SC $REPO/spike/qemu/session.sh $REPO/spike/shell.qml $REPO/spike/lock/metadata.json $REPO/spike/lock/LockScreen.qml dev@127.0.0.1:/tmp/ 2>&1 | tail -2
$S 'sudo pacman -Syu --noconfirm --needed kwin quickshell foot qt6-wayland mesa libglvnd ttf-dejavu kscreenlocker >/tmp/pacman.log 2>&1; tail -3 /tmp/pacman.log; pacman -Q kwin quickshell qt6-base' 
$S 'sudo chmod +x /tmp/session.sh
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
printf "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin dev --noclear %%I linux\n" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
echo "[ \"\$(tty)\" = /dev/tty1 ] && exec bash /tmp/session.sh" > /home/dev/.bash_profile
sudo systemctl daemon-reload; sudo systemctl restart getty@tty1; sleep 30
loginctl list-sessions --no-legend; cat /tmp/session.log 2>&1 | tail -30; tail -12 /tmp/qs.log 2>&1; ps aux | grep -E "kwin|quickshell|foot" | grep -v grep | cut -c1-150; ls /dev/dri'
shot() { rm -f "$1"; python3 - "$1" <<'PY'
import socket,json,sys,time
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
f.write(json.dumps({"execute":"screendump","arguments":{"filename":sys.argv[1]}})+"\n");f.flush();print(f.readline().strip())
PY
convert /tmp/$2.ppm /tmp/$2.png 2>&1; ls -la /tmp/$2.png; echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
shot /tmp/vm1.ppm vm1
qmp() { python3 - "$@" <<'PY'
import socket,json,sys
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
for a in sys.argv[1:]:
    f.write(a+"\n");f.flush();print(f.readline().strip())
PY
}
U='sudo -u dev XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus'
echo "== lock: services, pam, themes"
$S "$U busctl --user list 2>&1 | grep -i -E 'screensaver|kscreenlocker|ksld'; echo --; ls /etc/pam.d | grep -i -E 'kde|login|system-auth'; echo --; pacman -Ql kscreenlocker | grep -E 'greet|pam|lookandfeel' | head; ls /usr/share/plasma/look-and-feel 2>&1 | head"
echo "== install spike lock package and select it"
$S 'D=/home/dev/.local/share/plasma/shells/org.elto.shell; mkdir -p $D/contents/lockscreen; cp /tmp/metadata.json $D/; cp /tmp/LockScreen.qml $D/contents/lockscreen/; mkdir -p /home/dev/.config
printf "[Shell]\nShellPackage=org.elto.shell\n" > /home/dev/.config/plasmashellrc
printf "[Greeter]\nTheme=org.elto.shell\n" > /home/dev/.config/kscreenlockerrc
find $D -type f; kscreenlocker_greet --help 2>&1 | head -20'
echo "== lock: trigger"
$S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver Lock 2>&1; sleep 1; $U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver GetActive 2>&1; $U loginctl lock-session 2>&1 | head -2"
for i in $(seq 1 30); do N=$($S "grep -a -c 'Ping received' /tmp/session.log" 2>/dev/null); echo "pings=$N"; [ "${N:-0}" -ge 2 ] && break; sleep 4; done
$S 'ps aux | grep -E "kscreenlocker|kwin" | grep -v grep | cut -c1-160; grep -a -i -E "kscreenlocker|SPIKELOCK|Lockscreen|qrc|import" /tmp/session.log | tail -15; ps aux | grep kscreenlocker_greet | grep -v grep | cut -c1-200'
shot /tmp/vm2.ppm vm2
waitlog() { for i in $(seq 1 25); do N=$($S "grep -a -c '$1' /tmp/session.log" 2>/dev/null); [ "${N:-0}" -ge 1 ] && { echo "seen: $1 after $((i*4)) s"; return 0; }; sleep 4; done; echo "NOT seen within 100 s: $1"; return 1; }
echo "== lock: wrong password"
for k in x x x ret; do qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$k\"}]}}"; sleep 0.4; done
waitlog 'SPIKELOCK failed'
$S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver GetActive 2>&1"
shot /tmp/vm3.ppm vm3
echo "== lock: right password"
sleep 15
$S 'grep -a -E "SPIKELOCK|Unlocking|succeed|fail" /tmp/session.log | tail -8'
for k in d e v p a s s ret; do qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$k\"}]}}"; sleep 0.4; done
waitlog 'SPIKELOCK succeeded'
$S 'faillock --user dev 2>&1; grep -a "SPIKELOCK enter" /tmp/session.log; cat /etc/pam.d/system-auth | head -20'
$S 'grep -a -E "SPIKELOCK|Unlocking|succeed|fail|PamAuth" /tmp/session.log | tail -12'
$S "$U busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver GetActive 2>&1; ps aux | grep -E 'kscreenlocker_greet' | grep -v grep | wc -l; tail -25 /tmp/session.log"
shot /tmp/vm4.ppm vm4
