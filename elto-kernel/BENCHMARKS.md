# Benchmark protocol — ElTo kernel (before/after numbers only)

Rule (user-approved): no performance or stability claim without a measured
before/after. Run on the same VM, same boot, alternating kernels. Free tools
only: fio, iperf3, rt-tests (cyclictest), systemd-analyze, time.

## What "before" and "after" mean

- **before**: kernel built from the pinned CachyOS config + branding fragment
  only (config-elto.fragment) — i.e. the merged pre-trim state.
- **after**: the same plus config-elto-trim.fragment.

Both are built on the build VM; each result below is recorded in this file
under RESULTS before the PR is considered measured.

## Checks (VM-verifiable)

1. **Build cost (stability/maintenance metric).** `time make -j$(nproc)` for
   each config, same machine, ccache off. Also module count
   (`grep -c '=m$' .config`) and vmlinuz + modules install size (`du -sh`).
2. **Boot time.** Boot each kernel 3 times to the display manager / getty,
   record `systemd-analyze` (kernel + userspace) and `systemd-analyze blame`
   top 5. Median of 3.
3. **Disk.** `fio --name=randrw --rw=randrw --bs=4k --size=1G --numjobs=1
   --runtime=30 --time_based --group_reporting` on the virtio disk, 3 runs
   each kernel, median IOPS.
4. **Scheduler latency (weak signal in a VM).** `cyclictest -m -p 80 -n -i
   200 -l 100000` max/avg latency. Honest caveat: QEMU timing is noisy; treat
   a difference under ~20% as inconclusive.
5. **Memory (zram/zswap sanity, not a benchmark).** Confirm zswap is on
   (`cat /sys/module/zswap/parameters/enabled`) and zram loads
   (`modprobe zram`), since memory tuning is userspace policy and the kernel
   side is what this PR controls.
6. **Regression smoke.** On the trimmed kernel: virtio net + blk work,
   `lsmod` shows no failed loads in `dmesg`, audio (snd-hda via QEMU) if
   configured, USB tablet input works.

## What needs real hardware (do NOT claim from VM)

Graphics/GPU, Wi-Fi, suspend/resume, battery/power draw, real NVMe latency,
thermal behavior. Any number above is a VM number and gets labeled as such.

## RESULTS

(to be filled by the implementer's build VM run; empty = not measured yet)
