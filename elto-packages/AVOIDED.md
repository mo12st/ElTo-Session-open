# ElTo packages: avoided on purpose

ElTo's architecture is KWin + Quickshell with **no Plasma Shell** (repo
README). The packages below are excluded because they install the Plasma
Shell itself, depend on it, or duplicate what the ElTo shell already does.
Dependency facts below come from the live Arch package metadata
(archlinux.org package API), checked 2026-11-27, Plasma 6.8.3.

## Pulls in Plasma Shell (plasma-workspace / plasmashell)

| Package | Why avoided |
|---|---|
| `plasma` (group) / `plasma-meta` | The full Plasma desktop, including `plasma-workspace` (ships `/usr/bin/plasmashell`), `plasma-desktop`, krunner, baloo, Discover. Contradicts the core architecture. |
| `plasma-workspace` | The Plasma Shell itself. Only pulled in transitively here; never installed directly. |
| `plasma-desktop` | Plasma desktop shell settings/applets; part of the Plasma desktop, not of ElTo. |
| `xdg-desktop-portal-kde` | Hard-depends on `plasma-workspace` (verified). Replaced by `xdg-desktop-portal` + `xdg-desktop-portal-gtk`. Cost: no KDE screen-sharing / remote-desktop portal. If screen sharing becomes a requirement, this trade-off needs the owner's decision, not a silent dependency change. |
| `plasma-nm` | Network applet; depends on `plasma-workspace`. ElTo has its own Network widget (`Quickshell.Networking`). |
| `powerdevil` | Power management daemon; depends on `plasma-workspace`. Brightness on real hardware: `brightnessctl` (optional line in 20-services). |
| `discover` | Plasma software center; Plasma-tied UI, out of scope. Package management stays `pacman`. |
| `kscreen` | Plasma display configuration; pulls Plasma KCMs. Display setup is KWin config territory for now. |

## Duplicates an ElTo shell function

| Package | Why avoided |
|---|---|
| `bluedevil` | Plasma Bluetooth applet (depends on `libplasma`; its UI is plasmoids for Plasma Shell). ElTo has its own Bluetooth widget on `Quickshell.Bluetooth` + `bluez`. |
| `plasma-pa` | Plasma volume applet. ElTo has its own Volume widget on `Quickshell.Services.Pipewire`. |
| `network-manager-applet` | GTK tray applet; duplicates the Network widget. |

## Kept despite the plasma-* name (verified clean)

These sound like Plasma but do **not** depend on `plasma-workspace` or
`libplasma`, and are in the VM-proven boot lists:

- `plasma-integration` (Qt platform theme, needed for `QT_QPA_PLATFORMTHEME=kde`)
- `plasma5support` (KF6 compatibility engines; exact consumer untraced, see 10-session)
- `plasma-wayland-protocols` (build-time protocol XML only)

`kscreenlocker` depends on the `libplasma` **library** but not on
`plasma-workspace`; it never starts plasmashell and is the lock backend the
ElTo lock QML plugs into.

## Other deliberate exclusions

- **Proprietary NVIDIA driver (`nvidia`)**: free-packages-only rule. `mesa`
  covers Intel/AMD/virtio. Real NVIDIA hardware support is an owner decision.
- **Flatpak/Snap**: not part of the current milestone.
- **`cups` (printing)**: out of the current scope; can be added later without
  touching the session.
