# Dock icons: Iconoir 1.5px (implemented here)

Status: **implemented in this PR, L1.** The dock draws its own icon set now, not the shell's Lucide
glyphs. Nothing has been seen on a screen yet; the appearance is unproven until the implementer runs the
VM plan in DOCK-VARIANTS.md (the icon check is part of it).

He asked twice for the dock icons to change (Telegram 26248273, 26255758). The set choice below is the
one I recommended and shipped; swapping it is one directory plus one string, so a different pick costs
minutes.

## What changed

| file | change |
| --- | --- |
| `icons/dock/iconoir/*.svg` | eight new files, Iconoir v7.12.2 (MIT), stroke changed from `currentColor` to white so the shell tints them, license header in each file |
| `THIRD-PARTY-LICENSES.md` | Iconoir section with the upstream MIT text and source |
| `panel-widgets/LIcon.qml` | `property string dir: "lucide"`; the source path uses it. Every existing caller keeps Lucide unchanged |
| `panel-widgets/DockWindow.qml`, `DockBar.qml` | pinned glyphs and the pill mark pass `dir: "dock/iconoir"` |

The vendored files carry the **logical dock names**, so no theme value, world file or schema entry
changes: `folder`, `terminal`, `globe`, `notebook-pen`, `image`, `mail`, `palette`, `window`. Upstream
these are `folder`, `terminal`, `globe`, `journal`, `media-image`, `mail`, `palette`, `app-window`; the
rename happened once, when the files were vendored.

The pill's leading mark moved from the shell's `panel-top` glyph to `window` from the dock set: it was a
panel icon standing in for a window, and now it is a window mark drawn in the dock's own stroke weight.

## Why this set

What the dock drew before: `icons/lucide/`, 18 SVGs at `stroke-width="2"`, shared with the notch, the
drawer and Control. A 2 px stroke at 22 px on cream reads crisp and technical next to the serif and the
aquarelle walls, and the dock is the calmest surface in the session.

Four free sets were checked by fetching the actual files from the upstream repositories on 2026-11-27
(every name below returned HTTP 200 and was rendered), not from memory:

| set | license | stroke | source |
| --- | --- | --- | --- |
| Lucide (what the shell uses) | ISC | 2 px, round caps | https://github.com/lucide-icons/lucide |
| **Iconoir (shipped here)** | MIT | 1.5 px, round caps | https://github.com/iconoir-icons/iconoir |
| Phosphor Light | MIT | thin filled silhouette, not a stroke | https://github.com/phosphor-icons/core |
| Tabler outline | MIT | 2 px, round caps | https://github.com/tabler/tabler-icons |

Iconoir keeps the line-icon language, so the dock still belongs with the notch and the drawer, but the
thinner stroke and rounder terminals sit more calmly on paper. Phosphor Light was the alternative if the
glyphs should read as ink silhouettes; Tabler is the "keep today's look, better coverage" option.

## If he prefers another set

1. Vendor eight SVGs into `icons/dock/<set>/` using the logical names above, stroke or fill forced to
   white.
2. Add that set's license to `THIRD-PARTY-LICENSES.md`.
3. Change `dir: "dock/iconoir"` to the new folder in the two dock window files.

Nothing else is involved: `dock.glyphs`, `themes/soft-paper/theme.json` and `world.schema.json` stay as
they are.

## Still open

The pill's leading mark. It is now a `window` glyph from the dock set, which fixes the wrong semantics
but keeps a mark that may be redundant: the title already says which window it is. Two options left for
him:

1. Drop the mark and let the pill show only the title in serif italic. Calmest; a design call.
2. Use the app's own icon (`entryFor(appid)` + `IconImage`) so the pill matches its tile.

## Verification

- **L1:** `qmllint` and the dock smoke (island, bar, fallback) run in CI on this commit. That proves the
  QML still loads, not that the icons look right.
- A preview was rendered outside the shell for the review (44 px, ink `#164437` on cream `#f6f1e4`) and
  sent with the status report. It is a review aid, not a screenshot of the session.
- **Not proven:** the dock with the new icons on a real screen, the 22 px rendering in Quickshell's
  `MultiEffect` tint path, and how the stroke weight reads on paper at real DPI.
