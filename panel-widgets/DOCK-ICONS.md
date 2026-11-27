# Dock icons: held, illustrated round as concepts

Status: **nothing implemented, nothing merged.** The dock still draws the shell's Lucide glyphs. Six
rounds happened and none shipped:

1. Four line-icon sets (Lucide as today, Iconoir 1.5px, Phosphor Light, Tabler). Iconoir was shipped and
   he rejected all four: thin line glyphs, too plain. Reverted in `b68f055` and `c3cc6dd`.
2. Three treatments (A ink-over-wash, B palette colour, C paper wash). Rejected.
3. Three Apple-shaped tile directions on Phosphor Fill symbols (D paper plate, E ink plate, F palette
   plates). **Rejected too: the flat glyph on a tile is the problem.**
4. Three illustrated directions (G / H / I) where each icon is a drawn object with layers, gradients and
   depth. **Rejected as well.**
5. A written spec v1 plus two concepts built to it (1 paper plate, 2 ink plate). Rejected.
6. An outside design review of the spec and both concepts recommended dropping the universal extrusion,
   the shadow stack, the mandatory highlight and the three-shape rule, enlarging the object (plate 90-92,
   object 66-70), varying the plates, and redesigning six of the eight metaphors. Spec v2 and concept 3
   ("illustrated artifacts") follow that: variable depth, one soft shadow, three plate colours, an object
   at 74% of the plate, and new drawings for terminal, notebook, image, settings, palette, window and
   clock. **He picks, or asks for something else, before any file changes.**

The brief, as relayed: Apple-style dimensional icons, layered shapes, soft gradients, highlights and
depth, each drawn originally in the ElTo palette with the snail and paper identity. Self-drawn, free
licences only, no Apple assets, no paid tools.

## The concept on the table

| # | concept | what it is |
| --- | --- | --- |
| 3 | illustrated artifacts | paper objects on ink, dark sage and dark ochre plates; variable depth; one overlap per object as the family gesture; per-icon redesigns |

Built to `DOCK-ICON-SPEC.md` v2. Concept 1 (cream plates) is rejected: its plate disappears against the
cream dock. Concept 2's value structure survives inside concept 3, with the plate no longer dominant and
with plate variety.

Every icon is drawn here as SVG (100x100 viewBox, gradients and layered paths), then composited at
render time for the object's soft shadow, the plate's top gloss and bottom shade, and a faint embossed
snail at the plate corner. Nothing comes from an icon font: no Phosphor, no Lucide, no Apple shape.

Coverage: `folder`, `terminal`, `notebook`, `image`, `settings`, `palette`, `window`, plus `clock` for the
system area in this PR.

## Honest limits

- Renders made outside Quickshell, labelled CONCEPT. They show the drawing, not the shell's tint path,
  and they are not screenshots of a running session.
- The objects are drawn from primitives (rounded rects, paths, circles, gradients). They are original and
  reproducible, but they are illustration by geometry, not by hand. Anything more painterly is a
  different production route.
- The snail is a faint emboss at 88 px and disappears at dock size. If he wants the snail to read as a
  character at 30 px it needs its own silhouette and its own tile, not a corner mark.
- `I` has no plate, so on a light world it depends on its cast shadow and ink edge to separate from the
  bar. On the dark world it would need a light edge instead.
- Nothing here has been through the shell's `LIcon`/`MultiEffect` tint path. These are multi-colour
  drawings, so they would ship as pre-coloured files and skip the tint pass; that is a small change to
  `LIcon` when a direction is picked.

## If he picks one

1. Vendor the eight SVGs under `icons/dock/<direction>/` with the logical dock names (`folder`,
   `terminal`, `globe`, `notebook-pen`, `image`, `mail`, `palette`, `window`).
2. `LIcon.qml`: a `dir` property (default `lucide`) plus a flag to skip the tint pass for these.
3. The dock window files pass the chosen direction; unknown or missing falls back to today's Lucide glyphs.
4. Licence text only if a third-party source ends up in the tree; everything above is drawn here.
5. VM step 12 in DOCK-VARIANTS.md is the proof; nothing before that counts.

## Also open

The window pill's leading mark: drop it and keep only the serif title, keep a generic window glyph, or
use the app's own icon. Still his call; untouched.
