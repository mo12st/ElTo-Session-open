# ElTo Qt/KDE theme for Dolphin and other KDE apps (CONCEPT, UNVERIFIED)

Goal: Dolphin looks like ElTo without patching Dolphin (GPL-2.0+, not modified).

## What is here
- `gen_colors.py` builds `ElTo.colors` (a KDE color scheme) from `palette/elto-palette.json`. Colors stay in the one palette source. Edit the palette, run `python3 theme/gen_colors.py`.
- Apply (user level):
  ```
  mkdir -p ~/.local/share/color-schemes && cp theme/ElTo.colors ~/.local/share/color-schemes/
  plasma-apply-colorscheme ElTo
  ```
  Dolphin, Kate, System Settings and every Breeze-style app pick it up. The Aurorae window decoration already uses the same palette.

## Icon theme choice (free licenses)
- Recommended: **Breeze icons** (LGPL-2.1+, KDE, per KDE's COPYING-ICONS). Monochrome UI icons follow the color scheme, so they recolor to ElTo green automatically. Already a Plasma dependency.
- Alternative: **Papirus** (GPL-3.0, per its LICENSE file). Colorful, popular, but it does not recolor from the scheme, and it is an extra package.
- Set: `kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze` (or `Papirus`).
- A custom ElTo icon theme is not proposed here: drawing a full set is out of scope.

## Not done yet
- Kvantum: a Kvantum theme needs an SVG with every widget element, plus a kvconfig. Writing that blind is not worth it before the color scheme is checked in the VM. If the color scheme alone is not enough, a Kvantum theme or a QProxyStyle can be the next PR.
- Rounded corners and spacing beyond what the Breeze style offers.

## VM check list
1. `plasma-apply-colorscheme ElTo`, open Dolphin, confirm cream window, green text, midGreen selection, readable inactive text.
2. Check disabled and tooltip colors.
3. Report which parts still look off, and whether Kvantum is wanted.
