# Verification — ElTo kernel (CachyOS 7.3.6-3 + ElTo fragments + PKGBUILD)

Honest status per the project verification levels (implemented / built /
launched / functionally tested / VM / hardware). Sandbox: 1 vCPU, 1 GB RAM,
gcc 11.4.0, no KVM. This file covers the "own kernel" PR (trim + PKGBUILD);
the branding-only PR's earlier evidence is at the bottom for reference.

## Implemented — yes

`config-elto.fragment` (identity + virtio), `config-elto-trim.fragment`
(~130 documented removals), `PKGBUILD` + `linux-elto.preset` (linux-elto and
linux-elto-headers packages), updated `build-elto-kernel.sh`, `BENCHMARKS.md`.

## Verified in the sandbox (all real, reproducible)

1. Source provenance: `cachyos-7.3.6-3.tar.gz`, 270,002,252 bytes, sha256
   `e82ccb70388414378ccb559fb6aa5bea525127c89ceb01b75d4b3ab960049893`.
2. Config provenance: CachyOS config at commit `25259ced`, sha256
   `32b3c2004bf8640a1a280f0ceeab7a434765eb4d246cb81911ecff112dde6f50`.
3. Both fragments merge cleanly with `scripts/kconfig/merge_config.sh`;
   `make olddefconfig` passes.
4. Trim effect (measured, this exact tree): 5,697 `=m` + 2,984 `=y`, down
   from 6,416 `=m` + 3,226 `=y`. Every symbol named in the trim fragment is
   off in the final `.config` (checked programmatically, zero stragglers).
   Kept and verified on: virtio blk+net built in, r8169/e1000e/igb/igc/
   atlantic/alx/tg3/bnx2 + USB ethernet, KVM (intel+amd), IIO, WWAN,
   Thunderbolt, NFS client, CIFS, NVMe, ext4/btrfs, zram/zswap (zstd).
5. `make prepare` + `make scripts` pass; sample objects compile with the
   final trimmed config: `init/main.o`, `kernel/sched/core.o`,
   `drivers/block/virtio_blk.o`, `drivers/net/ethernet/realtek/r8169_main.o`.
6. `make kernelrelease` prints `7.3.6-elto`.
7. PKGBUILD: `bash -n` clean; source URLs and hashes match the verified
   downloads above. NOT run through makepkg (no Arch/makepkg in sandbox).

## NOT verified here (explicitly)

- Full build to bzImage (sandbox RAM/CPU; needs the build VM).
- makepkg run, pacman install, mkinitcpio image generation.
- Boot, benchmarks, lsmod regression smoke — protocol ready in BENCHMARKS.md,
  RESULTS section empty until the implementer's VM run fills it.
- Hardware: everything hardware-specific (GPU, Wi-Fi, suspend) untested.

## Earlier evidence (branding-only PR, already merged)

VM L2 proof by the implementer (run 46048223055): the built 7.3.6-elto
kernel booted QEMU to login with `root=/dev/vda3`, no initrd; `uname -r` over
ssh returned `7.3.6-elto`. Unproven then and still: hardware, modules, a
graphical session.
