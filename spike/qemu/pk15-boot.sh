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
 install) (sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 100 $H install "$ID" > /tmp/op.out 2>&1; echo "rc=$?" >> /tmp/op.out) & sleep 1;;
 pkcheck) (timeout 40 pkcheck --action-id org.freedesktop.packagekit.package-install --process $$ -u > /tmp/op.out 2>&1; echo rc=$? >> /tmp/op.out) & sleep 1;;
 remove) (sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 timeout 100 $H remove "sl;5.05-6;x86_64;installed" > /tmp/op.out 2>&1; echo "rc=$?" >> /tmp/op.out) & sleep 1;;
esac
EOS
$SC /tmp/p2.sh dev@127.0.0.1:/tmp/
$S 'sudo pacman -Sy --noconfirm --needed packagekit 2>&1 | tail -1; sudo systemctl restart packagekit; sleep 2; which pkgcli'
$S 'echo "== helper perms (before)"; ls -l /usr/lib/polkit-1/polkit-agent-helper-1; findmnt -no OPTIONS /; pacman -Qkk polkit 2>&1 | tail -4; echo --- who changed it: pacman log; grep -i polkit /var/log/pacman.log | tail -5; ls -l /usr/lib/polkit-1/polkit-agent-helper-1'
echo "== polkit agent registration check (no restart)"
$S 'QP=$(pgrep -u dev -x quickshell | head -1); echo qs-pid=$QP; cat /proc/$QP/cgroup; tr "\0" "\n" < /proc/$QP/environ | grep -E "XDG_SESSION|DBUS|WAYLAND"; sudo journalctl -b --no-pager -u polkit | grep -a -i -E "regist|agent|listener" | tail -10; grep -a POLKITREG /home/dev/.local/state/elto-session.log | head | cut -c1-250; sudo journalctl -b --no-pager | grep -a -i -E "quickshell" | tail -5 | cut -c1-250; ls -l /proc/$QP/exe; ldd $(readlink -f /proc/$QP/exe) | grep -i -E "polkit|glib" | head'
echo "== pkcheck routing test"
$S 'sudo bash /tmp/p2.sh pkcheck; sleep 6; grep -a POLKITREG /home/dev/.local/state/elto-session.log; cat /tmp/op.out; sudo journalctl -b --no-pager -u polkit | tail -12 | cut -c1-250'
shot /tmp/pkc.ppm pkc_pkcheck_dialog
sleep 3
echo "== step4 install sl"
$S 'sudo bash /tmp/p2.sh install'
sleep 8; cat > /tmp/w.js <<'EOJ'
var ws = workspace.windowList();
for (var i = 0; i < ws.length; i++) { var w = ws[i]; print("POLKITDIAG|" + w.caption + "|" + w.resourceClass + "|" + JSON.stringify(w.frameGeometry) + "|below=" + w.keepBelow + "|min=" + w.minimized + "|layer=" + w.layer + "|vis=" + w.hidden + "|desktopWin=" + w.desktopWindow + "|dock=" + w.dock); }
EOJ
$SC /tmp/w.js dev@127.0.0.1:/tmp/
$S 'export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; sleep 4; ID=$(busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript ss /tmp/w.js pdiag | awk "{print \$2}"); echo scriptid=$ID; busctl --user call org.kde.KWin /Scripting/Script$ID org.kde.kwin.Script run; sleep 2; grep -a POLKITDIAG ~/.local/state/elto-session.log | tail -12 | cut -c1-300'
shot /tmp/pk2.ppm pk2_auth_dialog_install
for k in d e v p a s s ret; do key $k; done; sleep 15
$S 'grep -a -i -E "polkit|agent|PolkitDialog" /home/dev/.local/state/elto-session.log | tail -25 | cut -c1-250; cat /tmp/op.out | cut -c1-300; pacman -Q sl; sudo journalctl -b --no-pager -u polkit -u packagekit | tail -5 | cut -c1-220'
$S 'echo --- agent alive?; pgrep -af quickshell | cut -c1-90; echo --- session log tail; tail -25 ~/.local/state/elto-session.log | cut -c1-220; echo --- journal agent-helper; sudo journalctl -b --no-pager | grep -i -E "polkit-agent|pam|authentication agent|polkit-kde" | tail -12 | cut -c1-240'
shot /tmp/pk3.ppm pk3_after_install
echo "== step5 remove sl"
$S 'sudo bash /tmp/p2.sh remove'
sleep 8; shot /tmp/pk4.ppm pk4_remove_state
for k in d e v p a s s ret; do key $k; done; sleep 12
$S 'cat /tmp/op.out | cut -c1-300; pacman -Q sl 2>&1'
echo "== step6 wrong password then cancel"
$S 'sudo bash /tmp/p2.sh install'
sleep 8; for k in x x x x ret; do key $k; done; sleep 4; shot /tmp/pk5.ppm pk5_wrong_password
key esc; sleep 8
$S 'cat /tmp/op.out | cut -c1-300; pacman -Q sl 2>&1'
shot /tmp/pk6.ppm pk6_after_cancel
echo "== step7 non-wheel (dev removed from wheel temporarily)"
$S 'sudo gpasswd -d dev wheel; id dev; sudo bash /tmp/p2.sh install'
sleep 8; shot /tmp/pk7.ppm pk7_nonwheel_dialog
for k in d e v p a s s ret; do key $k; done; sleep 6; key esc; sleep 8
$S 'cat /tmp/op.out | cut -c1-300; pacman -Q sl 2>&1; sudo gpasswd -a dev wheel'
echo "== non-wheel user without a session"
$S 'sudo useradd -m nw; echo nw:nwpass | sudo chpasswd; sudo -u nw timeout 60 python3 /tmp/repo/elto-discovery/elto-discovery install "$(cat /tmp/sl.id)" 2>&1 | cut -c1-300; pacman -Q sl 2>&1'
