# ElTo Worlds

One world = one complete theme package: shell, KDE apps, window decoration, icons, cursor,
wallpaper, and (in later phases) login screen, lock screen, boot splash and GRUB menu.
Data-driven: a world is a directory with a `world.json` plus `assets/`. No runtime engine;
each layer is generated to that layer's own mature format.

Approved scope (user directive, 2026-11-27): the six-step world program - 1) versioned
foundation (schema, defaults vs user overrides, atomic apply), 2) wallpaper sets, 3) notch
modes, 4) dock variants (island + bar, architecture open), 5) sounds, 6) .elworld bundles.
All of it user-level. SDDM/lock stay Phase 2, Plymouth/GRUB Phase 3.
Everything here is CONCEPT until VM-verified by the implementer.

## Layout of this directory

- `elto-world` - the applier/validator. python3, stdlib only, never executes theme code.
- `world.schema.json` - the format contract (JSON Schema draft 2020-12). `elto-world check`
  implements the same rules with no dependencies.
- `worlds/<name>/world.json` - the nine worlds from the user's concept art: aero, retro95,
  classic, flow, faithful, unix, retroaero, y2k, mono; plus meadow, an original early-2000s
  world (glossy rounded sky-blue titlebars, grass-green accents) added from a stub render,
  no concept art yet. Palettes are sampled from the art where it exists and are estimates
  for the artist to refine. `assets/` are pending the user's exports; the validator warns,
  it does not fail.

## Usage

```
elto-worlds/elto-world check  elto-worlds/worlds/retro95
elto-worlds/elto-world apply  elto-worlds/worlds/retro95            # user-level, reversible
elto-worlds/elto-world apply  elto-worlds/worlds/retro95 --dry-run  # print the plan only
elto-worlds/elto-world reset                                       # back to world defaults
elto-worlds/elto-world pack   elto-worlds/worlds/retro95 /tmp/retro95.elworld
elto-worlds/elto-world unpack /tmp/retro95.elworld /tmp/out
```

`apply` runs in two phases. The file phase is staged: every file write goes to a temp name
and is renamed into place, originals are backed up under
`~/.local/state/elto-world/runs/<timestamp>/`, and any failure mid-phase rolls back every
file the run touched. The activation phase (plasma-apply-colorscheme, kwriteconfig6, KWin
reconfigure) is best-effort after the files are safely in place.

`apply` does, in order:

1. Installs the world as a theme package in `~/.config/elto/themes/<name>/theme.json`
   (compatible with `panel-widgets/theme-tool.py`, so the Themes page lists it).
