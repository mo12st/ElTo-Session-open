# Dock icons: held, illustrated round as concepts

Status: **held.** No drawn direction from the rounds below shipped. The dock draws the shell's Lucide
glyphs, except for a temporary set of real GNOME app icons now applied for judging (see below).

Temporary: `icons/dock/gnome/` holds real GNOME app icons, unmodified, wired through two theme keys
(`dock.glyphDir`, `dock.glyphTint` in `themes/soft-paper/theme.json`). All seven dock slots use them:
folder, terminal, globe (Epiphany), notebook-pen, image, mail (Geary), palette. Settings, Clocks and the
legacy windows file are vendored with no dock slot. Licences and sources: THIRD-PARTY-LICENSES.md. Swap
back with `"glyphDir": "lucide"`.
Twelve rounds happened and none shipped:

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
   clock. **Rejected: ugly, and green is not allowed.**
7. Green is rejected for dock icons: no sage and no ink-green in plates, objects or details. Spec v2 keeps
   its sizes, depth, shadow and legibility rules, and its palette is now paper, cream, rust, ochre, warm
   brown, charcoal and clay rose, with charcoal, warm brown and dark ochre plates. Concept 3 was redrawn
   with that palette and checked at 22 and 30 px. **Rejected: the shapes themselves read crude, not only
   the colours.**
8. Concept 4 redraws the objects with continuous curves, one radius per role, even negative space, inset
   rules and deliberate overlaps (spec v2 section 11). Terminal, notebook, image, settings, palette and
   window were rebuilt; the rosette replaced the polygon gear. Checked at 22 and 30 px. **Rejected: he wants
   a different design.**
9. Icon work was held until he picked a style family. **He picked macOS Big Sur**: rounded-square tile with a
   colourful gradient, soft gloss, depth, a clear symbol.
10. Concept 5 is drawn in that language: one gradient tile per icon, a cream symbol with a contact shadow,
   no green anywhere, and every symbol measured against its own tile. Checked at 22 and 30 px. **Rejected
   as well.**
11. **Held again.** No new concept is drawn until he says what specifically is wrong with concept 5. Ten
    drawings across five languages have now been rejected without a stated reason, so the next round waits
    for that feedback rather than guessing again.
12. He then gave the reason for concept 5: **ugly, very primitive**, and **use better colours**. A richer
    Big Sur revision was drawn to that note but never sent, because he replaced the direction before it
    went out. The new direction, in his words: **imitate Notion and Claude**. Concept 6 is drawn in that
    language: a warm off-white card, soft ink drawing with cream and terracotta/clay fills, friendly
    rounded shapes, no green, and three to five detail elements per icon instead of concept 5's single
    flat symbol. Checked at 22 and 30 px and as an on-dock strip. Awaiting his read.

The brief, as relayed: Apple-style dimensional icons, layered shapes, soft gradients, highlights and
depth, each drawn originally in the ElTo palette with the snail and paper identity. Self-drawn, free
licences only, no Apple assets, no paid tools.

## The concept on the table

| # | concept | what it is |
| --- | --- | --- |
| 6 | Notion / Claude language | warm off-white card with a hairline warm border, soft ink drawing (#2b2521) with cream (#f6efdf), terracotta (#c0603c), clay (#b98a6f) and muted ochre fills, rounded organic shapes, small friendly illustration symbols, no green. Concept only |
| 5 | Big Sur language | one gradient squircle per icon (amber to rust, warm brown to charcoal, clay to rust, mauve to plum, grey to slate, ochre-clay to rust-brown, slate blue, brown), soft gloss and highlight, cream symbol with a contact shadow, no green. Rejected |
| 4 | refined artifacts | concept 3's palette and structure with rebuilt geometry: continuous curves, one radius per role, even negative space, inset rules, rosette instead of polygon gear. Rejected |
| 3 | illustrated artifacts | paper objects on charcoal, warm brown and dark ochre plates; variable depth; one overlap per object as the family gesture; per-icon redesigns; no green anywhere |

### Concept 6: the Notion / Claude language

He named the reference himself, so this round copies a language rather than guessing one. What was taken
from each:

- **Notion**: the warm off-white ground instead of a saturated plate, the soft near-black ink of the
  drawing, hairline warm borders, and small friendly objects rather than abstract glyphs.
- **Claude**: cream and terracotta/clay as the only colour, soft rounded organic silhouettes, and a calm
  low-contrast feel.

Palette: card `#fdfaf3` to `#f4ecdc` with a `#e3d9c4` hairline, ink `#2b2521`, cream `#f6efdf`, terracotta
`#c0603c` with a darker `#9c4730`, clay `#b98a6f`, muted ochre `#c99a5a`. Ink on the card measures 14.5:1
and terracotta 4.1:1, so the accents survive the card at dock size.

Per icon: `folder` ink folder with a terracotta tab and a cream sheet inside; `terminal` ink screen with a
clay title rule, cream chevron and cursor; `notebook` cream cover with an ink spine, terracotta ribbon and
rule lines; `image` ink frame with cream mount, clay and ochre hills, terracotta sun; `settings` ink
six-lobed gear with a cream ring and terracotta hub; `palette` cream palette with ink thumb hole and
terracotta, ochre and clay pigment; `window` clay card behind a cream card with a terracotta rule and
control dot; `clock` cream face, ink rim and hands, terracotta second hand.

Nothing here is implemented, vendored or wired. The same open questions below still apply.

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
2. `LIcon.qml`: a `dir` property (default `lucide`) plus a flag to skip the tint pass for these. Done for
   the temporary GNOME set (`dir`, `tintArt`, and a fall back to the Lucide glyph if a file is missing).
3. The dock window files pass the chosen direction; unknown or missing falls back to today's Lucide glyphs.
4. Licence text only if a third-party source ends up in the tree; everything above is drawn here.
5. VM step 12 in DOCK-VARIANTS.md is the proof; nothing before that counts.

## Also open

The window pill's leading mark: drop it and keep only the serif title, keep a generic window glyph, or
use the app's own icon. Still his call; untouched.
