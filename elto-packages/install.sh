#!/bin/bash
# ElTo package installer. Run on an Arch Linux system.
# Installs the curated lists in lists/ with pacman --needed.
#
# Usage:
#   ./install.sh                 base + session + services + fonts (the ElTo session)
#   ./install.sh --with-apps     plus optional user applications (40-apps)
#   ./install.sh --with-windows  plus Windows .exe support (50-windows-compat,
#                                requires the [multilib] repo)
#   ./install.sh --with-build    plus build-time packages (90-build)
#   ./install.sh --all           everything above
#   ./install.sh --dry-run ...   print what would be installed, change nothing
#
# Verification status of these lists: see VERIFICATION.md. Package names are
# checked against the live Arch repos; nothing here has been installed on real
# hardware by this track (the VM test is run by the implementer agent).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LISTS=("$HERE/lists/00-base.packages" "$HERE/lists/10-session.packages"
       "$HERE/lists/20-services.packages" "$HERE/lists/30-fonts.packages")
DRY=0
WINDOWS=0

for arg in "$@"; do
  case "$arg" in
    --with-apps)    LISTS+=("$HERE/lists/40-apps.packages") ;;
    --with-windows) LISTS+=("$HERE/lists/50-windows-compat.packages"); WINDOWS=1 ;;
    --with-build)   LISTS+=("$HERE/lists/90-build.packages") ;;
    --all)          LISTS+=("$HERE/lists/40-apps.packages"
                            "$HERE/lists/50-windows-compat.packages"
                            "$HERE/lists/90-build.packages"); WINDOWS=1 ;;
    --dry-run)      DRY=1 ;;
    -h|--help)      sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Strip comments/blank lines, one package per line.
PKGS=$(sed 's/#.*$//' "${LISTS[@]}" | tr -s ' \t' ' ' | grep -v '^\s*$' | sort -u)
COUNT=$(echo "$PKGS" | wc -l)

echo "ElTo packages: $COUNT packages from ${#LISTS[@]} list(s):"
for f in "${LISTS[@]}"; do echo "  - $(basename "$f")"; done

if [ "$DRY" = 1 ]; then
  echo "(dry run, nothing installed)"; echo "$PKGS"; exit 0
fi

if [ "$WINDOWS" = 1 ] && ! grep -Eq '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
  echo "ERROR: 50-windows-compat needs the [multilib] repo." >&2
  echo "Uncomment [multilib] (and its Include line) in /etc/pacman.conf, then re-run." >&2
  exit 1
fi

if [ "$(id -u)" != 0 ]; then SUDO=sudo; else SUDO=; fi
echo "$PKGS" | xargs $SUDO pacman -Syu --needed --noconfirm
echo "done: $COUNT packages requested (already-installed ones skipped by --needed)."
