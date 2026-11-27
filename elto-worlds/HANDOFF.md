# Shell handoff - what the worlds format needs from the shell QML

For the implementer. Everything below is a SPEC, not implemented or tested.
The worlds tool (elto-world) already writes all of these keys into the shell
overlay (`~/.config/elto/theme.json`) on apply. The shell can ship each item
independently; unknown keys are ignored by the current shell, so old shells and
new overlays mix safely both ways.

Fallback rule for every new key: if absent or unrecognized, behave exactly as
the shell does today. When a value IS present but not recognized, distinguish
the two cases and say which happened in a visible warning (shell log, and a
non-blocking note where the setting is shown): an UNKNOWN value (nothing the
shell was ever taught) and an UNSUPPORTED one (a declared concept the shell
does not implement yet). Both fall back to current behavior; neither may
break the shell or silence the warning.

Phasing below follows the approved review: ship and prove the simple case
first, land the edge behavior as its own tested step.

## 1. Notch modes (overlay: options.notchMode, options.notchAutoHideMs, options.notchRespectFullscreen)

Current behavior: clock notch always visible.

Phase A (first milestone, test and ship before Phase B starts):

- `notchMode: "show"` - current behavior. Default/fallback.
- `notchMode: "hidden"` - notch never rendered.

Phase B (separate step, tested on its own, especially the edge cases):

- `notchMode: "auto-hide"` - notch renders when the pointer enters the notch
  area or the panel/drawer opens, and hides after `notchAutoHideMs`
  milliseconds (int, default 400 if absent) without interaction. Edge cases
  to test explicitly: rapid re-entry during the hide delay, drawer opening
  mid-hide, and interaction with the fullscreen rule below.
- `notchRespectFullscreen: true` - when any window is fullscreen on the
  screen, force the notch hidden regardless of notchMode. When absent or
  false, fullscreen has no effect (current behavior).

## 2. Dock variants (overlay: options.dock)

Current behavior: `Theme.dockStyle === "island"` (DockWindow.qml).

Architecture: build one shared dock model layer first - window tracking,
launchers, running state, ordering - that both variants render from. The
variants are two presentations of the same model, not two docks. This keeps
the architecture open for later variants without touching window logic.

- `dock: "island"` - current behavior. Default/fallback.
- `dock: "bar"` - full-width bar pinned to the screen edge: no floating
  margins, no island rounding, spans the whole width, same shared model,
  same behavior otherwise.
- ridge-shelf and hidden-thread are declared concepts, not implemented:
  warn as UNSUPPORTED and fall back to island. Any other value: warn as
  UNKNOWN, fall back to island.

Test matrix for the shared layer + both variants: multiple windows of one
app, two monitors, a fullscreen window, and a shell restart (state
restored).

Note: options.dock and Theme.dockStyle need to converge on one source of
truth; simplest is Theme.qml mapping overlay options.dock -> dockStyle with
the fallback above.

## 3. Sounds (overlay: sounds.enabled; files: ~/.local/share/sounds/<world-id>/)

The tool installs a freedesktop sound theme per world:
`~/.local/share/sounds/<world-id>/index.theme` plus `stereo/<event>.wav`.
Event ids in use: session-start, notification, drawer-open, lock, unlock.

- Gate everything on overlay `sounds.enabled` (bool, default false = current
  silent behavior).
- Proof order on a real Arch+KDE machine before wiring ElTo events: 1) a
  freedesktop theme installed to ~/.local/share/sounds/ is picked up and
  plays at all (e.g. via the system sound path), 2) the shell plays one
  installed wav in-process, 3) only then wire the ElTo-internal events.
- Play in-process with Qt Multimedia `SoundEffect` (low latency, no spawn).
  Do NOT launch a process per event (no paplay/aplay) - too fragile.
- Resolve the active theme from the overlay `_world.id` stamp; if the theme
  dir or a given event file is missing, skip silently. Never block UI on
  audio; preload SoundEffect sources on shell start.
- Lock/unlock events will matter once the lock screen lands (Phase 2); wiring
  can wait until then.

## 4. Wallpaper sets (theme package: options.wallpapers; overlay: options.wallpaper)

Each world package lists its wallpaper set in `options.wallpapers` as
`{path, label}` objects (paths relative to the package under
`assets/wallpapers/`; later bundles ship several). The active pick lives in
overlay `options.wallpaper` and the file is copied into
`~/.config/elto/wallpapers/` (Wallpaper.qml already prefers that directory).
A plain-string entry is the legacy form: treat it as `{path: entry}`.

Spec for the Themes page: a wallpaper row under the active world showing its
set (label + thumbnail); picking one copies the file into
`~/.config/elto/wallpapers/` and writes `options.wallpaper` in the overlay.
Until the row exists, the tool's default pick applies and nothing breaks.

## Overlay reference (new keys, all optional)

```json
{
  "_world": {"id": "retro95", "schema_version": 3, "applied_at": "..."},
  "options": {
    "wallpaper": "assets/wallpaper.jpg",
    "dock": "island | bar",
    "notch": "clock",
    "notchMode": "show | hidden | auto-hide",
    "notchAutoHideMs": 400,
    "notchRespectFullscreen": true
  },
  "sounds": {"enabled": true}
}
```

`elto-world reset` re-applies the world's defaults over these keys, so the
shell must treat them as user-editable at any time (it already live-watches
the overlay).
