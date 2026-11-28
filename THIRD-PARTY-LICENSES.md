# Third-party licenses

## Lucide icons (icons/lucide/)
Icons: wifi, volume-2, moon, bell-off, sun, play, pause, skip-back, skip-forward, folder, terminal, globe, notebook-pen, image, mail, panel-top, chevron-down. The stroke color was changed from `currentColor` to white so the shell can tint them with theme colors.

ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Source: https://lucide.dev (https://github.com/lucide-icons/lucide)

## Lucide icons on the lock screen (lock/assets/icons/)
moon, rotate-cw, power, skip-back, skip-forward, play, pause, music. Same ISC license as above. Stroke color changed from `currentColor` to ink (#283a32) and cream (#f6f1e4) variants.

## GNOME app icons (icons/dock/gnome/) - TEMPORARY

A temporary set, added so the dock can be judged with real GNOME artwork. Each file is the official app icon
of a GNOME project, downloaded from that project's own repository and vendored unmodified. Nothing here was
redrawn. To go back to the Lucide glyphs, set `"glyphDir": "lucide"` (and `"glyphTint": true`) in the `dock`
section of `themes/soft-paper/theme.json`, or delete both keys.

| file | app | original file | source | license |
| --- | --- | --- | --- | --- |
| folder.svg | Files (Nautilus) | org.gnome.Nautilus.svg | github.com/GNOME/nautilus `data/icons/hicolor/scalable/apps/` | CC BY-SA 4.0 declared in the file; repository GPL-3.0 |
| terminal.svg | Console | org.gnome.Console.svg | github.com/GNOME/console `data/` | GPL-3.0 (repository); no license declared in the file |
| globe.svg | Web (Epiphany) | org.gnome.Epiphany.svg | github.com/GNOME/epiphany `data/icons/hicolor/scalable/apps/` | GPL-3.0 (repository); no license declared in the file |
| notebook-pen.svg | Text Editor | org.gnome.TextEditor.svg | github.com/GNOME/gnome-text-editor `data/icons/` | GPL-3.0 (repository); no license declared in the file |
| image.svg | Image Viewer (Loupe) | org.gnome.Loupe.svg | github.com/GNOME/loupe `data/icons/hicolor/scalable/apps/` | GPL-3.0 (repository); no license declared in the file |
| mail.svg | Mail (Geary) | org.gnome.Geary.svg | gitlab.gnome.org/GNOME/geary `icons/hicolor/scalable/apps/` | LGPL-2.1 (repository COPYING); no license declared in the file |
| palette.svg | Palette | org.gnome.design.Palette.svg | gitlab.gnome.org/World/design/palette `data/` | CC BY-SA 4.0 declared in the file; repository GPL-3.0 |
| settings.svg | Settings | org.gnome.Settings.svg | github.com/GNOME/gnome-control-center `data/icons/hicolor/scalable/apps/` | GPL-2.0 (repository); no license declared in the file |
| clock.svg | Clocks | org.gnome.clocks.svg | github.com/GNOME/gnome-clocks `data/icons/hicolor/scalable/apps/` | CC BY-SA 4.0 declared in the file; repository GPL-2.0 |
| window.svg | Windows (legacy) | preferences-system-windows.svg | github.com/GNOME/adwaita-icon-theme, tag `GNOME_ICON_THEME_3_0_0`, `src/` | LGPL-3.0 or CC BY-SA 3.0 (adwaita COPYING) |

Three of the ten ship as 512 px PNGs (`image.png`, `globe.png`, `mail.png`), rasterised from the unmodified
SVGs because Qt's SVG renderer cannot draw their masks and filters. The SVGs stay in the tree as their
source; see icons/dock/gnome/NOTICE.md.

Attribution: the GNOME Project. Adwaita's COPYING says naming "GNOME Project" is enough
(https://github.com/GNOME/adwaita-icon-theme/blob/master/COPYING); three of the files also name the
GNOME Design Team as author in their own metadata.

The full licence texts ship with the icons, in `icons/dock/gnome/LICENSES/`: GPL-3.0, GPL-2.0, LGPL-2.1,
LGPL-3.0, CC BY-SA 4.0 and CC BY-SA 3.0. Per-file provenance, the upstream licence file that was read for
each icon, and the licence chosen for it are in `icons/dock/gnome/NOTICE.md`.

These files stay under their own licences. The repository LICENSE does not apply to them and cannot narrow
them. All seven dock slots are wired: `folder`, `terminal`, `globe` (Epiphany), `notebook-pen`, `image`,
`mail` (Geary) and `palette`. `settings`, `clock` and `window` are vendored because they are part of the set
but the dock has no slot for them. `window.svg` is the 2008 Adwaita file: the artwork is untouched, the root `width`/`height` were set to
128 and a `viewBox` around the largest of the four size variants it contains was added, because the original
canvas holds four sizes stacked and would draw them all.
