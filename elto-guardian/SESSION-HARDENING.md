# Session hardening (for the session/implementer track to apply)

Guardian Phase 1 includes two hardening changes to `session/elto-session`.
That file belongs to the session/implementer track, so **this document is a
request, not an edit**. The Guardian track does not touch `session/`.

## Why

Today `session/elto-session` starts Quickshell exactly once:

```bash
quickshell -p "$ROOT/panel-widgets/elto-shell.qml" &
```

If Quickshell crashes (a bad QML edit, a driver hiccup, a broken world file
once Worlds land), the user is left on a bare KWin with no panel, no dock and
no visible error. The governance directive requires graceful failure: an
optional component failing must not cost the user the desktop.

## Requested change 1: limited respawn

Replace the single Quickshell start with a limited respawn loop (no new
service, just shell logic inside the existing session script):

```bash
# Guardian hardening: respawn the shell a few times on transient crashes,
# then stop trying and leave the log pointing at the way out.
ELTO_SHELL_MAX_RESPAWNS=3
respawns=0
while [ "$respawns" -le "$ELTO_SHELL_MAX_RESPAWNS" ]; do
    quickshell -p "$ROOT/panel-widgets/elto-shell.qml"
    code=$?
    respawns=$((respawns + 1))
    echo "elto-session: quickshell exited (code $code), respawn $respawns/$ELTO_SHELL_MAX_RESPAWNS"
    sleep 2
done
echo "elto-session: SHELL FAILED after $ELTO_SHELL_MAX_RESPAWNS respawns."
echo "elto-session: log out and choose 'ElTo Recovery' at the login screen, then run elto-doctor."
```

Notes for the implementer:
- The loop replaces `quickshell ... &` — Quickshell moves to the foreground of
  the script; the existing `wait $KWIN` logic needs to keep working (KWin is
  still the session leader whose exit ends the session). Exact integration is
  the implementer's call; the requirement is only "limited respawn, then a
  visible failure message in the log".
- 3 respawns with 2s pause is a starting value; the implementer may tune it.
- A clean logout also exits Quickshell; the loop must not fight session
  shutdown. If KWin is gone, exit instead of respawning.

## Requested change 2: none to lock screen or SDDM

The Recovery session entry (`elto-recovery.desktop`, Guardian Phase 2) will
appear in the SDDM session menu on its own; no SDDM config change is needed.
No change is requested to `session/install.sh` in Phase 1 — Guardian ships its
own `elto-guardian/install.sh`.
