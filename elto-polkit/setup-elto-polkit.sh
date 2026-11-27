#!/bin/bash
# setup-elto-polkit.sh - ElTo polkit option A setup (approved 2026-11-27):
# a polkit authentication agent for the session + wheel-group membership
# for the session user. NO permissive polkit rules are installed or touched;
# PackageKit's own policy (auth_admin_keep for install/remove) stays as
# shipped, so non-wheel users keep failing closed.
#
# Run as root:   setup-elto-polkit.sh --user NAME
# Idempotent: re-running installs nothing twice and adds no duplicate group.
#
# Environment overrides (test hooks, not for normal use):
#   ELTO_POLKIT_AGENT_PKG       agent package (default polkit-kde-agent;
#                               alternative lxqt-policykit, see README)
#   ELTO_POLKIT_AGENT_BIN       agent binary path
#   ELTO_POLKIT_AUTOSTART_FILE  the package's XDG autostart entry
#   ELTO_POLKIT_RULES_FILE      polkit default admin rule file
set -euo pipefail

AGENT_PKG=${ELTO_POLKIT_AGENT_PKG:-polkit-kde-agent}
AGENT_BIN=${ELTO_POLKIT_AGENT_BIN:-/usr/lib/polkit-kde-authentication-agent-1}
AUTOSTART_FILE=${ELTO_POLKIT_AUTOSTART_FILE:-/etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop}
RULES_FILE=${ELTO_POLKIT_RULES_FILE:-/usr/share/polkit-1/rules.d/50-default.rules}
LAUNCHER_SRC="$(cd "$(dirname "$0")" && pwd)/elto-polkit-agent.sh"
LAUNCHER_DST=${ELTO_POLKIT_LAUNCHER_DST:-/usr/local/libexec/elto-polkit-agent.sh}

err() { echo "setup-elto-polkit: $*" >&2; }

USER_NAME=""
while [ $# -gt 0 ]; do
    case "$1" in
        --user) USER_NAME=${2:-}; shift 2 ;;
        *) err "unknown argument: $1"; echo "usage: $0 --user NAME" >&2; exit 2 ;;
    esac
done
if [ -z "$USER_NAME" ]; then
    echo "usage: $0 --user NAME" >&2
    exit 2
fi
if [ "$(id -u)" != "0" ]; then
    err "must run as root"
    exit 2
fi
if ! id "$USER_NAME" >/dev/null 2>&1; then
    err "user '$USER_NAME' does not exist"
    exit 1
fi

# 1. agent package (ships the binary and, for sessions that process XDG
#    autostart, /etc/xdg/autostart entry; the ElTo session launches the
#    agent explicitly via elto-polkit-agent.sh)
pacman -S --needed --noconfirm "$AGENT_PKG"

if [ ! -x "$AGENT_BIN" ]; then
    err "agent binary $AGENT_BIN not found after installing $AGENT_PKG"
    exit 1
fi
if [ ! -f "$AUTOSTART_FILE" ]; then
    err "warning: autostart entry $AUTOSTART_FILE missing (unexpected for $AGENT_PKG; the ElTo session does not rely on it)"
fi

# 2. session launcher (started from elto-session; see README)
install -Dm755 "$LAUNCHER_SRC" "$LAUNCHER_DST"

# 3. verify the polkit default admin rule accepts wheel; if it does not,
#    admin authentication has no usable identity here and we fail loudly
#    instead of guessing (a different admin group is a user decision).
if ! grep -q 'addAdminRule' "$RULES_FILE" 2>/dev/null || ! grep -q 'wheel' "$RULES_FILE" 2>/dev/null; then
    err "$RULES_FILE does not name wheel as a polkit admin group"
    err "refusing to continue: which group polkit treats as admin is a policy decision"
    exit 1
fi

# 3b. polkit-agent-helper-1 must be setuid root or every password check
#     fails at once ("needs to be setuid root"). The stock Arch image here
#     ships it 0755 (VM-verified), so set the mode explicitly. Idempotent.
HELPER=${ELTO_POLKIT_HELPER:-/usr/lib/polkit-1/polkit-agent-helper-1}
if [ -e "$HELPER" ]; then
    chown root:root "$HELPER"
    chmod 4755 "$HELPER"
    echo "setup-elto-polkit: $HELPER mode $(stat -c %a "$HELPER")"
else
    err "warning: $HELPER not found; password checks cannot work without it"
fi

# 4. wheel membership (idempotent)
if id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx wheel; then
    echo "setup-elto-polkit: $USER_NAME is already in wheel"
else
    usermod -aG wheel "$USER_NAME"
    id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx wheel || {
        err "usermod ran but $USER_NAME is still not in wheel"
        exit 1
    }
    echo "setup-elto-polkit: added $USER_NAME to wheel"
fi

echo "setup-elto-polkit: done."
echo "  - $USER_NAME must log in again for wheel membership to take effect"
echo "  - the session must start the agent: add '$LAUNCHER_DST &' to elto-session after WAYLAND_DISPLAY is set (see README)"
echo "  - no polkit rules were added or changed; install/remove still require admin auth (auth_admin_keep)"
