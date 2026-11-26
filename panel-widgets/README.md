# panel-widgets (CONCEPT / SPIKE, not a design)

UNVERIFIED until the implementer's VM run shows it working.

Small QML widgets on Quickshell built-ins only: Clock, Volume (Pipewire), Battery (UPower), Network, Bluetooth. Panel.qml strings them together. No Plasma imports.

Run: `quickshell -p panel-widgets/shell-spike.qml`

Patterns referenced from DankMaterialShell (MIT) only. No GPL code copied (Caelestia, end-4 not used).

Known risk: Pipewire and UPower property names were written from recall, not checked against headers. Network and Bluetooth names were checked against Quickshell master. CI smoke (smoke.sh) only checks that the QML loads.

## Animations (UNVERIFIED)

Light, short animations (about 80-180 ms, one easing curve). All timing lives in `palette/elto-palette.json`, section `motion`. Edit it and run `python3 palette/gen.py`. Set `"enabled": false` to turn every animation off (all durations become 0).

- `ElToPill.qml`: taskbar pill. Hover color, press scale, active-window color change.
- `TaskbarPills.qml`: window pills from ToplevelManager. Fade and grow in on open, fade out on close, slide when neighbors move.
- `ElToPopup.qml`: popup container. Short fade plus a few px slide.

Easing only, no blur or shadow effects.
