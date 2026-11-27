# Dock icons: held, three richer directions as concepts

Status: **nothing implemented, nothing merged.** The dock still draws the shell's Lucide glyphs. Two
rounds happened and neither shipped:

1. I proposed four line-icon sets (Lucide as today, Iconoir 1.5px, Phosphor Light, Tabler) and shipped
   Iconoir for the dock. He rejected all four as ugly, then said the problem is the look itself: too
   plain, too simple, thin line glyphs. That change was reverted in `b68f055` and `c3cc6dd`; the branch
   is back to the shell's icons, and the dock smoke's icon-file check went with it.
2. Now three richer directions are prepared as concept images only, labelled CONCEPT. **He picks one, or
   asks for something else, before any file changes.**

## The three directions

All three use **Phosphor Fill** as the source shapes (MIT, https://github.com/phosphor-icons/core,
`assets/fill/<name>-fill.svg`, verified by fetching every glyph on 2026-11-27), coloured from the ElTo
palette: ink `#164437`, rust `#a05040`, deep sage `#7fa08c`, ochre `#b08246`, on paper `#f6f1e4`.

| # | direction | what it is | why it is richer |
| --- | --- | --- | --- |
| A | ink over wash | solid glyph silhouette filled with a sage wash, an ink edge drawn over it | two tones and a drawn edge; reads as ink line filled with colour rather than an outline icon |
| B | palette colour | solid glyph, one ElTo ink per glyph family (ink, rust, sage, ochre) | colour carries meaning; the most character, the most risk of noise in a row of seven |
| C | paper wash | solid glyph rendered as an aquarelle wash: uneven alpha, softened edge, paper grain, rust ink | the only one that looks painted; the closest to the world's paper walls |

Two images were produced for the review and sent with the status report: the three directions at 44 px
per glyph, and the same three at dock size (22 px in a 40 px tile) on the paper bar. Both were rendered
with ImageMagick outside Quickshell, so they show the drawing, not the shell's tint path.

## Honest limits of these concepts

- A and C are **treatments**, not icon sets: I generated them from Phosphor Fill silhouettes with a wash,
  an edge and grain. They are reproducible as a build step, but they are not hand-painted art. If he
  wants real aquarelle glyphs, that is his own brush, or art he approves; nothing free that I could
  verify looks like a painted ElTo glyph.
- At 22 px the ink edge in A thins to about one pixel and the wash fill dominates, so A reads closer to
  "soft filled" than to "outlined". That is visible in the at-size image, not hidden.
- No icon has been checked inside the shell's `MultiEffect` tint path. A and B are single-colour shapes
  and would tint like today's glyphs; C is multi-alpha and would need to be shipped pre-coloured rather
  than tinted, which is a small change to `LIcon`.
- Licences: Phosphor is MIT and covers all eight dock glyphs (`folder`, `terminal`, `globe`, `notebook`,
  `image`, `envelope`, `palette`, `app-window`). Attribution text is ready to add to
  `THIRD-PARTY-LICENSES.md` if a direction is picked.

## If he picks one

1. Vendor the eight Phosphor Fill SVGs into `icons/dock/<direction>/` under the logical dock names
   (`folder`, `terminal`, `globe`, `notebook-pen`, `image`, `mail`, `palette`, `window`), pre-coloured or
   white depending on the direction.
2. `LIcon.qml`: `dir` property (default `lucide`) and, for C, a flag to skip the tint pass.
3. The two dock window files pass the dock's folder.
4. `THIRD-PARTY-LICENSES.md` gets the Phosphor MIT text; the dock smoke's icon-file check comes back so a
   blank tile fails CI instead of showing up on screen.
5. VM step 12 in DOCK-VARIANTS.md is the proof; nothing before that counts.

## Also open

The window pill's leading mark: drop it and keep only the serif title, keep a generic window glyph, or
use the app's own icon. Still his call; untouched.
