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
for k in d e v p a s s ret; do key $k; done; sleep 30
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
echo "== right-click Terminal"
echo "== enable multilib + real install"
$S "cat > /tmp/pk2.sh" <<'EOS'
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
grep -A1 '^\[multilib\]' /etc/pacman.conf
cd /tmp/repo/elto-packages
sudo ./install.sh --with-apps --with-windows >/tmp/pk.log 2>&1; echo "install-rc=$?"; tail -6 /tmp/pk.log
pacman -Q wine winetricks umu-launcher icoutils aurorae 2>&1
EOS
$S 'bash /tmp/pk2.sh'
echo "== WINDOWS-COMPAT #20"
$S "cat > /tmp/wc1.sh" <<'EOS'
cd /tmp/repo/elto-windows-compat
sudo install -m755 elto-run-windows /usr/bin/elto-run-windows
sudo install -m644 elto-windows.desktop /usr/share/applications/
sudo install -m644 mimeapps.list /usr/share/applications/mimeapps.list
sudo install -Dm644 elto-windows.conf /usr/lib/binfmt.d/elto-windows.conf
sudo update-desktop-database /usr/share/applications 2>&1 | tail -1
desktop-file-validate /usr/share/applications/elto-windows.desktop && echo desktop-valid
sudo pacman -S --noconfirm --needed mingw-w64-gcc >/tmp/mingw.log 2>&1; tail -1 /tmp/mingw.log
mkdir -p ~/win; cd ~/win
cat > hello.c <<'EOC'
#include <stdio.h>
int main(void){ FILE *f=fopen("out.txt","w"); fprintf(f,"hello from windows exe\n"); fclose(f); puts("console hello"); return 0; }
EOC
x86_64-w64-mingw32-gcc hello.c -o hello.exe && ls -l hello.exe
gio mime application/x-msdownload 2>&1 | head -3
xdg-mime query default application/x-msdownload
EOS
$S 'bash /tmp/wc1.sh'
echo "== wine diagnostics (headless env, no wayland)"
$S "cat > /tmp/wd.sh" <<'EOS'
sudo mv /usr/bin/umu-run /usr/bin/umu-run.off
cd ~/win; rm -f out.txt
unset WAYLAND_DISPLAY DISPLAY
export WINEPREFIX=/tmp/wp1 WINEDEBUG=-all
date; time timeout 500 wine hello.exe; echo "wine-direct-rc=$?"; date
ls ~/win; cat ~/win/out.txt
EOS
$S 'bash /tmp/wd.sh 2>&1 | tail -20'
echo "== elto-run-windows via wine, headless env"
$S "cat > /tmp/wd2.sh" <<'EOS'
cd ~/win; rm -f out.txt
unset WAYLAND_DISPLAY DISPLAY
export WINEDEBUG=-all
date; timeout 500 elto-run-windows ~/win/hello.exe; echo "erw-rc=$?"; date
ls ~/win; cat ~/win/out.txt; tail -4 ~/.cache/elto/windows/hello.exe.log
EOS
$S 'bash /tmp/wd2.sh 2>&1 | tail -20'
echo "== binfmt"
$S "cat > /tmp/wc4.sh" <<'EOS'
sudo systemctl restart systemd-binfmt 2>&1 | tail -2
cat /proc/sys/fs/binfmt_misc/ElToWindows 2>&1 | head -4
cd ~/win; chmod +x hello.exe; rm -f out.txt
unset WAYLAND_DISPLAY DISPLAY; export WINEDEBUG=-all
timeout 300 ./hello.exe; echo "binfmt-rc=$?"; cat out.txt
EOS
$S 'bash /tmp/wc4.sh 2>&1 | tail -12'
shot /tmp/w1.ppm pkwc3_end
