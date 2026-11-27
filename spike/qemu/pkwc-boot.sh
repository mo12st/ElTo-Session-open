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
echo "== PACKAGES #21"
$S 'cd /tmp/repo/elto-packages && ./install.sh --dry-run --with-apps --with-windows | head -8; ./install.sh --with-windows; echo "rc-no-multilib=$?"; ./install.sh --bogus; echo "rc-bogus=$?"'
$S 'cd /tmp/repo/elto-packages && cat verify.sh | head -5; (timeout 300 ./verify.sh 2>&1 | tail -4); echo "verify-rc=$?"'
echo "== enable multilib + real install"
$S 'sudo sed -i "/^#\[multilib\]/,/^#Include/ s/^#//" /etc/pacman.conf; grep -A1 "^\[multilib\]" /etc/pacman.conf; cd /tmp/repo/elto-packages && (sudo ./install.sh --with-apps --with-windows >/tmp/pk.log 2>&1; echo "install-rc=$?"; tail -6 /tmp/pk.log); pacman -Q wine winetricks umu-launcher icoutils aurorae 2>&1; pacman -Q | wc -l'
echo "== WINDOWS-COMPAT #20"
$S 'cd /tmp/repo/elto-windows-compat && sudo install -m755 elto-run-windows /usr/bin/elto-run-windows && sudo install -m644 elto-windows.desktop /usr/share/applications/ && sudo install -m644 mimeapps.list /usr/share/applications/mimeapps.list && sudo install -Dm644 elto-windows.conf /usr/lib/binfmt.d/elto-windows.conf && sudo update-desktop-database /usr/share/applications 2>&1 | tail -1; desktop-file-validate /usr/share/applications/elto-windows.desktop && echo desktop-valid; sudo pacman -S --noconfirm --needed mingw-w64-gcc >/tmp/mingw.log 2>&1; tail -1 /tmp/mingw.log; mkdir -p ~/win && cd ~/win && printf "#include <stdio.h>\nint main(){FILE*f=fopen(\"out.txt\",\"w\");fprintf(f,\"hello from windows exe\\n\");fclose(f);puts(\"console hello\");return 0;}\n" > hello.c && x86_64-w64-mingw32-gcc hello.c -o hello.exe && ls -l hello.exe && file hello.exe 2>/dev/null | cut -c1-80'
$S 'gio mime application/x-msdownload 2>&1 | head -3; gio mime application/x-msi 2>&1 | head -2; xdg-mime query default application/x-msdownload'
echo "== run with wine fallback (umu moved away)"
$S 'sudo mv /usr/bin/umu-run /usr/bin/umu-run.off; cd ~/win && rm -f out.txt; export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; timeout 240 elto-run-windows ~/win/hello.exe; echo "wine-rc=$?"; sleep 2; ls ~/win; cat ~/win/out.txt; ls ~/.local/share/elto/prefixes; cat ~/.cache/elto/windows/hello.exe.log | tail -5'
echo "== no wine, no umu message"
$S 'sudo mv /usr/bin/wine /usr/bin/wine.off; export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; elto-run-windows ~/win/hello.exe; echo "none-rc=$?"; sudo mv /usr/bin/wine.off /usr/bin/wine'
echo "== umu path (Proton download, timeout 600s)"
$S 'sudo mv /usr/bin/umu-run.off /usr/bin/umu-run; cd ~/win && rm -f out.txt; export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; timeout 600 elto-run-windows ~/win/hello.exe; echo "umu-rc=$?"; ls ~/win; cat ~/win/out.txt; tail -8 ~/.cache/elto/windows/hello.exe.log'
echo "== msi: not generated here"
echo "== binfmt"
$S 'sudo systemctl restart systemd-binfmt 2>&1 | tail -2; cat /proc/sys/fs/binfmt_misc/ElToWindows 2>&1 | head -4; cd ~/win; chmod +x hello.exe; rm -f out.txt; ./hello.exe; echo "binfmt-rc=$?"; cat out.txt'
shot /tmp/w1.ppm pkwc_end
