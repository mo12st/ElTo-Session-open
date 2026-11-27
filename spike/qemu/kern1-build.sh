#!/usr/bin/env bash
# kernel #19 build test on the runner host (no VM): runs elto-kernel/build-elto-kernel.sh with a time cap.
set -x
sudo apt-get update -qq; sudo apt-get install -y -qq build-essential bc cpio flex bison libelf-dev libssl-dev perl python3 xz-utils dwarves zstd >/dev/null 2>&1
nproc; free -m | head -2; df -h / | tail -1; pahole --version
cd pr/elto-kernel || exit 1
START=$(date +%s)
timeout 1950 bash ./build-elto-kernel.sh /tmp/kb > /tmp/kb.log 2>&1; rc=$?
echo "== KERNEL BUILD rc=$rc secs=$(( $(date +%s)-START ))"
tail -15 /tmp/kb.log
ls -l /tmp/kb/cachyos-*/arch/x86/boot/bzImage 2>&1
(cd /tmp/kb/cachyos-* 2>/dev/null && make -s kernelrelease)
find /tmp/kb -name '*.o' 2>/dev/null | wc -l
[ $rc = 0 ]
