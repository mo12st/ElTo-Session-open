# ElTo Control — verification record

Honest levels per the governance directive. Nothing here claims more than was done.

## Verified in the sandbox (2026-11-27)

- **Implemented.** All of `elto-control/`: Main, 6 pages, 4 shared controls, 2 singletons,
  i18n.json (en + ar), wrapper script, desktop file, 3 new Lucide (ISC) icons.
- **Syntax-checked.** PySide6 qmllint 6.x over all 13 QML files: zero syntax errors.
  Remaining warnings are the same classes the VM-proven `panel-widgets/customize.qml`
  and `UserTheme.qml` produce under the same linter (singleton members invisible without
  qmldir, Quickshell modules not importable outside the shell). Class-equivalent to
  proven code, not cleaner.
- **i18n.json valid** (`jq`), every key present in both `en` and `ar`.
- **Wrapper script** passes `bash -n`, executable bit set.
- **Binding conditions, statically:** no new service/daemon anywhere (grep-verified:
  the only processes spawned are nmcli/bluetoothctl/wpctl/loginctl/systemctl/uname/sh);
  every page's unavailable branch exists in code; all colors/fonts/radii come from Theme.

## NOT verified (the implementer's VM steps)

- **Not built, not launched, not functionally tested, not session-tested, not VM-tested,
  not hardware-tested.** The sandbox has no Quickshell, no PipeWire/NM/BlueZ session.
- **VM test list:**
  1. `elto-control` opens; sidebar shows 7 pages; deep links `elto-control network` etc.
     open the right page; unknown page falls back to appearance.
  2. **Cross-directory singleton import**: pages use `Theme`/`UserTheme` via
     `import "../panel-widgets"`. If this fails in the real Quickshell build, the whole
     app fails to load — check first. Fallback: add a qmldir to panel-widgets (needs the
     implementer's OK, that directory is theirs).
  3. Appearance behaves exactly like the old Customize window (theme, wallpaper, dock,
     notch, motion write theme.json and restyle the shell live).
  4. Sound: default sink volume/mute live; switching output calls wpctl; with PipeWire
     stopped the page shows the unavailable card.
  5. Network: with NetworkManager stopped the page shows the unavailable card; with it
     running, wifi toggle, rescan, join an open and a secured network, wrong password
     shows the error inline.
  6. Bluetooth: adapter off -> enable; scan finds devices; pair/connect/forget work;
     with bluetooth.service stopped the page still loads (adapter null or disabled
     state, no crash).
  7. Power: battery row on the laptop, no-battery card in the VM; lock/sleep work;
     restart/poweroff/logout ask for confirmation and fire on second click.
  8. About: distro and kernel values real; Guardian button shows "not installed yet".
  9. Language switch: every string flips EN/AR live, layout mirrors in Arabic;
     Arabic renders with Noto Naskh Arabic (fontconfig fallback).
  10. A deliberately broken page (rename a page file) shows the error card while the
      other pages keep working.
  11. Closing the window leaves no process behind (`pgrep quickshell` before/after).

## Known risks, stated

- Quickshell service APIs (Pipewire node listing, Bluetooth device properties such as
  `paired`) are written against the same names the widgets' comments cite from Quickshell
  master. `Network.qml` already warns the installed Quickshell version must match. The VM
  run is the truth; per-page fallbacks (wpctl/nmcli/bluetoothctl) cover action paths.
- AppearancePage keeps customize.qml's manual x/y layout and renders LTR inside an RTL
  window in Arabic. Full RTL mirroring of that grid is a follow-up, not hidden.
- After the Themes PR merges, AppearancePage must be re-synced with the final
  customize.qml if the implementer changed it.

## Re-sync with Themes PR #28 (2026-11-27)

- Rebased onto main 5b6f73f. customize.qml's Appearance content was unchanged by the
  merge (only wrapped in an Item and given a sibling Themes page), so AppearancePage
  stays a faithful port. UserTheme.qml gained apply()/write(); nothing in Control used
  the old internals, no change needed.
- Control gains a seventh sidebar page, "Themes", embedding the implementer's own
  panel-widgets/ThemesPage.qml whole (unnamespaced directory import already present in
  Main.qml). It draws its own header at the same metrics as Control's, so it renders
  pixel-identical to its VM-proven Customize form. Its internal strings remain English
  (implementer-owned file); Arabic for its content is a follow-up with the implementer,
  the sidebar label is localized.
- New VM item 12: themes page inside Control lists themes, New from copy, edit, apply,
  export and install behave exactly as in the Customize window (same component), and
  theme-tool.py resolves (path is relative to panel-widgets/, unaffected by embedding).
