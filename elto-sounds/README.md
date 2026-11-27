# ElTo sounds (CONCEPT)

Optional, quiet sound theme for real shell events only: notification, app drawer open/close, lock/unlock, shell start.
Off by default. Disable any time: `elto-sounds disable` or `options.sounds.enabled=false`.

- Format: freedesktop sound-theme layout (`index.theme`, `stereo/<id>.wav`). Standard ids where the spec has one
  (`message-new-instant`, `desktop-login`); `elto-*` ids for events the spec lacks. WAV so Qt SoundEffect plays it everywhere.
  Not verified against the spec text by this PR; layout follows the common sound-theme-freedesktop structure.
- No process per event: `Sound.qml` + `SoundBank.qml` use QtMultimedia SoundEffect inside Quickshell. If QtMultimedia
  is missing the shell runs silent. Needs `qt6-multimedia` at runtime (not confirmed installed on the image).
- `elto-sounds install|uninstall|enable|disable|status`, user level, no root.
- Settings: `options.sounds = { enabled, theme, volume }` in the user overlay `~/.config/elto/theme.json`.
  Worlds can carry `options.sounds.theme` once the foundation schema lists it (needs the Theme/World agent's approval).
- Hooks into shell files are proposed in `hooks/README.md`, not applied (other tracks' files).
- Audio assets: none shipped. Needed list and license rules in `ASSETS.md`.

## Verification level
- `tests/test-install.sh`: PASS in a sandbox HOME (install, enable, disable, uninstall; uses generated test tones as fixtures).
- Not verified: QML loads under Quickshell, event fire, audio. VM can check install and `ELTOSOUND fire` log lines; audible quality is hardware-only.
