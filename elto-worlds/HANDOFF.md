# Shell handoff - what the worlds format needs from the shell QML

For the implementer. Everything below is a SPEC, not implemented or tested.
The worlds tool (elto-world) already writes all of these keys into the shell
overlay (`~/.config/elto/theme.json`) on apply. The shell can ship each item
independently; unknown keys are ignored by the current shell, so old shells and
new overlays mix safely both ways.

Fallback rule for every new key: if absent or unrecognized, behave exactly as
the shell does today.

## 1. Notch modes (overlay: options.notchMode, options.notchAutoHideMs, options.notchRespectFullscreen)

Current behavior: clock notch always visible.

- `notchMode: "show"` - current behavior. Default/fallback.
- `notchMode: "hidden"` - notch never rendered.
- `notchMode: "auto-hide"` - notch renders when the pointer enters the notch
  area or the panel/drawer opens, and hides after `notchAutoHideMs`
  milliseconds (int, default 400 if absent) without interaction.
- `notchRespectFullscreen: true` - when any window is fullscreen on the
  screen, force the notch hidden regardless of notchMode. When absent or
  false, fullscreen has no effect (current behavior).

## 2. Dock variants (overlay: options.dock)

Current behavior: `Theme.dockStyle === "island"` (DockWindow.qml).

- `dock: "island"` - current behavior. Default/fallback.
- `dock: "bar"` - full-width bar pinned to the screen edge: no floating
  margins, no island rounding, spans the whole width, same contents and
  behavior otherwise.
- Any other value (including the old concept values ridge-shelf,
  hidden-thread) - fall back to island.

Note: options.dock and Theme.dockStyle need to converge on one source of
truth; simplest is Theme.qml mapping overlay options.dock -> dockStyle with
the fallback above.

## 3. Sounds (overlay: sounds.enabled; files: ~/.local/share/sounds/<world-id>/)

The tool installs a freedesktop sound theme per world:
`~/.local/share/sounds/<world-id>/index.theme` plus `stereo/<event>.wav`.
Event ids in use: session-start, notification, drawer-open, lock, unlock.

- Gate everything on overlay `sounds.enabled` (bool, default false = current
  silent behavior).
- Play in-process with Qt Multimedia `SoundEffect` (low latency, no spawn).
  Do NOT launch a process per event (no paplay/aplay) - too fragile.
- Resolve the active theme from the overlay `_world.id` stamp; if the theme
  dir or a given event file is missing, skip silently. Never block UI on
  audio; preload SoundEffect sources on shell start.
- Lock/unlock events will matter once the lock screen lands (Phase 2); wiring
  can wait until then.

## 4. Wallpaper sets (theme package: options.wallpapers; overlay: options.wallpaper)

Each world package lists its wallpaper set in `options.wallpapers` (paths
relative to the package, e.g. `assets/wallpaper.jpg`; later bundles ship
several). The active pick lives in overlay `options.wallpaper` and the file
is copied into `~/.config/elto/wallpapers/` (Wallpaper.qml already prefers
that directory).

Spec for the Themes page: a wallpaper row under the active world showing its
set; picking one copies the file into `~/.config/elto/wallpapers/` and writes
`options.wallpaper` in the overlay. Until the row exists, the tool's default
pick applies and nothing breaks.

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
