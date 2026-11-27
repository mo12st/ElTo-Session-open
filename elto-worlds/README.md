# ElTo Worlds

One world = one complete theme package: shell, KDE apps, window decoration, icons, cursor,
wallpaper, and (in later phases) login screen, lock screen, boot splash and GRUB menu.
Data-driven: a world is a directory with a `world.json` plus `assets/`. No runtime engine;
each layer is generated to that layer's own mature format.

Approved scope: Phase 1 (user-level layers only). SDDM/lock are Phase 2, Plymouth/GRUB Phase 3.
Everything here is CONCEPT until VM-verified by the implementer.

## Layout of this directory

- `elto-world` - the applier/validator. python3, stdlib only, never executes theme code.
- `world.schema.json` - the format contract (JSON Schema draft 2020-12). `elto-world check`
  implements the same rules with no dependencies.
- `worlds/<name>/world.json` - the nine worlds from the user's concept art: aero, retro95,
  classic, flow, faithful, unix, retroaero, y2k, mono. Palettes are sampled from the art and
  are estimates for the artist to refine. `assets/` are pending the user's exports; the
  validator warns, it does not fail.

## Usage

```
elto-worlds/elto-world check  elto-worlds/worlds/retro95
elto-worlds/elto-world apply  elto-worlds/worlds/retro95            # user-level, reversible
elto-worlds/elto-world apply  elto-worlds/worlds/retro95 --dry-run  # print the plan only
```

`apply` does, in order:

1. Installs the world as a theme package in `~/.config/elto/themes/<name>/theme.json`
   (compatible with `panel-widgets/theme-tool.py`, so the Themes page lists it).
2. Writes the shell overlay `~/.config/elto/theme.json` (same sections `UserTheme.apply`
   writes: name, colors, roles, shape, fonts, plus the world's `layout`). The shell watches
   this file and restyles live. If the world's wallpaper asset exists it is copied to
   `~/.config/elto/wallpapers/` and `options.wallpaper` is set; otherwise the wallpaper is
   left unchanged with a warning.
3. Generates a KDE color scheme in `~/.local/share/color-schemes/` from the world's
   colors/roles (same mapping as `theme/gen_colors.py`, generalized) and applies it with
   `plasma-apply-colorscheme` when available.
4. Sets the icon theme name (`icons.systemTheme`, default breeze) via `kwriteconfig6`.
5. Sets the cursor theme name via `plasma-apply-cursortheme` or `kwriteconfig6`.
6. Generates an Aurorae window-decoration variant from the shipped `aurorae/ElToClassic`
   template into `~/.local/share/aurorae/themes/ElTo<name>/` (palette recolor of the SVGs,
   title text colors, and button side from `layout.windowControls`), selects it in `kwinrc`,
   and asks KWin to reconfigure when qdbus is available.

Files it overwrites are first backed up as `<file>.bak-elto-world`. Every missing tool is a
skip with a reason, never a failure; the step list in the JSON output says exactly what
happened. `install-system` (SDDM, lock, Plymouth, GRUB) is Phase 2/3 and currently refuses
with exit code 2.

## The world format

Everything in a theme.json v1 keeps the same meaning (colors, roles, shape, fonts, icons,
options, notch, dock, drawer). `version: 2` marks the world format. New sections, all optional:

- `layout` - world behavior, not recolor: `bar`, `rail`, `launcher`, `windowControls`,
  `motionProfile`. Declarative: the shell must ignore values it does not implement and fall
  back to its default layout.
- `kde.colorscheme` - generate and apply a `.colors` scheme.
- `kvantum` - deferred until the colorscheme-only look is VM-checked.
- `cursor` - installed theme name now; `custom` (xcursorgen build from SVGs) later.
- `aurorae` - template + frame/title color refs.
- `sddm`, `lock` - greeter `layout` (card-center, card-left, split, dialog-center, terminal,
  pill-center, minimal), background asset and colors. Phase 2.
- `plymouth`, `grub` - boot layers, `enabled: false` until Phase 3 approval. GRUB confirmed
  as the ElTo-OS bootloader.

Color references (`colorRef`) accept a palette token, a role name, or a literal `#hex`.
Assets always live under `assets/` inside the world directory.

## Verification level

- `elto-world check`: PASS on all nine worlds (plus negative tests: bad name, unknown role
  target, unknown layout key, unknown color ref are all rejected).
- `apply`: tested in a sandbox HOME on this repo checkout. Theme package lists in
  `theme-tool.py` (Themes page compatible), overlay/colorscheme/Aurorae outputs inspected:
  SVG recolor, rc text colors and close-left button swap confirmed. Plasma/KWin tool calls
  were skipped in the sandbox (tools absent), so live applying is NOT verified.
- Not VM-tested, not hardware-tested. Missing assets (wallpapers, greeter/boot art) are the
  user's exports and are warnings until then.
