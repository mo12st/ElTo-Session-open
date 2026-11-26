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
echo "== provision sddm theme"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
$SC -r $REPO/pr/spike/sddm/elto-classic $REPO/spike/qemu/session.sh $REPO/spike/shell.qml dev@127.0.0.1:/tmp/ 2>&1 | tail -2
$S 'sudo pacman -Syu --noconfirm --needed sddm kwin quickshell foot qt6-wayland qt6-svg qt6-declarative mesa libglvnd ttf-dejavu noto-fonts noto-fonts-extra ttf-nunito >/tmp/pacman.log 2>&1; tail -2 /tmp/pacman.log; pacman -Q sddm; fc-list | grep -ci "Nunito"; fc-list | grep -ci "Noto Serif Display"
sudo install -m755 /tmp/session.sh /usr/local/bin/elto-session
sudo mkdir -p /usr/share/wayland-sessions /etc/sddm.conf.d /usr/share/sddm/themes
sudo cp -r /tmp/elto-classic /usr/share/sddm/themes/
printf "[Desktop Entry]\nName=ElTo\nExec=/usr/local/bin/elto-session\nType=Application\n" | sudo tee /usr/share/wayland-sessions/elto.desktop >/dev/null
printf "[Theme]\nCurrent=elto-classic\n[General]\nDisplayServer=wayland\n[Wayland]\nCompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1\n" | sudo tee /etc/sddm.conf.d/elto.conf >/dev/null
sudo systemctl disable --now getty@tty1 2>&1 | tail -1
sudo systemctl enable sddm 2>&1 | tail -1
sudo systemctl start sddm; sleep 30
systemctl is-active sddm; ps aux | grep -E "sddm|kwin" | grep -v grep | cut -c1-150
sudo journalctl -u sddm --no-pager | tail -20 | cut -c1-200'
shot /tmp/vm1.ppm sddm1_greeter
key() { qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$1\"}]}}" >/dev/null; sleep 0.4; }
echo "== wrong password"
for k in x x x ret; do key $k; done; sleep 3
shot /tmp/vm2.ppm sddm2_wrong
echo "== right password"
for k in d e v p a s s ret; do key $k; done; sleep 25
$S 'loginctl list-sessions --no-legend; for s in $(loginctl list-sessions --no-legend | cut -d" " -f1); do loginctl show-session $s -p Name -p Type -p Class -p State; done; ps aux | grep -E "kwin|quickshell|foot" | grep -v grep | cut -c1-120'
shot /tmp/vm3.ppm sddm3_session
