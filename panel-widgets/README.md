# panel-widgets (CONCEPT / SPIKE, not a design)

UNVERIFIED until the implementer's VM run shows it working.

Small QML widgets on Quickshell built-ins only: Clock, Volume (Pipewire), Battery (UPower), Network, Bluetooth. Panel.qml strings them together. No Plasma imports.

Run: `quickshell -p panel-widgets/shell-spike.qml`

Patterns referenced from DankMaterialShell (MIT) only. No GPL code copied (Caelestia, end-4 not used).

Known risk: Pipewire and UPower property names were written from recall, not checked against headers. Network and Bluetooth names were checked against Quickshell master. CI smoke (smoke.sh) only checks that the QML loads.
