# Verification — ElTo kernel (CachyOS 7.3.6-3 + ElTo fragment)

Honest status per the project verification levels (implemented / built /
launched / functionally tested / VM / hardware). Sandbox: 1 vCPU, 1 GB RAM,
gcc 11.4.0, Ubuntu 22.04 userland, no pahole.

## Implemented — yes

`config-elto.fragment`, `build-elto-kernel.sh`, this documentation.

## Built — PARTIAL only

Verified in the sandbox, in this order, all passing:

1. Source provenance. Downloaded
   `https://github.com/CachyOS/linux/releases/download/cachyos-7.3.6-3/cachyos-7.3.6-3.tar.gz`
   (270,002,252 bytes),
   sha256 `e82ccb70388414378ccb559fb6aa5bea525127c89ceb01b75d4b3ab960049893`.
   Makefile reports `VERSION=7 PATCHLEVEL=3 SUBLEVEL=6`, `EXTRAVERSION` empty.
2. Config provenance. `linux-cachyos/linux-cachyos/config` at commit
   `25259ced6c7c8c68796d2a47d98cafb96ccdd603` (2026-11-26),
   sha256 `32b3c2004bf8640a1a280f0ceeab7a434765eb4d246cb81911ecff112dde6f50`.
3. Fragment merge: `scripts/kconfig/merge_config.sh -m` applied the fragment
   cleanly; `.config` then contains `CONFIG_LOCALVERSION="-elto"` and
   `CONFIG_DEFAULT_HOSTNAME="elto"`.
4. `make olddefconfig` — completed, "configuration written to .config".
5. `make prepare scripts` — completed; generated headers and host tools,
   including `tools/objtool/objtool` linked against libelf.
6. `make kernelrelease` — prints `7.3.6-elto`.
7. Sample core objects compiled with the final `.config`, all OK:
   `init/main.o`, `kernel/fork.o`, `kernel/sched/core.o` (the CachyOS/BORE
   scheduler path), `mm/memory.o`, `drivers/tty/vt/vt.o`.

## NOT done (explicitly unverified)

- **Full build**: not run. The sandbox has 1 vCPU / 1 GB RAM, and the config
  enables `CONFIG_DEBUG_INFO_BTF=y` which needs `pahole` (absent). The
  vmlinux link alone would not fit in 1 GB RAM. Steps 1-7 prove the source,
  config, fragment, and toolchain are consistent; they do not prove the full
  tree compiles.
- **Launched / booted**: no.
- **Functionally tested**: no.
- **VM-tested**: no (the implementer agent owns the VM).
- **Hardware-tested**: no.

## What proves the rest

On the build VM: run `./build-elto-kernel.sh` (deps in README). It stops on
any hash mismatch or build error. Success = `arch/x86/boot/bzImage` exists and
`make -s kernelrelease` prints `7.3.6-elto`. Then boot that bzImage in the
ElTo VM (implementer) and record `uname -r` from the booted session.
