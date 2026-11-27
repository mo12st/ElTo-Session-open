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
| `rail-dock` | Rail dock | no | reserved id, concept only, resolves to island |
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

## Checked in CI (a container, not the VM)

`.github/workflows/dock-variants-smoke.yml` runs `panel-widgets/dock-smoke.sh` in the same disposable
Arch container as the panel smoke. It starts one nested KWin, then loads `dock-smoke.qml` (the dock and
nothing else) three times with a different overlay:

| case | overlay `options.dock` | expected `ELTODOCK variant` log |
| --- | --- | --- |
| absent key | key not set | `island` |
| bar | `"bar"` | `bar` |
| fallback | `"nonsense"` | `island` |

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
12. **Icons.** In both variants, every pinned tile shows a dock glyph (Iconoir, thinner stroke than the
    notch's Lucide) and no tile is blank; the window pills show the small `window` mark, not the old
    panel glyph. Screenshot `dock-icons.png`. If a tile is blank, the vendored file name and the
    `dock.glyphs` value disagree - report which app, do not merge.

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
