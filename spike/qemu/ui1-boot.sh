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
echo "== MANAGER #67"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
cat > /tmp/m.sh <<'EOS'
for s in $(loginctl list-sessions --no-legend | awk '$3=="dev"{print $1}'); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && S=$s; done
SCOPE=$(loginctl show-session $S -p Scope --value); echo $$ > /sys/fs/cgroup/user.slice/user-1000.slice/$SCOPE/cgroup.procs
sudo -u dev env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=kde XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus HOME=/home/dev setsid quickshell -p /tmp/repo/elto-worlds/manager/ui/ManagerWindow.qml >/tmp/mgr.log 2>&1 </dev/null &
sleep 25
EOS
cat > /tmp/pick.py <<'EOS'
import json
try:
    d = json.load(open('/tmp/kde.json'))
except Exception as e:
    print("PARSE", e)
    raise SystemExit
items = d.get("items") or []
print("ok", d.get("ok"), "n", len(items), "stale", d.get("stale"))
for it in items[:6]:
    print({k: str(v)[:50] for k, v in it.items() if k in ("title", "kind", "id", "ocsId", "license")})
data = [i for i in items if i.get("kind") != "code"]
json.dump(data[0] if data else {}, open('/tmp/entry.json', 'w'))
print("picked", data[0].get("title") if data else None)
EOS
cat > /tmp/key.py <<'EOS'
import json, sys
d = json.load(sys.stdin)
it = d.get("items") or []
print((it[0].get("key") or it[0].get("id")) if it else "")
EOS
cat > /tmp/cli.sh <<'EOS'
cd /tmp/repo/elto-worlds/manager
R() { sudo -u dev env HOME=/home/dev python3 store.py --cli "$@"; }
echo "--- worlds as the UI runs it (cwd /)"; cd /; sudo -u dev env HOME=/home/dev python3 /tmp/repo/elto-worlds/manager/store.py --cli worlds 2>&1 | head -c 400; echo; python3 --version; cd /tmp/repo/elto-worlds/manager; echo "--- kde worlds"; R kde wallpapers > /tmp/kde.json 2>/tmp/kde.err; head -c 300 /tmp/kde.json; echo; head -3 /tmp/kde.err
cat > /tmp/try.py <<'EOT'
import json, subprocess
for cat in ("color-scheme", "icons", "cursor", "window-frame", "wallpapers"):
    r = subprocess.run(["python3", "store.py", "--cli", "kde", cat], capture_output=True, text=True)
    try:
        items = json.loads(r.stdout).get("items") or []
    except Exception as e:
        print(cat, "PARSE", e); continue
    data = [i for i in items if i.get("kind") != "code"]
    print(cat, "n", len(items), "data", len(data))
    for it in data[:6]:
        r = subprocess.run(["python3", "store.py", "--cli", "installarg", json.dumps(it)], capture_output=True, text=True)
        print(" try", it.get("title"), "->", r.stdout.strip()[:200])
        try:
            if json.loads(r.stdout).get("ok"):
                raise SystemExit
        except json.JSONDecodeError:
            pass
EOT
sudo -u dev env HOME=/home/dev python3 /tmp/try.py 2>&1 | head -c 2500
echo "--- installed"; R installed 2>&1 | head -c 600; echo
KEY=$(R installed 2>/dev/null | python3 /tmp/key.py)
echo "key=$KEY"; echo "--- remove"; R remove "$KEY" 2>&1 | head -c 400; echo; echo "--- installed after"; R installed 2>&1 | head -c 400; echo
EOS
$SC /tmp/m.sh /tmp/pick.py /tmp/key.py /tmp/cli.sh dev@127.0.0.1:/tmp/
$S 'pkill -f "[w]elcome.qml"; sleep 1'
echo "== before: dock / world state"
$S 'sudo -u dev python3 /tmp/repo/elto-worlds/elto-world status 2>&1 | head -c 400; ls /home/dev/.local/share/elto/worlds 2>&1 | head; ls -la /home/dev/.config/elto 2>&1 | head'
$S 'sudo bash /tmp/m.sh; pgrep -a quickshell | cut -c1-120; grep -a -v -E "Unable to assign|locale|portal" /tmp/mgr.log | head -20 | cut -c1-220'
shot /tmp/u1.ppm u1_discover
echo "== click Install on Meadow card"
click 781 400; sleep 6; shot /tmp/u2.ppm u2_after_install_click
$S 'ls /home/dev/.local/share/elto/worlds /home/dev/.local/share/elto/worlds/meadow 2>&1 | head -20; sudo -u dev python3 /tmp/repo/elto-worlds/manager/store.py --cli installed 2>&1 | head -c 500'
echo "== Installed tab"
click 188 104; sleep 5; shot /tmp/u3.ppm u3_installed_tab
echo "== click Apply (guess x=975 y=293)"
click 975 293; sleep 8; shot /tmp/u4.ppm u4_after_apply
$S 'sudo -u dev python3 /tmp/repo/elto-worlds/elto-world status 2>&1 | head -c 500; ls -la /home/dev/.config/elto /home/dev/.local/share/elto 2>&1 | head -20; grep -a -v -E "Unable to assign|locale|portal" /tmp/mgr.log | tail -8 | cut -c1-220'
echo "== Updates tab"
click 270 104; sleep 5; shot /tmp/u5.ppm u5_updates
echo "== Installed tab again then Remove (guess x=1115 y=293)"
click 188 104; sleep 4; shot /tmp/u6.ppm u6_installed_again
click 1115 293; sleep 6; shot /tmp/u7.ppm u7_after_remove
$S 'ls /home/dev/.local/share/elto/worlds 2>&1 | head; sudo -u dev python3 /tmp/repo/elto-worlds/manager/store.py --cli installed 2>&1 | head -c 400; grep -a -v -E "Unable to assign|locale|portal" /tmp/mgr.log | tail -8 | cut -c1-220'
