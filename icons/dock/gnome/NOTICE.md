# GNOME app icons: notices

TEMPORARY set. These are the official app icons of GNOME projects, taken from each project's own
repository and vendored unmodified. Nothing here was redrawn or recoloured.

Each file is used under the licence named for it below. The full licence texts sit in `LICENSES/` next to
this file. Attribution: the GNOME Project (Adwaita's COPYING says naming "GNOME Project" is enough, with a
link to https://www.gnome.org where available). Three of the files also name the GNOME Design Team as author
in their own metadata.

| file here | upstream file | upstream project and path | upstream licence file, read on 2026-11-27 | licence used here |
| --- | --- | --- | --- | --- |
| folder.svg | org.gnome.Nautilus.svg | github.com/GNOME/nautilus, `data/icons/hicolor/scalable/apps/` | `LICENSE`, GPL-3.0 | CC BY-SA 4.0, declared in the file (`dc:creator` GNOME Design Team); repository GPL-3.0 |
| terminal.svg | org.gnome.Console.svg | github.com/GNOME/console, `data/` | `COPYING`, GPL-3.0 | GPL-3.0 (repository; the file declares nothing) |
| globe.svg | org.gnome.Epiphany.svg | github.com/GNOME/epiphany, `data/icons/hicolor/scalable/apps/` | `COPYING`, GPL-3.0 | GPL-3.0 (repository; the file declares nothing) |
| notebook-pen.svg | org.gnome.TextEditor.svg | github.com/GNOME/gnome-text-editor, `data/icons/` | `COPYING`, GPL-3.0 | GPL-3.0 (repository; the file declares nothing) |
| image.svg | org.gnome.Loupe.svg | github.com/GNOME/loupe, `data/icons/hicolor/scalable/apps/` | `COPYING.md`, GPL-3.0 | GPL-3.0 (repository; the file declares nothing) |
| mail.svg | org.gnome.Geary.svg | gitlab.gnome.org/GNOME/geary, `icons/hicolor/scalable/apps/` | `COPYING`, LGPL-2.1 or later | LGPL-2.1 (repository; the file declares nothing) |
| palette.svg | org.gnome.design.Palette.svg | gitlab.gnome.org/World/design/palette, `data/` | `COPYING`, GPL-3.0 | CC BY-SA 4.0, declared in the file (`dc:creator` GNOME Design Team); repository GPL-3.0 |
| settings.svg | org.gnome.Settings.svg | github.com/GNOME/gnome-control-center, `data/icons/hicolor/scalable/apps/` | `COPYING`, GPL-2.0 | GPL-2.0 (repository; the file declares nothing) |
| clock.svg | org.gnome.clocks.svg | github.com/GNOME/gnome-clocks, `data/icons/hicolor/scalable/apps/` | `LICENSE.md`, GPL-2.0 | CC BY-SA 4.0, declared in the file (`dc:creator` GNOME Design Team); repository GPL-2.0 |
| window.svg | preferences-system-windows.svg | github.com/GNOME/adwaita-icon-theme, tag `GNOME_ICON_THEME_3_0_0`, `src/` | `COPYING`, LGPL-3.0 or CC BY-SA 3.0 | LGPL-3.0 (chosen); the same COPYING offers CC BY-SA 3.0 as the alternative, and its wording names the United States port |

How the licence was decided for each file:

- Where the SVG declares a licence in its own metadata, that declaration is used, because it is the author's
  own statement about the artwork. The project's repository licence is listed next to it.
- Where the SVG declares nothing, the project's repository licence covers the artwork, since the icon is part
  of that project's work and no separate icon licence is stated in the project.
- No file here has unclear terms, so no dock slot falls back to the Lucide glyph on licensing grounds.

Footnotes: the CC BY-SA 3.0 text shipped in `LICENSES/` is the Unported 3.0 legal code, which is the text
Adwaita's COPYING links to; the United States port it names in words is not shipped, and `window.svg` does
not rely on it because LGPL-3.0 is the licence chosen for that file. The GPL and LGPL texts are the
canonical ones from gnu.org (LGPL texts from the SPDX licence list, identical wording).

Modifications: only `window.svg` differs from upstream bytes. The artwork is untouched; the root `width` and
`height` were set to 128 and a `viewBox` was added around the largest of the four size variants the original
canvas stacks, otherwise all four would draw. Everything else is byte-identical to upstream.

These files are not covered by this repository's LICENSE, which cannot narrow their terms. See the
carve-out in LICENSE and the entry in THIRD-PARTY-LICENSES.md.
