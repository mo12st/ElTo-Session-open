# Trail (v1)

ElTo file browser and the "This computer" page, built from the approved design image as a Quickshell window. Own code and own art; no Dolphin code.

Run: `quickshell -p elto-files/trail.qml` (one Trail window; "This computer" is a page in its sidebar, like Explorer). `TRAIL_START=computer` opens on that page; `TRAIL_START=/some/folder` opens Trail there. Launchers: `trail.desktop`, `trail-computer.desktop`.

v1 scope: browse folders, open files with xdg-open, sidebar (This computer, Home, Documents, Downloads, Pictures, Trash), breadcrumb, back/forward (also Backspace, Alt+Left/Right), "This computer" with folder shortcuts (item counts) and drive cards (usage bar, percent, Eject for USB drives).

Not in v1: copy, move, delete, rename, tabs, search, network. Those come later through KDE KIO.

`trail-helper.py` reads drives (lsblk + disk usage) and folder item counts as JSON and ejects with udisksctl. Windows are decorated by KWin (Aurorae theme), like the Welcome app. Theme: `themes/soft-paper` plus the user overlay.

Verification so far: layout render with stubbed Quickshell types in a Qt 6 offscreen run (software renderer: tinted icons do not draw there). Real run under Quickshell and KWin is for the VM.

## Theming

Trail has no styling of its own. Every colour, radius and font comes from the ElTo theme tokens, read like the Welcome app and the shell (`themes/soft-paper/theme.json` plus the user overlay `~/.config/elto/theme.json` or `$ELTO_THEME`). The overlay file is watched, so switching the theme or world restyles an open Trail live.

Tokens used: roles `surface`, `surfaceAlt`, `text`, `textMuted`, `accent`, `selection`, `divider`, `disabled`; shape `radiusWindow` (window and sidebar), `radiusCard` (tiles, rows, cards, art corners), `radiusPill` (breadcrumb, buttons, bars); fonts `serif` and `sans`; option `motion`. The folder, drive and snail art is drawn in QML from these roles (`FolderArt.qml`, `DriveArt.qml`, `SnailArt.qml`). Mono icons (`icons/`, white SVG) are tinted with `LIcon.qml`, the same method as Welcome.

Limits: the schema has no spacing or icon-stroke tokens yet, so layout sizes and icon stroke width are fixed constants in the QML. Derived shades (hover, art shading, stripes) are computed from the roles with `Qt.alpha`, `Qt.darker`, `Qt.lighter`, `Qt.tint`.
