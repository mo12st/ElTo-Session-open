# ElTo Control

The unified center for system and session settings ("مركز موحد للتحكم في إعدادات النظام
والجلسة"). One Quickshell window, one style, six pages. Approved Phase-1 scope: Appearance,
Sound, Network, Bluetooth, Power and session, About. Display is deferred (no mature
non-Plasma display UI exists; needs the owner's own decision).

Run from the repo root (concept):

    ELTO_ROOT=$PWD ./elto-control/elto-control            # opens Appearance
    ELTO_ROOT=$PWD ./elto-control/elto-control network    # deep link

Installed layout (done by the implementer's `session/install.sh`, NOT by this track):

    /opt/elto-session/elto-control/        this directory
    /usr/local/bin/elto-control            the wrapper script
    /usr/share/applications/elto-control.desktop

The implementer also retires `session/elto-customize.desktop` and
`panel-widgets/customize.qml` once this merges (the rename to "ElTo Control" was
approved); AppearancePage.qml already carries everything customize.qml did.

## Deep-link contract

`elto-control <page>` with page in `appearance sound network bluetooth power about`.
Unknown pages fall back to appearance. Welcome and Guardian open pages this way.

## How it meets the three binding conditions

1. **Existing system interfaces and services only; no new daemon.**
   Each page maps 1:1 to a backend that is already in the package lists and already used
   by a shell widget:

   | Page | Backend | How |
   |---|---|---|
   | Appearance | `~/.config/elto/theme.json` via `UserTheme` | existing watched-JSON mechanism |
   | Sound | PipeWire | `Quickshell.Services.Pipewire` (same as `Volume.qml`), `wpctl set-default` |
   | Network | NetworkManager | `Quickshell.Networking` (same as `Network.qml`), `nmcli` actions |
   | Bluetooth | BlueZ | `Quickshell.Bluetooth` (same as `Bluetooth.qml`), `bluetoothctl` actions |
   | Power/session | UPower + logind | `Quickshell.Services.UPower` (same as `Battery.qml`), `loginctl`/`systemctl` |
   | About | files every Linux has | `/etc/os-release`, `uname` |

   Control stores one small file of its own, `~/.config/elto/control.json` (language),
   through the same write pattern as `UserTheme.qml`. Privileged operations use the
   already-shipped `polkit-kde-agent`. The app exits when closed; nothing runs in the
   background.

2. **One unified design and interaction style.** Every page is built from the same three
   controls (`ElRow`, `ElToggle`, `ElButton`) plus the shell's `Theme` tokens (colors,
   radii, fonts from the active World). Arabic and English from day one: `i18n.json`,
   live language switch in the sidebar, RTL mirroring. No hex colors in page code.

3. **Unavailable services show state, not fake settings.** Every page has an explicit
   unavailable branch: no PipeWire/sink, NetworkManager down, no Bluetooth adapter, no
   battery, missing `elto-guardian` binary, or a page that fails to load each render a
   clear message card instead of dead controls. Action failures surface the tool's
   stderr inline.

## Notes for the implementer (VM test)

- `Main.qml` and every page import `Theme`/`UserTheme` from `../panel-widgets` as a
  directory import. This is the one mechanism the sandbox cannot prove; confirm it
  resolves in the real Quickshell build (see VERIFICATION.md).
- Icons: `appearance/sound/network` reuse `icons/lucide/`; `bluetooth/power/info` are
  new Lucide (ISC) SVGs shipped locally in `elto-control/icons/` to avoid touching the
  shell's icon directory. Move them to `icons/lucide/` later if the owner wants one set.
- Desktop icon reuses `elto-customize.svg`; a dedicated icon is polish, not scope.
- AppearancePage keeps customize.qml's manual x/y layout (working code, not rewritten);
  it renders LTR inside an RTL window. Full RTL mirroring of that grid is a follow-up.
- Arabic glyphs fall back to Noto Naskh Arabic via fontconfig (`noto-fonts` in 30-fonts).