2. Installs the default wallpaper into `~/.config/elto/wallpapers/` (skipped with a warning
   until the user's art lands) and the sound theme into `~/.local/share/sounds/<id>/`
   (freedesktop layout: index.theme + stereo/<event>.wav).
3. Writes the shell overlay `~/.config/elto/theme.json`. World `defaults` fill the managed
   option keys (options.wallpaper/dock/notch/notchMode/notchAutoHideMs/
   notchRespectFullscreen, sounds.enabled); the user's other keys and their overrides of
   managed keys are preserved on a normal apply. `reset` re-applies the world defaults over
   the managed keys (that is the "reset to world defaults" flow) while leaving unrelated
   user keys alone. A `_world` stamp in the overlay records what was applied.
3. Generates a KDE color scheme in `~/.local/share/color-schemes/` from the world's
   colors/roles (same mapping as `theme/gen_colors.py`, generalized) and applies it with
   `plasma-apply-colorscheme` when available.
4. Sets the icon theme name (`icons.systemTheme`, default breeze) via `kwriteconfig6`.
5. Sets the cursor theme name via `plasma-apply-cursortheme` or `kwriteconfig6`.
6. Generates an Aurorae window-decoration variant from the shipped `aurorae/ElToClassic`
   template into `~/.local/share/aurorae/themes/ElTo<name>/` (palette recolor of the SVGs,
   title text colors, and button side from `layout.windowControls`), selects it in `kwinrc`,
   and asks KWin to reconfigure when qdbus is available.

Every missing tool is a skip with a reason, never a failure; the step list in the JSON
output says exactly what happened. `install-system` (SDDM, lock, Plymouth, GRUB) is Phase
2/3 and currently refuses with exit code 2.

## .elworld bundles

`pack` zips a world directory (world.json + assets/ + CREDITS) into a data-only bundle with
a manifest.json (format `elworld/1`: sha256, byte size and license per file). `unpack`
verifies before writing anything: path traversal, absolute paths, symlinks, scripts and
executables, files over 25 MB, bundles over 100 MB, missing licenses and checksum mismatches
are all rejected. There is no install script mechanism and no online store; bundles move by
file sharing only.

### Bundle commands (hardened reader, `bundle.py`)

```
elto-world inspect <file.elworld>              # verify, print license + size per asset, writes nothing
elto-world unpack  <file.elworld> <destdir>    # verify, stage, validate, atomic rename; refuses an existing destdir
elto-world install <file.elworld> [--replace]  # into ~/.local/share/elto/worlds/<id>/; does NOT apply
```

Everything is verified before any byte reaches its final place: safe paths (no `..`, absolute,
backslash, drive letter, duplicate or case-colliding names), regular files only (no symlinks,
no encryption), allowlisted types under `assets/` (scripts, `.desktop`, `.qml`, unknown types
rejected), SVG with scripts/event handlers/external references rejected, a license on every
asset, sha256 and byte counts checked against real bytes (not zip headers), zip-bomb ratio
guard, and the pack limits (25 MB per file, 500 files, 150 MB total). A world is never
overwritten: `install` stops if it exists; `--replace` keeps the old copy as `<id>.bak-<time>`.
References in world.json to assets not in the bundle are warnings (art may be pending),
as in `check`. After install, `elto-world apply ~/.local/share/elto/worlds/<id>` applies it.
Tests: `python3 elto-worlds/tests/test_bundle.py` (24 tests, sandbox only; NOT VM-tested).

## The world format

Everything in a theme.json v1 keeps the same meaning (colors, roles, shape, fonts, icons,
options, notch, dock, drawer). `schema_version: 3` is the current world format (v2 files are
accepted with a warning). New sections, all optional:

- `id` + `schema_version` + `compatible` - stable world identity and the shell/tool
  versions the world was built for.
- `identity` - optional story and signature: what makes the world itself, not a recolor.
- `defaults` - the world's own picks for wallpaper, dock variant, notch mode and sounds.
  Applied to the managed overlay keys; the user can override them and `reset` restores them.
  Unknown or declared-but-unsupported values warn visibly and fall back, never fail.
- `options.wallpapers` - the wallpaper set as `{path, label}` objects under
  `assets/wallpapers/`; `options.wallpaper` stays the active pick.
- `assets` - manifest of the files under `assets/` (path, kind, license; sha256/bytes added
  by `pack`).
- `sounds` - `enabled` default plus `events` mapping event ids to wav assets.

- `layout` - world behavior, not recolor: `bar`, `rail`, `launcher`, `windowControls`,
  `motionProfile`. Declarative: the shell must ignore values it does not implement and fall
  back to its default layout.
- `shape` Trail data contract (signed off by the Trail agent): `bevel`, `glass` (0-1),
  `folderArt`, `cardArt`, `pageLayout`, `iconArt`, `folderView`. Same declarative rule:
  readers ignore unknown values and fall back. Band worlds derive their band colors from
  the world palette (colors/roles), never hardcoded. `colors.folder` names the folder tint
  the file manager uses. Meadow carries the reference set (`folderArt: luna`,
  `cardArt: gloss-band`, `pageLayout: desktop-icons`, `iconArt: gloss`,
  `folderView: details`, `bevel: rounded-gloss`, `glass: 0.4`).
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

## Verification levels

L0 design, L1 sandbox, L2 VM, L3 hardware. Current state:

- L1 `elto-world check`: PASS on all ten worlds at schema v3 (plus negative tests: bad
  name, unknown role target, unknown layout key, unknown color ref are all rejected).
  Unknown vs unsupported option values warn visibly and fall back (unknown dock variant,
  unknown notch mode, unsupported ridge-shelf/hidden-thread concepts all verified).
- L1 `apply`: tested in a sandbox HOME on this repo checkout. Theme package lists in
  `theme-tool.py` (Themes page compatible), overlay/colorscheme/Aurorae outputs inspected:
  SVG recolor, rc text colors and close-left button swap confirmed. Plasma/KWin tool calls
  were skipped in the sandbox (tools absent), so live applying is NOT verified.
- L1 staged apply + rollback: tested in the sandbox by forcing a failure mid-apply; every
  file the run wrote was removed or restored from backup.
- L1 `reset`: tested in the sandbox; world defaults restored over managed keys, unrelated
  user keys preserved.
- L1 `pack`/`unpack`: round-trip tested in the sandbox; traversal, oversized and
  checksum-tampered bundles are rejected.
- L0 only: the shell side of notch modes, the dock `bar` variant, sound playback and the
  wallpaper picker is a spec for the implementer (HANDOFF.md), not implemented.
- No L2 (VM) or L3 (hardware) verification yet. Missing assets (wallpapers, sounds,
  greeter/boot art) are the user's exports and are warnings until then.

## Later (approved, not scheduled)

- World preview in the Themes page.
- Safe uninstall of a world (restore what apply changed, not just reset).
- Upgrade/rollback tests for worlds across schema versions.
- Accessibility: reduced motion and mute honored world-wide.
