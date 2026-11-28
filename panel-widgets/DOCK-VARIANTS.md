# Dock variants (shell side)

Status: **CONCEPT.** L1 only: the QML passes `qmllint` and both variants plus the fallback case load in
Quickshell under a nested KWin in a container. Nothing has run on a real screen, so appearance and
behaviour are unproven until the implementer runs the VM plan at the bottom.

Contract: `elto-worlds/HANDOFF.md` section 2 (worlds foundation, PR #36). The overlay key is
`options.dock`, the only real values are `island` and `bar`, and any other value falls back to
`island`. The shell side below implements exactly that.

## What exists

| id | file | what it is |
| --- | --- | --- |
| `island` | `DockWindow.qml` (+ `DockWindowBlur.qml`) | unchanged floating island: rounded, centred, floating margin above the screen edge |
| `bar` | `DockBar.qml` (+ `DockBarBlur.qml`) | full-width strip pinned to the bottom edge: no floating margin, no island rounding, same contents and behavior otherwise |
| `rail-dock` | `DockRail.qml` | narrow vertical rail on the left (or right) edge: launcher at the top, pinned tiles, open windows, workspace indicator and clock at the bottom |

Both variants read the same `dock` section of the theme, so a world needs no second dock block and
`themes/soft-paper/theme.json` is untouched. Only these keys are used: `height`, `radius` (island
only), `bottomMargin` (island only), `tile`, `icon`, `gap`, `pad`, `pillWidth`, `pillHeight`,
`color`, `glass`, `opacity`, `blur`, `pinned`, `glyphs`.

`bar` specifics:

- The strip is exactly `dock.height` tall and the window is `dock.height + 44` tall; the extra 44 px
  is transparent room for the right-click Pin/Unpin menu, and the window mask keeps clicks there
  falling through.
- A 1 px hairline (`Theme.divider`, or white at 50 % in glass mode) plus a 10 px inner shade replace
  the island's stacked outer drop shadow, because a flush strip has nowhere to cast one.
- Window pills sit in a clipped area between the pinned cluster and the right padding, so a long
  window list never spills past the screen edge.
- No snail mark: HANDOFF.md says the bar keeps the same contents as the island, so nothing was added
  to it. If the user wants the snail at the end of the bar that is an artistic addition and needs his
  approval first.

## Shared layer, one view per variant

`Dock.qml` is the model and the only place with behaviour: the pinned list from the theme overlay, the
window list, `openApps`/`activeApp`, `pin`/`unpin`/`entryFor`, and the resolved `style`. Each variant
file is a `PanelWindow` that draws that model and nothing else: it takes `required property var dock`,
declares its own `style`, and refuses to show unless `dock.style` matches. Adding a variant never
touches the model, the window tracking or the theme schema, and both variants share one `dock` theme
section instead of forking it.

## How a variant is chosen

```
overlay ~/.config/elto/theme.json   options.dock
        -> Theme.qml                Theme.dockStyle  (optionsT.dock, already live-watched)
        -> DockStyle.qml            DockStyle.resolve(id)
        -> Dock.qml                 picks the window file and loads it once per screen
```

`DockStyle.resolve()` is the fallback rule from the contract in one place: absent, empty, unknown or
reserved ids all return `island`, so a world or a hand-edited overlay can never leave the session
without a dock. A value that is present but unknown or not implemented warns once in the shell log
(`ELTODOCK unknown or unsupported dock style '<id>', falling back to island`) and then behaves as
island. A user-facing warning belongs in the Theme or Control page that owns the picker, not here.
Each variant window also refuses to show itself unless `dock.style` matches its own id, which is a
second lock against a stale instance.

Switching is live: the overlay is watched by `Theme.qml`, `Dock.qml` reloads the window on
`style` change, and a variant swap costs one Loader reload, not a shell restart.

## Registry (`panel-widgets/DockStyle.qml`)

| id | label | real | notes |
| --- | --- | --- | --- |
| `island` | Island | yes | current default and fallback |
| `bar` | Bar | yes | new in this PR |
| `rail-dock` | Rail dock | yes | vertical rail, left or right edge (`edge: "left"` / `"right"`); a bottom or top value draws it on the left |
| `console` | Console | no | reserved id, concept only, resolves to island |
| `hidden-thread` | Hidden thread | no | concept chip already shown in Customize, resolves to island |
| `ridge-shelf` | Ridge shelf | no | concept chip already shown in Customize, resolves to island |

The concept rows exist so the registry is the one list a picker can read (`DockStyle.labels()`
returns `[{ id, label, real }]`). They draw nothing: a concept id resolves to `island` until a
window file is added and its row is flipped to `real: true`. `rail-dock` and `ridge-shelf` may be the
same idea under two names from the concept art; that naming call belongs to the user, not here.

## Adding the next variant

1. Add `panel-widgets/Dock<Name>.qml`: a `PanelWindow` with `required property var dock`, a
   `readonly property string style: "<id>"`, `visible: dock.style === style`, and the same
   `mask`/menu pattern as the other two. Draw only; all logic stays in `Dock.qml`.
2. Optional `Dock<Name>Blur.qml` that inherits it and adds `BackgroundEffect.blurRegion`.
3. Flip the registry row to `real: true` and fill `window`/`blur`.
4. Read look values from the `dock` theme section; only add a new theme key when no existing key can
   carry the meaning, and then it is a `world.schema.json` change owned by the worlds track.
5. Add the id to the VM plan below.

## Not changed here (open decisions)

- **Screen space.** Both variants use `exclusionMode: ExclusionMode.Ignore`, like the island today, so
  maximized windows draw under the bar. Reserving the strip needs the menu in its own window (or a
  bigger exclusion zone than the strip), which changes window layout for the whole session, so it
  waits for the user's and the implementer's call.
- **Pickers.** `panel-widgets/customize.qml` and `elto-control/AppearancePage.qml` still list
  `island` / `ridge-shelf` / `hidden-thread` as literal arrays and belong to the Theme and Control
  tracks. Until one of them reads `DockStyle.labels()`, the bar is chosen by the world
  (`options.dock: "bar"`) or by editing the overlay, not by a chip in the UI.
- **Worlds.** All nine worlds in `elto-worlds/worlds/` currently declare `options.dock: "island"`;
  their concept-art bar arrangement lives in `layout.bar`. Flipping one world to `"bar"` is a
  one-word change in that world's `world.json` and belongs to the worlds track.

## The real taskbar pieces (workspace indicator, rail, second surface)

The five concept images the user pointed at show one taskbar doing four things: a launcher, one button
per open window, a clock with the status readouts, and a workspace indicator (`Desktop 1`,
`01 · Personal`). The first three the dock already had. This is how the fourth, and the two shapes the
concepts also use, are built. Every piece is a token, so a world that omits the tokens draws exactly
what it drew before.

**Workspace indicator** (`DockDesktops.qml`, `DockPager.qml`, `dock-desktops.py`). KWin publishes the
virtual desktops on the session bus at `org.kde.KWin /VirtualDesktopManager`
(`org.kde.KWin.VirtualDesktopManager`): `count`, `current` (the id of the desktop in use) and
`desktops` (position, id, name per desktop). Quickshell has no D-Bus property binding, so
`dock-desktops.py` reads them with `dbus-send` (part of the `dbus` package, nothing new to install) and
prints one record per line; `DockDesktops.qml` polls it every two seconds and after every switch.
`DockPager.qml` only draws. A click sets `current` through the same helper. KWin not answering (no
session bus, a different compositor) leaves the pager empty instead of wrong.

Why polling and not a signal: a `currentChanged` subscription needs a long-lived process of its own,
which is a second helper to install and keep alive. Two `dbus-send` calls every two seconds cost less
than that, and the only visible difference is that the indicator can lag a switch by up to two seconds.

**Rail** (`DockRail.qml`, variant id `rail-dock`). The aero Habitat concept draws a vertical rail: mark
at the top, icon tiles, clock and language at the bottom. The rail draws the same model as the island in
a column, with the workspace indicator above the clock. It reads `edge` for left or right; any other
value draws it on the left. It draws the launcher as the world's logo when the world has one, otherwise
as a small mark, and it does not draw the volume/network/battery readouts: they are text and read badly
in a 56 px column, so the rail keeps the clock and the workspace indicator only.

**Second surface** (`DockStrip.qml`, `secondSurface: "top"`). Two concepts put a Start/Programs strip
along the top above the desktop, with the task buttons on it and the clock at its right end. With the
token set, the dock loads that strip on every screen in addition to itself. It carries the launcher, one
button per open window, the readouts, the workspace indicator and the clock, and nothing else: no
application menu, because the menu lane owns that. Off by default; every world today draws no strip.

Open question for the user on the strip: the shell's Notch also lives at the top. With
`secondSurface: "top"` the two share the top edge, and which of them owns it (or how they stack) is a
decision, not something to settle in code. The VM run should capture what actually happens with both
present.

## Checked in CI (a container, not the VM)

`.github/workflows/dock-variants-smoke.yml` runs `panel-widgets/dock-smoke.sh` in the same disposable
Arch container as the panel smoke. It starts one nested KWin, then loads `dock-smoke.qml` (the dock and
nothing else) three times with a different overlay:

| case | overlay | expected log |
| --- | --- | --- |
| absent key | `{}` | `ELTODOCK variant island` |
| bar | `options.dock: "bar"` | `ELTODOCK variant bar` |
| fallback | `options.dock: "nonsense"` | `ELTODOCK variant island` plus the fallback warning |
| rail | `options.dock: "rail-dock"`, `dock.edge: "left"` | `ELTODOCK variant rail-dock` |
| top strip | `options.dock: "bar"`, `dock.secondSurface: "top"` | `ELTODOCK variant bar` plus `ELTODOCK strip` |
| pager | `dock.workspaceStyle: "text"` | `ELTODOCKDESK <n> desktops` (the D-Bus read ran) |

It also fails on a real QML load failure (`is not a type`, `Cannot load`, `module ... not found`,
`ReferenceError`, `Cannot read property`) or if Quickshell dies. The real window-list helper is a C
binary that is not in the container, so the script points `ELTO_WINDOWLIST` at a silent stand-in.

Result on commit `f7047a0`: **DOCK-VARIANTS-OK** - all three cases resolved to the expected variant
and no load failure appeared.
https://github.com/mo12st/ElTo-Session-open/actions/runs/46023932079/job/140590336124

What that does **not** prove: how either dock looks, that the bar's geometry and clipping are right on
a real screen, window interactions, glass/blur, or anything about the live session. That is the VM plan
below.

## VM test plan (for the implementer)

Environment: the usual ElTo VM with the session running. The bar needs a real window list, so
`/tmp/elto-windowlist` (or `ELTO_WINDOWLIST`) must be running as usual.

1. **Island unchanged (regression).** Overlay without `options.dock`, or `"island"`. Expect exactly
   today's floating island: rounded, centred, margin under it, pins, pills, Pin/Unpin menu.
   Screenshot `dock-island.png`.
2. **Bar.** Set `"options": {"dock": "bar"}` in `~/.config/elto/theme.json` (or apply a world whose
   `options.dock` is `bar`). Expect, without restarting the shell: the island disappears, a
   full-width strip appears flush on the bottom edge with square corners, one hairline on top, the
   same pinned icons at the left, the divider, and one pill per open window. Screenshot
   `dock-bar.png` at 1280x720 and at the VM's widest mode.
3. **Live switch back.** Set `"island"` again. Expect the bar to disappear and the island to come
   back in the same session. Screenshot `dock-back-island.png`.
4. **Fallback.** Set `"ridge-shelf"` (or `"nonsense"`). Expect island, one warning line
   `ELTODOCK unknown or unsupported dock style ...` in the shell log, and no load error. This is the
   contract's fallback rule.
5. **Bar contents, multiple windows.** Launch two apps (e.g. Kate, Dolphin): pills appear for both,
   clicking a pill raises that window, right-clicking a pill opens Pin/Unpin above the strip and the
   menu is not clipped by the screen edge, left-clicking a pinned icon launches it. Close one: its
   pill goes away and the divider disappears with the last pill.
6. **Overflow.** Open enough windows to pass the screen width. Expect pills to be clipped at the
   right padding, nothing drawn past the strip, no shell error.
7. **Glass.** Toggle `dock.glass` true in the bar: hairline becomes white, the 1 px border appears,
   text stays readable. Screenshot `dock-bar-glass.png`.
8. **Blur.** Set `dock.blur: true` in the bar. If `BackgroundEffect` is unavailable, the log shows
   `ELTODOCKBLUR unsupported, plain dock` and the plain bar still appears (this also fixes the old
   island behaviour, which stayed blank after a blur failure).
9. **Second monitor.** With two outputs attached, expect one bar on each screen, both flush to that
   screen's bottom edge, both tracking the same window list, and the Pin/Unpin menu opening on the
   screen where the click happened. Screenshot `dock-bar-dual.png`.
10. **Fullscreen.** Play a fullscreen window (video or a game window) in both variants. Expect the
    dock to keep its layer and not steal focus or input outside its own mask; the bar may sit over the
    fullscreen surface, which is the known `ExclusionMode.Ignore` consequence recorded above. Report
    what actually happens rather than what looks nicer.
11. **Restart.** With `options.dock: "bar"`, restart the session shell. Expect the bar to come back as
    a bar on the first frame, with no island flash, and no load error in the log.
12. **Workspace indicator.** Create two or more virtual desktops in System Settings, set
    `"workspaceStyle": "numbers"` (and then `"text"`, `"dots"`). Expect one square/dot per desktop with
    the current one filled, `01 · Personal` in text style when the desktop has a name, and a click on a
    square switching desktop. With one desktop nothing should draw. Screenshot each style, and the log
    line `ELTODOCKDESK <n> desktops` should show the real count.
13. **Rail.** `options.dock: "rail-dock"` with `dock.edge: "left"`. Expect a narrow vertical rail on the
    left with the launcher at the top, pinned tiles, one tile per open window, and the workspace
    indicator and clock at the bottom; right-click opens Pin/Unpin beside the rail and the menu is not
    cut off by the screen edge. Then `"edge": "right"` and expect it mirrored. Screenshots both.
14. **Second surface.** `dock.secondSurface: "top"` with the bar at the bottom. Expect a thin strip
    along the top with the launcher, one button per open window, the readouts, the pager and the clock,
    and the dock still where it was. Then note what happens with the Notch also on the top edge: which
    one is visible, which one takes the click. That answer decides whether the strip can stay.

Proof is the screenshots plus a clean shell log. Anything not covered above stays unproven; do not
merge on the strength of qmllint alone.

## Verification level (L0 design / L1 sandbox / L2 VM / L3 hardware)

- **L0 design:** this document, written against PR #36's contract (`elto-worlds/HANDOFF.md` 2).
- **L1 sandbox: reached.** `qmllint` passes on every QML file in the PR (`build, lint, secrets`), and
  the dock smoke loads both variants plus the fallback case in Quickshell 0.3.2 under nested KWin in
  the Arch container.
- **L2 VM: not reached.** Needs the plan above; that is the only place appearance, geometry, clicks,
  glass, blur, fullscreen and multi-monitor are decided.
- **L3 hardware: not reached.**
- No screenshots exist, because nothing here has ever been on a screen. Nothing was run on the machine
  where this was written either: no Qt or Quickshell was available there, so CI is the only place this
  code has executed.

## Per-world identity tokens (optional)

A world can give the dock its own identity through optional keys in the `dock` section of its theme
overlay. Every key is optional. Absent, mistyped or unknown values fall back to the default in the last
column, which is exactly what the dock drew before these keys existed, so a world that omits them is
unchanged and a typo can never produce a broken dock. `Dock.qml` resolves and validates them once
(`dock.look`); both variants only read the resolved values.

| key | values | what it changes | default |
| --- | --- | --- | --- |
| `dockMaterial` | `paper` `flat` `glass` `gloss` `bevel` | surface of the bar: flat fill, translucent glass with a light border, a gloss highlight band, or a two-tone bevel (light top and left, dark bottom and right, the 95 look) | `paper` |
| `dockRadius` | number | corner radius of the island (the bar variant is full width and has none) | `dock.radius` |
| `dockHeight` | number | bar height | `dock.height` |
| `dockButton` | `circle` `rounded` `square` | shape of the hover halo behind a pinned app | `circle` |
| `launcherMark` | `none` `dot` `label` `button` `logo` | leading mark before the pinned apps; `label` draws plain `launcherLabel`, `button` draws it as a clickable button with a caret that opens the app drawer, `logo` draws the world's own `launcherLogo` (plus `launcherLabel` when it is not empty) inside that button | `none` |
| `launcherLabel` | string | text for `launcherMark: "label"` or `"button"`; also drawn next to the logo when set | `Elto` |
| `launcherLogo` | string | path to the world's launcher art: absolute, or relative to the shell root (`icons/launcher/aero.svg`). Drawn untinted, never recoloured, and a missing file falls back to `launcherLabel` | empty |
| `launcherLogoSize` | number | height and width of that art in px, clamped to 10-40 | `22` |
| `clockStyle` | `text` `pill` `none` | clock in the system area: plain text, a pill, or none | `text` |
| `clockPosition` | `end` `start` | clock sits in the system area at the end, or at the leading edge | `end` |
| `trayStyle` | `text` `compact` `none` | status readouts: full with the Settings entry, smaller without it, or hidden | `text` |
| `activeIndicator` | `pill` `dot` `bar` `none` | how a running app is marked: filled halo, a dot under the tile, a short bar, or nothing | `pill` |
| `taskStyle` | `pill` `button` `label` | how an open window is drawn: the pill with a generic glyph, a flat button with the app's own icon, or the title alone | `pill` |
| `edge` | `bottom` `top` `left` `right` | which screen edge the dock sits on; the menu and the shadows follow. `left` and `right` are for the rail variant | `bottom` |
| `workspaceStyle` | `none` `text` `numbers` `dots` | the workspace indicator: `01 · Personal` or `Desktop 2` as text, one square per desktop, one dot per desktop, or nothing. Clicking it switches desktop (text moves on, numbers and dots jump). Draws nothing while KWin reports a single desktop | `text` |
| `secondSurface` | `none` `top` | an extra thin strip along the top edge with the launcher, one button per open window and the system area, while the dock keeps its own edge | `none` |
| `railWidth` | number | width of the rail variant, clamped to 40-96 | `56` |
| `stripHeight` | number | height of the top strip, clamped to 24-64 | `34` |

Example, a world that wants a raised gloss bar at the top with a start label and dot markers:

```json
"dock": {
  "dockMaterial": "gloss",
  "dockButton": "rounded",
  "launcherMark": "label",
  "launcherLabel": "Start",
  "activeIndicator": "dot",
  "trayStyle": "compact",
  "edge": "top"
}
```

Proof level: the tokens are code-complete and the fallback path is the pre-existing rendering, but the
VM run is what proves it. Nothing here changes window tracking, pinning or launching.
