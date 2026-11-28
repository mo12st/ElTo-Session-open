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
echo "== right-click Terminal"
echo "== NATIVE POLKIT AGENT"
sleep 8
$S 'sudo usermod -aG wheel dev; id dev; ls -l /usr/lib/polkit-1/polkit-agent-helper-1; ls /usr/lib/qt6/qml/Quickshell/Services/Polkit 2>&1 | head -5; pacman -Q quickshell'
echo "== relogin"
$S 'sudo loginctl terminate-user dev; sleep 3; sudo systemctl restart sddm; sleep 25; systemctl is-active sddm'
shot /tmp/pk0.ppm pk0_greeter
for k in d e v p a s s ret; do key $k; done; for i in $(seq 1 40); do $S 'pgrep -u dev quickshell >/dev/null' && break; sleep 5; done; sleep 5
$S 'pkill -f welcome.qml; sleep 2; pgrep -a quickshell | cut -c1-80'
$S 'id; echo --- step3 agent after relogin; pgrep -u dev -af polkit-kde | cut -c1-100; for s in $(loginctl list-sessions --no-legend | cut -d" " -f1); do loginctl show-session $s -p Name -p Type -p Active | tr "\n" " "; echo; done; pgrep -a quickshell | cut -c1-60'
$S 'pgrep -a kwin_wayland|cut -c1-60; pgrep -a quickshell|cut -c1-60; pgrep -af quickshell|cut -c1-90; sudo journalctl -b --no-pager -u sddm | tail -8 | cut -c1-200'
shot /tmp/pk1.ppm pk1_session
cat > /tmp/p2.sh <<'EOS'
# run a helper command inside the graphical session scope so polkit sees the active session
for s in $(loginctl list-sessions --no-legend | awk '$3=="dev"{print $1}'); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && [ "$(loginctl show-session $s -p Remote --value)" = no ] && S=$s; done
SCOPE=$(loginctl show-session $S -p Scope --value); echo S=$S scope=$SCOPE
echo $$ > /sys/fs/cgroup/user.slice/user-1000.slice/$SCOPE/cgroup.procs
H="python3 /tmp/repo/elto-discovery/elto-discovery"
ID=$(sudo -u dev timeout 120 $H search sl 2>/dev/null | python3 -c "
import sys,json
for l in sys.stdin:
    o=json.loads(l)
    for r in o.get('results',[]):
        if r['name']=='sl' and r.get('install_id'): print(r['install_id']); raise SystemExit
"); echo ID=$ID
echo "$ID" > /tmp/sl.id
case "$1" in
 install) (sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 600 $H install "$ID" > /tmp/op.out 2>&1; echo "rc=$?" >> /tmp/op.out) >/dev/null 2>&1 </dev/null & sleep 1;;
 pkcheck) (sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 600 sh -c 'pkcheck --action-id org.freedesktop.packagekit.package-install --process $$ -u' > /tmp/op.out 2>&1; echo rc=$? >> /tmp/op.out) >/dev/null 2>&1 </dev/null & sleep 1;;
 remove) (sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 600 $H remove "sl;5.05-6;x86_64;installed" > /tmp/op.out 2>&1; echo "rc=$?" >> /tmp/op.out) >/dev/null 2>&1 </dev/null & sleep 1;;
