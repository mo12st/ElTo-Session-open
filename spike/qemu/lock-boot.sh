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
$S 'sudo pacman -Syu --noconfirm --needed sddm kwin quickshell foot qt6-wayland qt6-svg qt6-declarative mesa libglvnd ttf-dejavu noto-fonts noto-fonts-extra ttf-nunito base-devel wayland plasma-wayland-protocols wayland-protocols libnotify kcalc dolphin plasma-integration breeze kscreenlocker playerctl python >/tmp/pacman.log 2>&1; tail -2 /tmp/pacman.log
mkdir -p /tmp/repo && tar -xzf /tmp/repo.tgz -C /tmp/repo && sudo bash /tmp/repo/session/install.sh 2>&1 | tail -5
ls -la /usr/local/bin/elto-session /usr/local/bin/elto-windowlist /usr/share/wayland-sessions/elto.desktop /etc/xdg/kdeglobals /etc/xdg/kwinrc
sudo systemctl disable --now getty@tty1 2>&1 | tail -1
sudo systemctl enable sddm 2>&1 | tail -1
sudo systemctl start sddm; sleep 30
systemctl is-active sddm; cat /etc/sddm.conf.d/elto.conf'
shot /tmp/vm1.ppm full1_greeter
key() { qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$1\"}]}}" >/dev/null; sleep 0.4; }
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
echo "== installed lock files"
$S 'ls -R /usr/share/plasma/shells/org.elto.shell | head -20; pacman -Q plasma5support playerctl 2>&1; pacman -Ql plasma5support | grep -i "qml" | head -5; pacman -Q plasma-workspace 2>&1'
echo "== mock MPRIS player (test double, not a real media app)"
cat > /tmp/mockplayer.py <<'PY'
import asyncio
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method, dbus_property, PropertyAccess
from dbus_next import Variant
class Root(ServiceInterface):
    def __init__(s): super().__init__('org.mpris.MediaPlayer2')
    @dbus_property(access=PropertyAccess.READ)
    def Identity(s) -> 's': return 'Mock'
    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(s) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(s) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def HasTrackList(s) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(s) -> 'as': return []
    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(s) -> 'as': return []
class Player(ServiceInterface):
    def __init__(s): super().__init__('org.mpris.MediaPlayer2.Player'); s.st='Playing'
    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(s) -> 's': return s.st
    @dbus_property(access=PropertyAccess.READ)
    def Metadata(s) -> 'a{sv}': return {'xesam:title': Variant('s','Weightless'), 'xesam:artist': Variant('as',['Marconi Union']), 'mpris:trackid': Variant('o','/t/1'), 'mpris:length': Variant('x',480000000)}
    @dbus_property(access=PropertyAccess.READ)
    def CanControl(s) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(s) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanPause(s) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(s) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(s) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(s) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def Position(s) -> 'x': return 0
    @dbus_property(access=PropertyAccess.READ)
    def Rate(s) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(s) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(s) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def Volume(s) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def LoopStatus(s) -> 's': return 'None'
    @dbus_property(access=PropertyAccess.READ)
    def Shuffle(s) -> 'b': return False
    @method()
    def PlayPause(s):
        s.st = 'Paused' if s.st=='Playing' else 'Playing'; open('/tmp/mock.log','a').write('PlayPause -> '+s.st+'\n')
        s.emit_properties_changed({'PlaybackStatus': s.st})
    @method()
    def Next(s): open('/tmp/mock.log','a').write('Next\n')
    @method()
    def Previous(s): open('/tmp/mock.log','a').write('Previous\n')
async def main():
    bus = await MessageBus().connect()
    bus.export('/org/mpris/MediaPlayer2', Root()); bus.export('/org/mpris/MediaPlayer2', Player())
    await bus.request_name('org.mpris.MediaPlayer2.mock')
    await asyncio.get_event_loop().create_future()
asyncio.run(main())
PY
$SC /tmp/mockplayer.py dev@127.0.0.1:/tmp/ 2>&1 | tail -1
$S 'python -m venv /tmp/mv && /tmp/mv/bin/pip -q install dbus-next 2>&1 | tail -1'
echo "== LOCK 1: no player, aquarelle (B2)"
lockit
$S "$U sh -c 'journalctl --user -b 2>/dev/null | grep -a ELTOLOCK | tail; true'; sudo journalctl -b 2>/dev/null | grep -a ELTOLOCK | tail -8; grep -a ELTOLOCK /home/dev/.local/state/elto-session.log | tail -8"
shot /tmp/vm1.ppm lock1_noplayer
echo "== LOCK 2: with player"
$S "$U sh -c 'setsid nohup /tmp/mv/bin/python /tmp/mockplayer.py >/tmp/mock.out 2>&1 &'; sleep 5; echo MOCKDIAG; ls -la /tmp/mv/bin/python /tmp/mockplayer.py; pgrep -af mockplayer; $U busctl --user list | grep -i mpris; cat /tmp/mock.out; $U playerctl -l; $U playerctl metadata --format '{{status}}|{{title}}|{{artist}}'; cat /tmp/mock.out"
sleep 4
shot /tmp/vm2.ppm lock2_player
echo "== LOCK 3: wrong password"
for k in x x x ret; do key $k; done; sleep 3
shot /tmp/vm3.ppm lock3_wrong
echo "== LOCK 4: click pause on media card"
click 195 737
$S 'cat /tmp/mock.log 2>&1'; sleep 3
shot /tmp/vm4.ppm lock4_paused
echo "== LOCK 5: right password unlocks"
for k in d e v p a s s ret; do key $k; done; sleep 6
shot /tmp/vm5.ppm lock5_unlocked
echo "== LOCK 6: dusk (B3)"
$S "sudo sed -i 's/property string background: \"aquarelle\"/property string background: \"dusk\"/' /usr/share/plasma/shells/org.elto.shell/contents/lockscreen/LockScreen.qml; grep -n 'property string background' /usr/share/plasma/shells/org.elto.shell/contents/lockscreen/LockScreen.qml"
lockit; sleep 3
shot /tmp/vm6.ppm lock6_dusk
echo "== LOCK 7: Restart button"
$S 'cat /proc/sys/kernel/random/boot_id; uptime -s'
click 1110 706
shot /tmp/vm8.ppm lock7a_after_click
sleep 3
$S 'sudo journalctl -b --no-pager | grep -a ELTOLOCK | tail -5; grep -a ELTOLOCK /home/dev/.local/state/elto-session.log | tail -8'
click 1110 706
$S 'sudo journalctl -b --no-pager 2>/dev/null | grep -a -E "ELTOLOCK run: systemctl|systemd-logind|Reboot" | tail -6; systemctl is-system-running'
sleep 25
for i in $(seq 1 30); do if $S 'cat /proc/sys/kernel/random/boot_id; uptime -s' 2>/dev/null; then break; fi; echo "ssh down ($i)"; sleep 6; done
$S 'sudo journalctl -b -1 2>/dev/null | grep -a -E "ELTOLOCK run|systemctl reboot" | tail -5; last reboot | head -3'
shot /tmp/vm7.ppm lock7_after_restart
