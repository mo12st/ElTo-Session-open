#!/usr/bin/env bash
# Installs the ElTo Guardian Phase 1 components system-wide.
# Run as root, from the repo root:  sudo ./elto-guardian/install.sh
#
# What it installs (and nothing else):
#   /usr/local/bin/elto-doctor                              the diagnostic command
#   /etc/systemd/journald.conf.d/elto-persistent.conf       persistent system logs
#   /etc/systemd/coredump.conf.d/elto.conf                  capped crash collection
#
# It does NOT touch session/, the shell, SDDM, packages, or any other track's
# files. Reversible: sudo ./elto-guardian/install.sh --uninstall
set -e

R=$(cd "$(dirname "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "elto-guardian install: run as root (sudo $0)" >&2
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    rm -f /usr/local/bin/elto-doctor
    rm -f /etc/systemd/journald.conf.d/elto-persistent.conf
    rm -f /etc/systemd/coredump.conf.d/elto.conf
    systemctl restart systemd-journald 2>/dev/null || true
    echo "elto-guardian: Phase 1 components removed."
    exit 0
fi

install -m755 "$R/elto-doctor" /usr/local/bin/elto-doctor

install -d /etc/systemd/journald.conf.d /etc/systemd/coredump.conf.d
install -m644 "$R/config/journald-persistent.conf" /etc/systemd/journald.conf.d/elto-persistent.conf
install -m644 "$R/config/coredump-elto.conf"       /etc/systemd/coredump.conf.d/elto.conf

# Apply log retention now. Journald restart is safe and standard; coredump
# drop-ins are picked up on the next crash, no restart needed.
systemctl restart systemd-journald 2>/dev/null || true

echo "elto-guardian: Phase 1 installed."
echo "  - elto-doctor is on PATH (try: elto-doctor)"
echo "  - system logs now persist across reboots"
echo "  - crash collection enabled (capped, see /etc/systemd/coredump.conf.d/elto.conf)"
echo "Note: the session hardening in SESSION-HARDENING.md is applied by the"
echo "      session track to session/elto-session; this installer does not touch it."
