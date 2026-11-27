#!/usr/bin/env bash
# kernel #19 build test v2: same pinned source/config/fragment, but `make bzImage` only (no modules), ccache, 33 min cap.
set -x
sudo apt-get update -qq; sudo apt-get install -y -qq build-essential bc cpio flex bison libelf-dev libssl-dev perl python3 xz-utils dwarves zstd ccache >/dev/null 2>&1
nproc; pahole --version
cd pr/elto-kernel || exit 1
sed 's/^make -j"\$JOBS"$/make -j"$JOBS" CC="ccache gcc" HOSTCC="ccache gcc" bzImage/' build-elto-kernel.sh > /tmp/bk.sh
grep -n 'bzImage' /tmp/bk.sh | head -3
cp config-elto.fragment /tmp/config-elto.fragment
sed -i 's#^FRAGMENT=.*#FRAGMENT=/tmp/config-elto.fragment#' /tmp/bk.sh
START=$(date +%s)
timeout 2000 bash /tmp/bk.sh /tmp/kb > /tmp/kb.log 2>&1; rc=$?
echo "== KERNEL BUILD2 rc=$rc secs=$(( $(date +%s)-START ))"
tail -8 /tmp/kb.log
ls -l /tmp/kb/cachyos-*/arch/x86/boot/bzImage 2>&1
(cd /tmp/kb/cachyos-7.3.6-3 2>/dev/null && make -s kernelrelease; strings arch/x86/boot/bzImage 2>/dev/null | grep -m1 'Linux version')
find /tmp/kb -name '*.o' 2>/dev/null | wc -l
ccache -s | head -5
[ $rc = 0 ]
