# Notch modes

Overlay keys (`~/.config/elto/theme.json`, `options.*`, live-watched; contract in `elto-worlds/HANDOFF.md`):

| key | values | fallback |
| --- | --- | --- |
| `notchMode` | `show`, `hidden`, `auto-hide` | `show` |
| `notchAutoHideMs` | int 0..10000 | 400 |
| `notchRespectFullscreen` | `true` | off |

Behavior (Notch.qml):
- `show`: unchanged.
- `hidden`: card slides off the top edge, no input region left.
- `auto-hide`: a 5 px hot zone at the top centre (only while tucked away) reveals the notch on pointer entry. It hides `notchAutoHideMs` after the pointer leaves. Each screen reveals on its own.
- `notchRespectFullscreen`: while any window is fullscreen the notch is forced hidden and the hot zone is removed so it never steals the top edge from the app. Fullscreen comes from elto-windowlist state bit 8. The helper reports no screen, so this applies to all screens. The helper only runs when the option is on.
- Keyboard / script fallback, works in every mode (also in hidden and fullscreen): `quickshell ipc call notch reveal` (3 s), `... toggle` (open or close drawer), `... status`. Binding a key to it is left to the session (no global shortcut protocol under KWin in Quickshell).
- The clock is only drawn by the notch, so in `hidden` mode use the IPC fallback or switch back in Control > Appearance > Notch style (Show / Auto-hide / Hidden; Control stays reachable from the dock).

## VM test plan (implementer)

Verification level of this PR: code written, NOT run. No qmllint or Quickshell available where it was written. Everything below is unproven until the VM runs it.

Phasing (user-approved review advice): run Phase A first (show + hidden, steps 1, 2, 4, 6, 9). Edge auto-hide and fullscreen (steps 3, 5, 7, 8) are Phase B, tested and reported separately so a Phase B failure does not block A.
Levels: this PR is L0 (written, not run). Phase A VM pass = L2 for show/hidden only. Do not report auto-hide as proven from Phase A. L3 = hardware, not covered.
Unknown `notchMode` falls back to show and logs `ELTONOTCH unknown options.notchMode ...` as a warning in the session log (step 4 should grep for it). Soft motion off (`options.motion: "off"`) makes the slide instant.

Setup: in the VM session, edit `~/.config/elto/theme.json` (merge into `options`), or use the Control buttons.

1. Default: no `notchMode` key. Notch visible as before. Screenshot.
2. `"notchMode":"hidden"`: notch disappears live, hovering top centre does nothing. `quickshell ipc call notch reveal` shows it for ~3 s. Screenshot hidden and revealed.
3. `"notchMode":"auto-hide"`: notch tucked away. Move pointer to top centre (xdotool-less: use the VM's pointer move): notch slides in, drawer opens on hover as before. Move away: hides after ~400 ms. Then set `"notchAutoHideMs":1500` and confirm the longer delay.
4. `"notchMode":"bogus"` and `"notchAutoHideMs":"x"`: behaves as show / 400, no QML errors in `~/.local/state/elto-session.log`.
5. Fullscreen: `"notchRespectFullscreen":true`, mode `show`. Open Kate, press F11 (fullscreen): notch hides. Leave fullscreen: it returns. With mode `auto-hide`, in fullscreen the top-edge pointer does not reveal it. Check the log for helper errors and that `elto-windowlist` runs only when the option is on (`pgrep elto-windowlist`).
6. Control > Appearance: Notch style shows Show / Auto-hide / Hidden, selected one has the rust border, clicking writes `options.notchMode` to theme.json and the shell reacts live. Check Arabic labels render.
7. If the VM has two outputs: each reveals on its own; fullscreen hides both (known limit).
8. Media card: with `playerctl` playing, hidden mode hides the media card too.
9. `elto-world reset` re-applies world defaults over the three keys; confirm the notch follows.

Known risks to check first: (a) a `WindowList` Item inside the `Scope` (Notch.qml) may need to be moved into a window if Quickshell rejects it; (b) `IpcHandler` needs a Quickshell build with IPC; (c) mask `Region` with a zero-size item.