esac
EOS
$SC /tmp/p2.sh dev@127.0.0.1:/tmp/
$S 'sudo pacman -Sy --noconfirm --needed packagekit 2>&1 | tail -1; sudo systemctl restart packagekit; sleep 2; which pkgcli'
$S 'echo "== helper perms (before)"; ls -l /usr/lib/polkit-1/polkit-agent-helper-1; findmnt -no OPTIONS /; pacman -Qkk polkit 2>&1 | tail -4; echo --- who changed it: pacman log; grep -i polkit /var/log/pacman.log | tail -5; ls -l /usr/lib/polkit-1/polkit-agent-helper-1'
echo "== polkit agent registration check (no restart)"
$S 'QP=$(pgrep -u dev -x quickshell | head -1); echo qs-pid=$QP; cat /proc/$QP/cgroup; tr "\0" "\n" < /proc/$QP/environ | grep -E "XDG_SESSION|DBUS|WAYLAND"; sudo journalctl -b --no-pager -u polkit | grep -a -i -E "regist|agent|listener" | tail -10; grep -a POLKITREG /home/dev/.local/state/elto-session.log | head | cut -c1-250; sudo journalctl -b --no-pager | grep -a -i -E "quickshell" | tail -5 | cut -c1-250; ls -l /proc/$QP/exe; ldd $(readlink -f /proc/$QP/exe) | grep -i -E "polkit|glib" | head'
type_pw() { shot /tmp/dlg$RANDOM.ppm dlg_before_typing; for k in d e v p a s s ret; do key $k; done; }
LOGF=/home/dev/.local/state/elto-session.log
cnt() { $S "grep -a -c 'POLKITREG isActive=true' $LOGF" 2>/dev/null | tail -1; }
wait_req() { n=$1; for i in $(seq 1 60); do c=$(cnt); [ "${c:-0}" -gt "$n" ] && break; sleep 2; done; echo "request seen c=$c n=$n"; sleep 2; }
cat > /tmp/h.sh <<'EOS'
# run a pkexec helper test inside the graphical session scope; args: tag manifest source-root
for s in $(loginctl list-sessions --no-legend | awk '$3=="dev"{print $1}'); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && [ "$(loginctl show-session $s -p Remote --value)" = no ] && S=$s; done
SCOPE=$(loginctl show-session $S -p Scope --value)
echo $$ > /sys/fs/cgroup/user.slice/user-1000.slice/$SCOPE/cgroup.procs
(sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 300 sh -c "pkexec /usr/lib/elto/elto-worlds-helper install --manifest $2 --source-root $3" > /tmp/h_$1.out 2>&1; echo "rc=$?" >> /tmp/h_$1.out) >/dev/null 2>&1 </dev/null &
sleep 1
EOS
cat > /tmp/hprep.sh <<'EOS'
set -x
install -d -m755 /usr/lib/elto
install -m755 -o root -g root /tmp/repo/elto-worlds/helper/elto-worlds-helper /usr/lib/elto/elto-worlds-helper
install -m644 -o root -g root /tmp/repo/elto-worlds/helper/org.elto.worlds.policy /usr/share/polkit-1/actions/org.elto.worlds.policy
ls -l /usr/lib/elto/elto-worlds-helper /usr/share/polkit-1/actions/org.elto.worlds.policy
pkaction --action-id org.elto.worlds.install --verbose | head -12
sudo -u dev mkdir -p /home/dev/w/src
echo "world data one" | sudo -u dev tee /home/dev/w/src/a.txt >/dev/null
sudo -u dev ln -sf /etc/shadow /home/dev/w/src/link.txt
echo '{"files":[{"src":"a.txt","dest":"world1/a.txt"}]}' | sudo -u dev tee /home/dev/w/ok.json >/dev/null
echo '{"files":[{"src":"shadow","dest":"x/shadow"}]}' | sudo -u dev tee /home/dev/w/etc.json >/dev/null
echo '{"files":[{"src":"a.txt","dest":"../../../../tmp/pwned"}]}' | sudo -u dev tee /home/dev/w/dots.json >/dev/null
echo '{"files":[{"src":"link.txt","dest":"world1/link.txt"}]}' | sudo -u dev tee /home/dev/w/sym.json >/dev/null
echo '{"files":[{"src":"a.txt","dest":"world1/rootowned.txt"}]}' > /home/dev/w/rootm.json; chown root:root /home/dev/w/rootm.json
echo '{"files":[{"src":"a.txt","dest":"/etc/cron.d/x"}]}' | sudo -u dev tee /home/dev/w/abs.json >/dev/null
EOS
$SC /tmp/h.sh /tmp/hprep.sh dev@127.0.0.1:/tmp/
$S 'sudo bash /tmp/hprep.sh 2>&1 | cut -c1-200'
shot_n() { shot /tmp/$1.ppm $1; }
echo "== T0 cancel with Esc"
$S 'sudo bash /tmp/h.sh t0 /home/dev/w/ok.json /home/dev/w/src'
sleep 15; shot_n h0_dialog; key esc; sleep 6
$S 'cat /tmp/h_t0.out; ls -la /usr/share/elto/worlds 2>&1 | head -3'
echo "== T1 valid install, typed password"
$S 'sudo bash /tmp/h.sh t1 /home/dev/w/ok.json /home/dev/w/src'
sleep 15; for k in d e v p a s s ret; do key $k; done; sleep 8
shot_n h1_after_install
$S 'cat /tmp/h_t1.out; ls -la /usr/share/elto/worlds/world1/ 2>&1; stat -c "%U:%G %a %n" /usr/share/elto/worlds/world1/a.txt; cat /usr/share/elto/worlds/world1/a.txt'
for t in "t2 /home/dev/w/etc.json /etc" "t3 /home/dev/w/dots.json /home/dev/w/src" "t4 /home/dev/w/sym.json /home/dev/w/src" "t5 /home/dev/w/rootm.json /home/dev/w/src" "t6 /home/dev/w/abs.json /home/dev/w/src"; do
  set -- $t; echo "== $1 $2 $3"
  $S "sudo bash /tmp/h.sh $1 $2 $3"
  sleep 14; for k in d e v p a s s ret; do key $k; done; sleep 8
  $S "cat /tmp/h_$1.out | head -c 400"
done
shot_n h2_after_escapes
echo "== T7 direct run without pkexec as dev"
$S 'python3 /usr/lib/elto/elto-worlds-helper install --manifest /home/dev/w/ok.json --source-root /home/dev/w/src; echo rc=$?'
echo "== final tree"
$S 'find /usr/share/elto/worlds -type f -exec ls -l {} \; ; ls -l /tmp/pwned /etc/cron.d/x 2>&1 | head -3'
