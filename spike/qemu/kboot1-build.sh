#!/usr/bin/env bash
# kernel #19: build bzImage (same as kern2), then boot it in QEMU against the Arch cloud image root, no initrd, record uname -r.
set -x
sudo apt-get update -qq; sudo apt-get install -y -qq build-essential bc cpio flex bison libelf-dev libssl-dev perl python3 xz-utils dwarves zstd ccache qemu-system-x86 qemu-utils cloud-image-utils sshpass >/dev/null 2>&1
sudo chmod 666 /dev/kvm 2>/dev/null
ROOT=$PWD
cd pr/elto-kernel || exit 1
sed 's/^make -j"\$JOBS"$/make -j"$JOBS" CC="ccache gcc" HOSTCC="ccache gcc" bzImage/' build-elto-kernel.sh > /tmp/bk.sh
cp config-elto.fragment /tmp/config-elto.fragment; sed -i 's#^FRAGMENT=.*#FRAGMENT=/tmp/config-elto.fragment#' /tmp/bk.sh
timeout 1800 bash /tmp/bk.sh /tmp/kb > /tmp/kb.log 2>&1; rc=$?
echo "== KBOOT build rc=$rc"; tail -3 /tmp/kb.log
BZ=$(ls /tmp/kb/cachyos-*/arch/x86/boot/bzImage) || exit 1
CFG=/tmp/kb/cachyos-7.3.6-3/.config
grep -E 'CONFIG_(VIRTIO_BLK|VIRTIO_PCI|EXT4_FS|BTRFS_FS|VIRTIO_NET|SERIAL_8250_CONSOLE|DEVTMPFS_MOUNT|BLK_DEV_INITRD)=' $CFG
cd /tmp
curl -sSL -o arch.qcow2 https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
qemu-img resize arch.qcow2 12G
sudo modprobe nbd max_part=8; sudo qemu-nbd -c /dev/nbd0 arch.qcow2; sleep 2; sudo lsblk -f /dev/nbd0; sudo qemu-nbd -d /dev/nbd0
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
echo "instance-id: kb1" > meta-data; cloud-localds seed.img user-data meta-data
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
for P in 3 2; do
 echo "== boot attempt root=/dev/vda$P"
 rm -f /tmp/serial.log
 qemu-system-x86_64 -accel $ACCEL -m 2048 -smp 2 -cpu max -kernel $BZ -append "root=/dev/vda$P rw console=ttyS0 loglevel=6 systemd.log_level=info" \
  -drive file=arch.qcow2,if=virtio -drive file=seed.img,if=virtio,format=raw -display none -serial file:/tmp/serial.log \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 -pidfile /tmp/q.pid -daemonize
 for i in $(seq 1 40); do
  if sshpass -p devpass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p 2222 dev@127.0.0.1 'echo SSH-UP; uname -r; cat /proc/version' 2>/dev/null; then OK=1; break; fi
  grep -a -q -e 'Kernel panic' -e 'VFS: Unable' /tmp/serial.log && break
  sleep 6
 done
 echo "-- serial tail"; grep -a -e 'Linux version' -e 'panic' -e 'VFS' -e 'Mounted root' -e 'login:' /tmp/serial.log | head -8 | cut -c1-200
 [ -n "$OK" ] && break
 kill $(cat /tmp/q.pid) 2>/dev/null; sleep 2
done
echo "== KBOOT done ok=${OK:-0}"
[ -n "$OK" ]
