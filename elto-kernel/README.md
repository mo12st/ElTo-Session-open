# ElTo kernel

ElTo's kernel: CachyOS base, ElTo-owned config layers, packaged as `linux-elto`.

- Base: CachyOS `7.3.6-3` source release (`github.com/CachyOS/linux`), with the
  CachyOS project config at commit `25259ced` (`github.com/CachyOS/linux-cachyos`).
  Kept deliberately: their maintained desktop tuning (scheduler defaults, `-O3`,
  zswap-on-zstd, zram-zstd, ADIOS I/O scheduler) is mature infrastructure.
- ElTo-owned layers (fragments merged on top, in order):
  1. [`config-elto.fragment`](config-elto.fragment) — identity: `uname -r` =
     `7.3.6-elto`, default hostname `elto`, virtio net+blk built in for
     no-initrd VM boots.
  2. [`config-elto-trim.fragment`](config-elto-trim.fragment) — stability:
     ~130 subsystems/drivers outside the target (QEMU/KVM VMs and ordinary
     desktop/laptop hardware) switched off: Xen/Hyper-V/VMware guest support,
     SAN/FC/SAS/Infiniband, server 10G+ NICs, 10/100-era NICs, cluster
     filesystems, ham radio/CAN/DVB/PCMCIA/parallel/FPGA/Chromebook platform.
     Result: 5,697 modules + 2,984 built-ins, down from 6,416 + 3,226
     (about 11% fewer modules, every removal listed with its reason in-file).
- Package: [`PKGBUILD`](PKGBUILD) builds `linux-elto` + `linux-elto-headers`
  with a mkinitcpio preset, so the kernel installs and updates through pacman
  like any Arch package. Signing is NOT set up (not approved).

What this is not: a from-scratch kernel. Owning the config layers, the
package, and (next) the CI proof is how a distro owns its kernel; writing a
kernel is reinventing mature infrastructure (project governance rule 7).

## Build

Two ways:

```sh
# 1. As an Arch package (recommended):
cp PKGBUILD linux-elto.preset config-elto.fragment config-elto-trim.fragment /some/build/dir
cd /some/build/dir && makepkg -si

# 2. Plain build (same result, no packaging):
./build-elto-kernel.sh
```

Dependencies: `pacman -S --needed base-devel bc cpio flex bison libelf openssl
perl python tar xz pahole` (`makepkg -s` resolves the makedepends itself).

## Status and verification

See [VERIFICATION.md](VERIFICATION.md) for exact levels. Summary: fragments
merge cleanly, olddefconfig passes, sample objects compile, `make
kernelrelease` = `7.3.6-elto` (sandbox-verified). Full build, package install,
VM boot, and benchmarks run on the build VM per
[BENCHMARKS.md](BENCHMARKS.md) — before/after numbers only, hardware unproven
until tested on hardware.

## Follow-ups (need their own approval)

- CI: build + QEMU boot on every config change (GitHub Actions, free).
- Hardware test matrix: GPU, Wi-Fi, audio, suspend.
- Deeper trim, only with hardware coverage data.
- Module signing / Secure Boot (not approved).
- Keep `linux-elto.preset` `ALL_kver` in sync on version bumps.
