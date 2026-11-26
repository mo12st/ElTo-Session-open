#!/bin/sh
# ElTo Welcome autostart guard: show Welcome once per major version, only inside the
# ElTo session. Referenced by elto-welcome-autostart.desktop (XDG autostart).
# If XDG_SESSION_DESKTOP is set and is not ElTo (e.g. a Plasma session on the same
# machine, since elto-session exports XDG_CURRENT_DESKTOP=KDE), do nothing.
[ -n "$XDG_SESSION_DESKTOP" ] && [ "$XDG_SESSION_DESKTOP" != "ElTo" ] && exit 0
MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/elto/welcome-v1.done"
[ -f "$MARKER" ] && exit 0
exec quickshell -p /opt/elto-session/welcome/welcome.qml
