#!/bin/bash
# elto-polkit-agent.sh - start the ElTo polkit authentication agent.
#
# The ElTo session script starts only KWin and Quickshell; nothing in it
# processes /etc/xdg/autostart, so the agent is launched explicitly. The
# session adds one line AFTER WAYLAND_DISPLAY is exported:
#
#     /usr/local/libexec/elto-polkit-agent.sh &
#
# Idempotent: if the agent is already running for this user, exits 0.
# The agent registers itself with polkit; when PackageKit (or anything
# else) needs admin authentication, polkit asks this agent to prompt.
set -u

AGENT_BIN=${ELTO_POLKIT_AGENT_BIN:-/usr/lib/polkit-kde-authentication-agent-1}

if pgrep -u "$(id -u)" -f "$AGENT_BIN" >/dev/null 2>&1; then
    exit 0
fi

if [ ! -x "$AGENT_BIN" ]; then
    echo "elto-polkit-agent: $AGENT_BIN not found; run setup-elto-polkit.sh as root" >&2
    exit 1
fi

exec "$AGENT_BIN"
