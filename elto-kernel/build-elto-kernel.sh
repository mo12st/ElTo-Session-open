#!/usr/bin/env bash
# build-elto-kernel.sh - build the ElTo kernel: CachyOS 7.3.6-3 + ElTo fragment.
#
# What it does:
#   1. Downloads the official CachyOS kernel source tarball (pinned + sha256-checked)
#   2. Downloads the CachyOS kernel config (pinned commit + sha256-checked)
#   3. Merges config-elto.fragment on top (ElTo branding, nothing else)
#   4. make olddefconfig && make -j$(nproc)
#
# Usage: ./build-elto-kernel.sh [workdir]   (default: ./elto-kernel-build)
#
# Dependencies (Arch): pacman -S --needed base-devel bc cpio flex bison libelf \
#   openssl perl python tar xz pahole
# pahole is required: the CachyOS config enables CONFIG_DEBUG_INFO_BTF=y.
set -euo pipefail

KSRC_VER="7.3.6"
KSRC_TAGREL="3"
KSRC_NAME="cachyos-${KSRC_VER}-${KSRC_TAGREL}"
KSRC_TARBALL="${KSRC_NAME}.tar.gz"
KSRC_URL="https://github.com/CachyOS/linux/releases/download/${KSRC_NAME}/${KSRC_TARBALL}"
KSRC_SHA256="e82ccb70388414378ccb559fb6aa5bea525127c89ceb01b75d4b3ab960049893"

CONFIG_COMMIT="25259ced6c7c8c68796d2a47d98cafb96ccdd603"
CONFIG_URL="https://raw.githubusercontent.com/CachyOS/linux-cachyos/${CONFIG_COMMIT}/linux-cachyos/config"
CONFIG_SHA256="32b3c2004bf8640a1a280f0ceeab7a434765eb4d246cb81911ecff112dde6f50"

FRAGMENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config-elto.fragment"
WORKDIR="$(realpath "${1:-elto-kernel-build}")"
JOBS="$(nproc)"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
for t in curl tar xz make gcc flex bison bc pahole; do need "$t"; done

mkdir -p "$WORKDIR"
cd "$WORKDIR"

fetch_and_verify() { # url file sha256
    if [ ! -f "$2" ]; then
        echo ">> downloading $1"
        curl -fL --retry 3 -o "$2" "$1"
    fi
    echo "$3  $2" | sha256sum -c - || { echo "sha256 mismatch on $2; delete it and retry" >&2; exit 1; }
}

fetch_and_verify "$KSRC_URL" "$KSRC_TARBALL" "$KSRC_SHA256"
fetch_and_verify "$CONFIG_URL" "config-cachyos" "$CONFIG_SHA256"

if [ ! -d "$KSRC_NAME" ]; then
    echo ">> extracting $KSRC_TARBALL"
    tar xzf "$KSRC_TARBALL"
fi
cd "$KSRC_NAME"

cp ../config-cachyos .config
./scripts/kconfig/merge_config.sh -m .config "$FRAGMENT"
make olddefconfig

echo ">> building with $JOBS jobs (a full kernel build takes a while)"
make -j"$JOBS"

echo
echo ">> done"
echo "   kernel release: $(make -s kernelrelease)"
echo "   image:          $(pwd)/arch/x86/boot/bzImage"
echo "   modules:        run  sudo make modules_install  on the target, or package with makepkg"
