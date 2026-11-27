# Trail (v1)

ElTo file browser and the "This computer" page, built from the approved design image as standalone Quickshell windows. Own code and own art; no Dolphin code.

Run: `quickshell -p elto-files/trail.qml` (Trail window). `TRAIL_START=computer` opens "This computer" first; `TRAIL_START=/some/folder` opens Trail there. Launchers: `trail.desktop`, `trail-computer.desktop`.

v1 scope: browse folders, open files with xdg-open, sidebar (This computer, Home, Documents, Downloads, Pictures, Trash), breadcrumb, back/forward (also Backspace, Alt+Left/Right), "This computer" with folder shortcuts (item counts) and drive cards (usage bar, percent, Eject for USB drives).

Not in v1: copy, move, delete, rename, tabs, search, network. Those come later through KDE KIO.

`trail-helper.py` reads drives (lsblk + disk usage) and folder item counts as JSON and ejects with udisksctl. Windows are decorated by KWin (Aurorae theme), like the Welcome app. Theme: `themes/soft-paper` plus the user overlay.

Verification: `python3 -m` render check with stubbed Quickshell types in a Qt 6 offscreen run (layout only). Real run under Quickshell and KWin is for the VM.
