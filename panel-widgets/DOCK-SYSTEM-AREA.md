# Dock system area (clock, Settings, status readouts)

Status: **CONCEPT, L1 only.** The QML parses (CI `qmllint`) and nothing else has been run: the panel
smoke does not load the dock, and no screen has shown this yet. VM proof is the implementer's step.

## What was added

Both dock variants (`island` in `DockWindow.qml`, `bar` in `DockBar.qml`) carry the same group.

One `DockSystemArea` row at the right end of the dock: the clock, a Settings entry, and the status
readouts the shell already has data for. It composes the widgets that already live in this directory
instead of reading the services a second time, so each readout keeps one source of truth.

| item | data source | real data | interaction |
| --- | --- | --- | --- |
| Clock | `Clock.qml` -> Quickshell `SystemClock`, minutes precision, `HH:mm` | yes | none |
| Settings | `elto-control.desktop` (`Exec=elto-control`, installed by `session/install.sh`) with the plain `elto-control` command as fallback | yes | click opens ElTo Control |
| Volume | `Volume.qml` -> `Quickshell.Services.Pipewire`, `defaultAudioSink` | yes | click toggles mute, wheel changes 5 % per notch |
| Network | `Network.qml` -> `Quickshell.Networking` (NetworkManager), first connected device | yes | none |
| Battery | `Battery.qml` -> `Quickshell.Services.UPower`, `displayDevice`; hidden when the machine has no battery | yes | none |

All five read live state; none of them is a placeholder. What they are **not**: icons. Every readout is
text in the dock's serif at 13 px, muted ink, because the dock icon style is still open (see
DOCK-ICONS.md) and adding glyphs now would prejudge it.

The four widgets gained one optional property, `pixelSize` (default 20, unchanged for `Panel.qml`), so
the dock can draw them smaller without duplicating them.

## Deliberately not added

- **Bluetooth.** `Bluetooth.qml` exists and reads BlueZ for real (adapter state, connected count, click
  toggles power), but it was not in his list and the dock should not grow without a reason. One line to
  add if he wants it.
- **Media, notifications, app indicators.** No data source in the shell yet; adding them would mean new
  plumbing, not a dock change.
- **A settings icon.** The entry is the word "Settings" in serif italic; the icon sets are on hold.

## Sizing and known limits

- Readout text is 13 px, the Settings pill is 24 px tall, spacing 12 px, one 1 px divider before the
  group. Everything is muted ink except the clock and the Settings word.
- The island grows with its content and has no clipping, so a long window list plus this group can push
  it past the screen edge. That limit is older than this change, but the group makes it easier to hit.
  The bar variant clips its pills, so it does not have the problem.
- Both variants use the same component. The island appends it after the window pills; the bar pins it to
  the right end and the clipped pills area stops short of it (`bar.width - pad - x - (sys.width + 22)`),
  so a long window list never runs under the clock. A 1 px divider sits before it in both.

## VM test plan (for the implementer)

1. Start the session. The island shows, at the right: volume, network, battery (if the machine has one),
   a divider, "Settings", and the clock in `HH:mm`.
2. Watch the clock for two minutes: it advances on the minute.
3. Click "Settings": ElTo Control opens. The dock stays where it is; the log says
   `ELTODOCK open elto-control via ...` and names which route was used.
4. Volume: click the readout, it flips to `vol muted`; click again, it returns. Wheel over it changes the
   percentage by 5 % and the notch drawer's volume row agrees.
5. Network: disconnect the active connection, the readout goes to `net off`; with no NetworkManager
   backend it reads `net n/a`.
6. Battery: on a machine without a battery the readout is absent and leaves no gap.
7. Restart the shell: every readout comes back and the log has no load error.
8. Switch the world (or set the dock option) to `bar`: the strip shows the same group at its right end,
   the clock is inside the screen edge, and opening ten windows clips the pills before the divider
   instead of pushing the clock off screen. Switch back to `island`: the group is unchanged.

Screenshots: `dock-system-area.png` (island, normal), `dock-system-area-muted.png` (volume muted).

## Verification level

- L0 design: this document.
- L1: `qmllint` in CI. That is all; the existing panel smoke loads `shell-spike.qml`, which does not
  include the dock.
- L2 VM and L3 hardware: not reached. Nothing here is proven to work on a real session yet.
