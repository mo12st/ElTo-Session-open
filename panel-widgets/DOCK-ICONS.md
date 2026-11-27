# Dock icons: proposal (needs the user's pick)

Status: **proposal only, nothing changed.** No icon file in the repo was touched. Choosing a set is an
artistic decision, so it waits for his approval; the switch itself is one small commit after that.

## What the dock draws today

- `panel-widgets/LIcon.qml` loads `icons/lucide/<name>.svg` from the repo, paints it white, and tints it
  with `MultiEffect` to a theme color. The path is hardcoded, so every icon in the shell (notch, drawer,
  Control) comes from the same Lucide folder: 18 SVGs, `stroke-width="2"`.
- The dock's pinned apps use the glyph names in `dock.glyphs` of the theme (`folder`, `terminal`,
  `globe`, `notebook-pen`, `image`, `mail`, `palette`), tinted `Theme.text`, at `dock.icon` (22 px) inside
  a `dock.tile` (40 px) tile. An app with no glyph falls back to its own icon theme image
  (`IconImage`), which is right: the glyph is a calm stand-in, not the real app mark.
- Both dock variants also draw one Lucide glyph, `panel-top`, as the leading mark inside every window
  pill, at 16 px, tinted `Theme.textMuted`.
- License today: Lucide, ISC, recorded in `THIRD-PARTY-LICENSES.md`.

## What is off

1. A 2 px stroke at 22 px on cream paper reads crisp and technical next to the serif and the aquarelle
   walls. The dock is the calmest surface in the session and its icons are the loudest marks on it.
2. `panel-top` is a *panel* icon used as a *window* marker. It says "a panel" next to a window title,
   which is the one place where the dock is semantically wrong rather than just stylistically off.

## Candidates (all free, license verified from the upstream LICENSE file)

| set | license | stroke | source | dock glyphs |
| --- | --- | --- | --- | --- |
| Lucide (today) | ISC | 2 px, round caps | https://github.com/lucide-icons/lucide (LICENSE) | all present |
| **Iconoir** | MIT | 1.5 px, round caps | https://github.com/iconoir-icons/iconoir (LICENSE) | all present as `folder`, `terminal`, `globe`, `journal`, `media-image`, `mail`, `palette`, `app-window` |
| Phosphor (Light) | MIT | filled silhouette, thin | https://github.com/phosphor-icons/core (LICENSE) | all present as `*-light` files |
| Tabler (outline) | MIT | 2 px, round caps | https://github.com/tabler/tabler-icons (LICENSE) | all present as `folder`, `terminal`, `globe`, `notebook`, `photo`, `mail`, `palette`, `app-window` |

Each one was checked by fetching the actual files from the upstream repository on 2026-11-27, not from
memory: every name in the table returned HTTP 200 and was rendered. Phosphor ships `fill` silhouettes,
not strokes, so its "Light" weight is thin filled shapes; the other three are stroke icons.

A preview was rendered for this review (44 px, ink `#164437` on cream `#f6f1e4`, ImageMagick outside the
shell) and sent to the user with the proposal. It is not committed: it is a review aid, not art.

## Recommendation

**Iconoir regular, 1.5 px, MIT.** It is the same line-icon language as today, so the dock still belongs
with the notch and the drawer, but the thinner stroke and rounder terminals sit calmly on paper. Second
choice is Phosphor Light if he wants the glyphs to read as ink silhouettes instead of lines; Tabler is
the "keep the current look, better coverage" option and the least interesting.

Vendored as `icons/dock/iconoir/` with the **logical dock names** (`folder.svg`, `terminal.svg`,
`globe.svg`, `notebook-pen.svg` copied from Iconoir's `journal`, `image.svg` from `media-image`,
`mail.svg`, `palette.svg`, `window.svg` from `app-window`), so `dock.glyphs` values, the theme schema and
every world file stay exactly as they are. The rename happens once, when the files are vendored; no name
mapping is needed at runtime.

Wiring, if approved (one commit, no schema change):

1. Add the eight SVGs with `currentColor` replaced by `#ffffff` (same trick the Lucide files use) plus
   the MIT notice in `THIRD-PARTY-LICENSES.md`.
2. `LIcon.qml`: `property string dir: "lucide"` and source `"../icons/" + root.dir + "/" + name + ".svg"`.
   Default keeps every existing caller unchanged.
3. `DockWindow.qml` and `DockBar.qml`: pass `dir: "dock/iconoir"` for the pinned glyphs and the pill mark.
4. Nothing else: `dock.glyphs`, `themes/soft-paper/theme.json` and `world.schema.json` are untouched.

## Second question in the same area

The window pill's leading mark. Three options, in order of my preference:

1. Drop it and let the pill show only the window title in serif italic. The calmest, and it removes a
   redundant mark: the title already says which window it is.
2. Keep a mark but use the app's own icon (`entryFor(appid)` + `IconImage`) so the pill matches the tile.
3. Keep a generic glyph, but a window one (`window`/`app-window`) instead of `panel-top`.

I would not decide this without him: option 1 changes how the pill reads, which is a design call.

## Verification level

L0 design only. Nothing here is in the shell: no icon file was added, no QML was changed for this, and
the preview was rendered outside Quickshell. If he picks a set, the switch is L1 (CI load test) at best
until the implementer sees it in the VM.
