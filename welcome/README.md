# ElTo Welcome (Phase 2)

First-run welcome and tour for the ElTo session: a standalone Quickshell window,
same pattern as `panel-widgets/customize.qml`. Approved design: tour-only with a
Customize hand-off (no in-Welcome personalization), English first (Arabic + RTL in
Phase 3), shown once per major version via a versioned state marker.

## Files

- `welcome.qml` — the window. Four pages: Welcome, the tour (notch / dock / drawer),
  Make it yours (opens the existing Customize window), Done. Skippable on every page,
  keyboard navigable (Left/Right, Esc to skip). Writes the marker and exits.
- `elto-welcome-autostart.sh` — autostart guard: exits unless the marker for the
  current `welcomeVersion` is missing; also exits in non-ElTo sessions
  (`XDG_SESSION_DESKTOP` check) because `elto-session` exports `XDG_CURRENT_DESKTOP=KDE`.
- `elto-welcome-autostart.desktop` — XDG autostart entry for the guard
  (`OnlyShowIn=KDE` matches the session's current `XDG_CURRENT_DESKTOP`).
- `elto-welcome.desktop` — app-drawer entry so Welcome can be reopened anytime.

## Install wiring (implementer: belongs in session/install.sh)

    install -d /opt/elto-session/welcome
    cp "$R/welcome/welcome.qml" "$R/welcome/elto-welcome-autostart.sh" /opt/elto-session/welcome/
    chmod 755 /opt/elto-session/welcome/elto-welcome-autostart.sh
    install -m644 "$R/welcome/elto-welcome.desktop" /usr/share/applications/elto-welcome.desktop
    install -m644 "$R/welcome/elto-welcome-autostart.desktop" /etc/xdg/autostart/elto-welcome-autostart.desktop

All runtime paths are relative to the QML file (`Quickshell.shellPath("../...")`),
so the layout above (`/opt/elto-session/welcome/` next to `panel-widgets/`,
`themes/`, `wallpapers/`, `lock/`) matches both the repo tree and the installed tree.

## Behavior

- Marker: `${XDG_STATE_HOME:-~/.local/state}/elto/welcome-v1.done` (JSON content:
  version + timestamp). Bump `welcomeVersion` in `welcome.qml` to re-show Welcome
  after a major version ("what's new").
- No daemon, no service, nothing resident: one window, exits when done or skipped.
  If Welcome crashes or is deleted, the session is unaffected.
- Styling reads `themes/soft-paper/theme.json` + the user overlay
  (`~/.config/elto/theme.json`) read-only, merged the same way as
  `panel-widgets/Theme.qml`. The merge is inlined because `Theme.qml` is a QML
  singleton local to `panel-widgets/` and cannot be imported across directories
  without a `qmldir` (which belongs to the implementer's track). `LIcon` is a
  plain component and is reused directly.

## Explicitly out of scope (other components' territory)

User creation, timezone, keyboard, network setup UI, settings editing, app
installation. Welcome links out to Customize and never duplicates controls.
