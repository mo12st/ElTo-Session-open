# ElTo Welcome — verification status (honest levels per the governance directive)

## Verified
- `welcome/elto-welcome-autostart.sh` passes `bash -n`.
- Every QML pattern used is copied from files already exercised in the repo's CI/VM
  spike boots: `FloatingWindow` window (`customize.qml`), `FileView` JSON load and
  merge + `Quickshell.shellPath` (`Theme.qml`), `Process` sh -c file write
  (`UserTheme.qml`), `Quickshell.env`, `LIcon` usage.
- Runtime asset paths checked against `session/install.sh`'s installed layout:
  `../themes/soft-paper/theme.json`, `../wallpapers/golden-valley.png`,
  `../lock/assets/snail.png`, `../panel-widgets/customize.qml` and
  `../icons/lucide/*.svg` all exist in the repo and land under
  `/opt/elto-session/` after install.
- Tour text claims checked against the code: the notch holds clock/media and pulls
  down to controls (`Notch.qml`), the drawer opens "from the snail in the notch"
  and has search (`AppDrawer.qml`), the dock shows pinned apps and running-window
  pills (`Dock.qml`, `TaskbarPills.qml`), Customize is pinned in the dock
  (`themes/soft-paper/theme.json`).

## NOT verified (no QML engine in this sandbox)
- `welcome.qml` was never parsed by a QML engine, never launched, never VM-tested.
  A typo-level syntax error is possible.
- `import "../panel-widgets" as Shell` (relative directory import for `LIcon`) is
  standard QML but unverified under Quickshell's loader. If it fails, fallback:
  copy `LIcon.qml` into `welcome/` (20 lines) and drop the import.
- `XDG_SESSION_DESKTOP=ElTo` under SDDM (from `DesktopNames=ElTo` in
  `session/elto.desktop`) is expected but unconfirmed; the guard degrades to the
  marker check alone if it is unset.

## VM test list (for the implementer)
1. Apply the install wiring from `welcome/README.md`, boot the ElTo VM, log in via SDDM.
2. First login: Welcome appears, styled (cream paper, serif headline, banner image,
   snail). Screenshot each of the 4 pages.
3. Next/Back/dots, Esc and "Skip the tour" all work; keyboard-only navigation works.
4. "Open Customize" opens the Customize window.
5. "Start using ElTo" closes Welcome and writes
   `~/.local/state/elto/welcome-v1.done` (check content: JSON with version 1).
6. Log out, log in again: Welcome does NOT reappear. Delete the marker, log in: it
   appears. Launch "Welcome" from the app drawer: it opens on demand.
7. Confirm `XDG_SESSION_DESKTOP` value inside the session (adjust the guard if it
   is not `ElTo`).
8. With `"motion": "off"` in the user theme overlay: no animations.
