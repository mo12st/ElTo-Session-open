# Dock icons: held, three Apple-style tile directions as concepts

Status: **nothing implemented, nothing merged.** The dock still draws the shell's Lucide glyphs. Three
rounds happened and none shipped:

1. Four line-icon sets (Lucide as today, Iconoir 1.5px, Phosphor Light, Tabler); Iconoir was shipped for
   the dock and he rejected all four as ugly. The problem is the look itself: thin line glyphs, too plain.
   Reverted in `b68f055` and `c3cc6dd`, including the dock smoke's icon-file check.
2. Three richer treatments (A ink-over-wash, B palette colour, C paper wash) rendered as concept images.
   **He rejected A/B/C too.** They are dropped and are no longer options in this PR.
3. Now three Apple-shaped tile directions, D / E / F, drawn as concept images only. **He picks one, or
   asks for something else, before any file changes.**

His brief for round 3, in his words: Apple-style icons, rounded-square app tiles with soft depth and a
clear symbol, macOS Big Sur feel, with ElTo's own identity (paper, ink, sage, rust palette, snail
character). Original art only, no Apple assets, free licences or self-drawn, no paid tools.

## The three directions

| # | direction | plate | symbol | notes |
| --- | --- | --- | --- | --- |
| D | paper plate | cream gradient `#efe9d8` to `#e3dac4`, faint ink hairline, warm soft shadow | ink `#164437` | lightest; at 28 px the plate nearly melts into the paper bar, so picking D means darkening the plate one step |
| E | ink plate | deep ink gradient `#164437` to `#0d2b22`, gloss along the top | paper `#f6f1e4` | strongest contrast against the bar, closest to the classic world's ink |
| F | palette plates | one ElTo ink per tile: sage `#7fa08c` folder and image, ink terminal and window, ochre `#b08246` notebook and clock, rust `#a05040` settings and palette | paper | colour carries the app family; small snail watermark bottom-right carries the character |

Tiles, gradients, gloss, hairline, grain and the snail are drawn here in Python/PIL from the classic-world
palette. The symbols inside are **Phosphor Fill** (MIT, https://github.com/phosphor-icons/core,
`assets/fill/<name>-fill.svg`), fetched and rendered on 2026-11-27.

Coverage: `folder`, `terminal`, `notebook`, `image`, `settings`, `palette`, `window`, plus `clock` for the
system area in PR #46. Settings serves both the dock tile and the bar's Control entry.

## Honest limits of these concepts

- These are renders made outside Quickshell and labelled CONCEPT. They show the drawing, not the shell's
  tint path, and they are not screenshots of a running session.
- The snail is a watermark drawn from the session's own `lock/assets/snail.png`, tinted to paper. At 28 px
  it reads as a faint mark, not as a character. If he wants the snail legible at dock size it needs its own
  silhouette rather than a scaled lock-screen image.
- D's plate and the bar are both paper, so the tile edge is the only separation. E and F have no such
  problem.
- Symbol sizes are 52% of the tile. That number is a judgement, not a measurement of any system.
- Licences: Phosphor is MIT and covers all eight symbols. Attribution text is ready for
  `THIRD-PARTY-LICENSES.md` if a direction is picked. Nothing Apple-derived is used.

## If he picks one

1. Vendor the eight Phosphor Fill SVGs under `icons/dock/<direction>/` with the logical dock names
   (`folder`, `terminal`, `globe`, `notebook-pen`, `image`, `mail`, `palette`, `window`), pre-coloured.
2. Ship the plate as a drawn QML item (gradient + rounded rect + shadow) rather than as raster tiles, so it
   scales and stays crisp on every monitor scale.
3. The dock window files pass the chosen direction; unknown or missing falls back to today's Lucide glyphs.
4. `THIRD-PARTY-LICENSES.md` gets the Phosphor MIT text; the dock smoke's icon-file check comes back so a
   blank tile fails CI instead of showing up on screen.
5. VM step 12 in DOCK-VARIANTS.md is the proof; nothing before that counts.

## Also open

The window pill's leading mark: drop it and keep only the serif title, keep a generic window glyph, or
use the app's own icon. Still his call; untouched.
