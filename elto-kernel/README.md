# ElTo kernel

ElTo's kernel is the **CachyOS kernel with ElTo branding, and nothing else**.

- Base: CachyOS `7.3.6-3` source release (`github.com/CachyOS/linux`), with the
  CachyOS project config at commit `25259ced` (`github.com/CachyOS/linux-cachyos`).
  That gives us their maintained desktop tuning: the CachyOS scheduler defaults,
  `-O3` flags, 1000 Hz tick, BBR v3, zstd modules, and their patchset, all from
  upstream instead of our own tree.
- ElTo changes: exactly two config lines, in [`config-elto.fragment`](config-elto.fragment):

  | Setting | CachyOS | ElTo |
  |---|---|---|
  | `CONFIG_LOCALVERSION` | `""` | `"-elto"` (so `uname -r` = `7.3.6-elto`) |
  | `CONFIG_DEFAULT_HOSTNAME` | `"cachyos"` | `"elto"` |

No patch changes, no scheduler changes, no removed drivers. Keeping the delta
this small is deliberate: every extra change is ours to maintain and rebase on
every CachyOS release, and CachyOS already ships the tuning ElTo wants.

## Build

On an Arch machine/VM:

```sh
sudo pacman -S --needed base-devel bc cpio flex bison libelf openssl perl python tar xz pahole
./build-elto-kernel.sh            # or pass a workdir
```

The script downloads the pinned tarball and config (both sha256-checked),
merges the fragment, and runs `make -j$(nproc)`. Result:
`arch/x86/boot/bzImage`, release name `7.3.6-elto`.

A full build needs a real machine: roughly 30-90 minutes on 8 cores and 8+ GB
RAM. It will not finish in a tiny sandbox.

## Status

Partially built in a limited sandbox (config, headers, host tools, and sample
core objects compile; `make kernelrelease` prints `7.3.6-elto`). **Not yet
fully built, not booted, not VM-tested, not hardware-tested.** Exact evidence
and what remains: [VERIFICATION.md](VERIFICATION.md).

## Follow-ups (not in this PR, need their own approval)

- Package as an Arch package (`linux-elto` PKGBUILD derived from CachyOS's) so
  pacman manages it.
- Module signing / Secure Boot keys.
- Boot smoke test in the ElTo VM, then hardware.
