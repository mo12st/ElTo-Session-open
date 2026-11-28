#!/bin/bash
# Kernel build probe on the runner host (no VM): bzImage only, time-capped, then boot with qemu -kernel + busybox initramfs.
set -x
MODE=after
REPO=$PWD; K=$REPO/pr/elto-kernel
W=/tmp/kb; mkdir -p $W; cd $W
sudo apt-get update -qq; sudo apt-get install -y -qq bc cpio flex bison libelf-dev libssl-dev pahole busybox-static qemu-system-x86 xz-utils >/dev/null 2>&1; pahole --version; nproc; free -m | head -2; gcc --version | head -1
curl -fsSL --retry 3 -o src.tgz https://github.com/CachyOS/linux/releases/download/cachyos-7.3.6-3/cachyos-7.3.6-3.tar.gz
echo "e82ccb70388414378ccb559fb6aa5bea525127c89ceb01b75d4b3ab960049893  src.tgz" | sha256sum -c -
curl -fsSL --retry 3 -o config-cachyos https://raw.githubusercontent.com/CachyOS/linux-cachyos/25259ced6c7c8c68796d2a47d98cafb96ccdd603/linux-cachyos/config
echo "32b3c2004bf8640a1a280f0ceeab7a434765eb4d246cb81911ecff112dde6f50  config-cachyos" | sha256sum -c -
tar xzf src.tgz; cd cachyos-7.3.6-3
cp ../config-cachyos .config
FR="$K/config-elto.fragment"; [ "$MODE" = after ] && FR="$FR $K/config-elto-trim.fragment"
./scripts/kconfig/merge_config.sh -m .config $FR >/dev/null; make olddefconfig >/dev/null
echo "MODE=$MODE modules(m)=$(grep -c '=m$' .config) builtin(y)=$(grep -c '=y$' .config)"
START=$(date +%s)
timeout 1950 make -j$(nproc) bzImage >/tmp/kb/build.log 2>&1; RC=$?
END=$(date +%s)
echo "BUILD rc=$RC seconds=$((END-START)) mode=$MODE"
tail -3 /tmp/kb/build.log
echo "objects compiled so far: $(grep -c -E '^\s+CC' /tmp/kb/build.log)"
ls -la arch/x86/boot/bzImage || exit 0
make -s kernelrelease
# boot test
mkdir -p /tmp/kb/ir/bin; cp /usr/bin/busybox /tmp/kb/ir/bin/; cd /tmp/kb/ir
cat > init <<'EOI'
#!/bin/busybox sh
/bin/busybox mkdir -p /proc /sys /dev
/bin/busybox mount -t proc none /proc; /bin/busybox mount -t sysfs none /sys
echo "BOOTED uname=$(/bin/busybox uname -r)"; /bin/busybox cat /proc/version; /bin/busybox uptime
/bin/busybox poweroff -f
EOI
chmod +x init; find . | cpio -o -H newc 2>/dev/null | gzip > /tmp/kb/ir.gz
B=$(date +%s)
timeout 240 qemu-system-x86_64 -accel kvm -cpu max -m 1024 -smp 2 -kernel /tmp/kb/cachyos-7.3.6-3/arch/x86/boot/bzImage -initrd /tmp/kb/ir.gz -append "console=ttyS0 panic=-1 quiet loglevel=3" -nographic -no-reboot 2>&1 | tail -15
echo "QEMU seconds=$(( $(date +%s)-B ))"
