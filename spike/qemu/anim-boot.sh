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
echo "== provision anim"
SC="sshpass -p devpass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222"
ls $REPO/pr/panel-widgets
$SC -r $REPO/pr/panel-widgets $REPO/pr/plugin/windowlist dev@127.0.0.1:/tmp/ 2>&1 | tail -2
$S 'sudo pacman -Syu --noconfirm --needed kwin quickshell foot qt6-wayland mesa libglvnd ttf-dejavu base-devel wayland plasma-wayland-protocols wayland-protocols >/tmp/pacman.log 2>&1; tail -1 /tmp/pacman.log
cd /tmp/windowlist && make 2>&1 | tail -1 && cp elto-windowlist /tmp/elto-windowlist && ls -la /tmp/elto-windowlist'
$S 'cat > /tmp/asession.sh <<EOS
#!/bin/bash
exec > /tmp/session.log 2>&1
export XDG_RUNTIME_DIR=/run/user/\$(id -u) XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus
kwin_wayland --socket wayland-0 --no-lockscreen &
sleep 8
export WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland
quickshell -p /tmp/panel-widgets/shell-spike.qml > /tmp/qs.log 2>&1 &
sleep 4
foot -T winA -e sh -c "sleep 3000" &
wait
EOS
chmod +x /tmp/asession.sh
echo "[ \"\$(tty)\" = /dev/tty1 ] && exec bash /tmp/asession.sh" > /home/dev/.bash_profile
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
printf "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin dev --noclear %%I linux\n" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
sudo systemctl daemon-reload; sudo systemctl restart getty@tty1; sleep 35
grep -a -v "^$" /tmp/qs.log | tail -25; pgrep -a quickshell | head -2'
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
cat > /tmp/frames.py <<'PY'
import socket,json,sys,time
n=int(sys.argv[1]); dt=float(sys.argv[2]); pre=sys.argv[3]
acts=sorted((float(x.split("@",1)[0]),x.split("@",1)[1]) for x in sys.argv[4:])
s=socket.socket(socket.AF_UNIX);s.connect('/tmp/qmp.sock');f=s.makefile('rw')
f.readline();f.write(json.dumps({"execute":"qmp_capabilities"})+"\n");f.flush();f.readline()
def send(o):
    f.write(json.dumps(o)+"\n");f.flush();return f.readline()
def mv(x,y): return {"execute":"input-send-event","arguments":{"events":[{"type":"abs","data":{"axis":"x","value":x*32767//1280}},{"type":"abs","data":{"axis":"y","value":y*32767//800}}]}}
def btn(d): return {"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":d,"button":"left"}}]}}
t0=time.time(); log=[]
for i in range(n):
    t=time.time()-t0
    while acts and acts[0][0]<=t:
        a=acts.pop(0)[1]
        if a=="hover": send(mv(215,771))
        elif a=="away": send(mv(60,700))
        elif a=="down": send(btn(True))
        elif a=="up": send(btn(False))
        log.append((round(t,2),a))
    send({"execute":"screendump","arguments":{"filename":"/tmp/%s%02d.ppm"%(pre,i)}})
    time.sleep(dt)
print(pre,"actions",log,"total",round(time.time()-t0,2))
PY
sheet() { # prefix name
  montage /tmp/$1[0-9][0-9].ppm -crop 400x56+170+744 +repage -tile 4x -geometry +2+2 -background '#888' /tmp/$2.png 2>&1 | head -2; ls -la /tmp/$2.png
  echo "===== BEGIN-SHOT $2 ====="; base64 -w0 /tmp/$2.png; echo; }
SSHT="sshpass -p devpass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 dev@127.0.0.1"
shot /tmp/vm1.ppm vm1
echo "== 1 appear: winC spawns in the VM about 0.6 s after frames start"
$SSHT 'nohup sh -c "sleep 0.8; XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 foot -T winC -e sh -c \"sleep 3000\"" >/dev/null 2>&1 &'
python3 /tmp/frames.py 28 0.05 ap
sheet ap appear
sleep 2
echo "== 2 hover: pointer to pill after 0.4 s, away after 1.0 s"
qmp '{"execute":"input-send-event","arguments":{"events":[{"type":"abs","data":{"axis":"x","value":'$((60*32767/1280))'}},{"type":"abs","data":{"axis":"y","value":'$((700*32767/800))'}}]}}' >/dev/null
sleep 1
python3 /tmp/frames.py 28 0.05 hv 0.4@hover 1.0@away
sheet hv hover
echo "== 3 press: hover, down at 0.4 s, up at 1.0 s"
python3 /tmp/frames.py 28 0.05 pr 0.0@hover 0.4@down 1.0@up
sheet pr press
python3 /tmp/frames.py 1 0 pz 0.0@away
sleep 2
shot /tmp/vm2.ppm vm2
echo "== 4 disappear: winC killed in the VM about 0.8 s after frames start"
$SSHT 'nohup sh -c "sleep 0.8; pkill -f \"[f]oot -T winC\"" >/dev/null 2>&1 &'
python3 /tmp/frames.py 28 0.05 dp
sheet dp disappear
sleep 1
shot /tmp/vm3.ppm vm3
$S 'grep -a -i -E "error|crash|segv|abort" /tmp/qs.log | head -5; pgrep -a quickshell | head -1'
