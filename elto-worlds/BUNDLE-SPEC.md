# .elworld bundle spec (data-only)

Status: spec for format `elworld/1`. Implemented and sandbox-tested (L1) by `pack` (#36) and
`bundle.py` (#40). Not VM-tested. Items marked LATER are not built and not approved.

## Rule
A bundle is data. It never contains code and nothing in it is executed. SDDM, lock screen and
Plymouth rendering are built into ElTo as fixed code; a bundle only supplies the values and
images those fixed renderers read. No QML, scripts, desktop files, or install hooks in a bundle
(user decision, 2026-11-28).

## Container
Zip file, extension `.elworld`. Top level, nothing else allowed:

| Path | Required | Meaning |
|---|---|---|
| `manifest.json` | yes | `format: "elworld/1"`, `world` (= world id), `label`, `schema_version`, `files[]` of `{path, sha256, bytes, license}` for every asset |
| `world.json` | yes | the world (schema in `world.schema.json`), max 1 MB |
| `CREDITS` | no | human-readable author/license/source lines |
| `preview.png` / `.jpg` / `.webp` | no | listing preview, one file |
| `assets/**` | no | everything the world references, by relative path |

Allowed asset types: png, jpg, jpeg, webp, svg, wav, ogg, flac, json, txt, md, theme, ttf, otf.
Rejected anywhere: scripts, executables, `.desktop`, `.qml`, unknown types.

## What each layer reads from a bundle
| Layer | world.json section | Assets | Applied by | Level today |
|---|---|---|---|---|
| Shell look | colors, roles, shape, fonts, icons, layout | none | `elto-world apply` (user) | VM-verified apply (#34) |
| Wallpapers | `options.wallpapers[]` of `{path, label}` under `assets/wallpapers/` (plain strings warn, fall back) | images | apply (user) | L1 |
| Dock / notch | `defaults.dock`, `defaults.notchMode`, ... | none | apply (user) | L1 |
| Sounds | `sounds.events` event -> `assets/sounds/<event>.wav` | wav | apply (user), `~/.local/share/sounds/<id>/` | L1, wav only (ogg/flac allowed in a bundle but not installed yet) |
| KDE colors, cursor name, Aurorae | `kde`, `cursor`, `aurorae` | none | apply (user) | L1 |
| SDDM | `sddm`: theme, layout, background, backgroundColor, accentColor | background image | built-in SDDM theme, privileged step | Phase 2, not built |
| Lock screen | `lock`: layout, background, colors | background image | built-in lock UI | Phase 2, not built |
| Plymouth | `plymouth`: enabled, background, snail, spinnerFrames | images | built-in Plymouth theme, privileged step | Phase 3, off by default |
| GRUB | `grub`: enabled, background, font, colors | image | privileged step | Phase 3, off by default |
| Trail | none yet | none | none | needs a schema section from the Theme agent |
Layout names (`sddm.layout`, `lock.layout`) must be ones the built-in renderer knows; an unknown
value warns visibly and falls back to the default layout.

## Verification before anything is written (implemented)
1. Zip opens; at most 500 files; each file at most 25 MB; 150 MB uncompressed total; per-file
   compression ratio guard.
2. Every path safe: no `..`, absolute, backslash, drive letter, empty part, duplicate, or names
   that differ only by case; regular files only (no symlinks); no encrypted entries.
3. Only the paths in the table above; asset types on the allowlist; SVG without script, event
   handlers, or external references.
4. `manifest.json` format is `elworld/1`; world id matches `world.json`; every asset is listed with
   sha256, byte count and a license; every listed file exists; no unlisted asset. Hashes and counts
   are checked against the real bytes, not zip headers.
5. `world.json` references that point outside `assets/` or use unsafe paths are rejected;
   references to assets not in the bundle are warnings (art may be pending).

## Install rules (implemented)
- `elto-world inspect` verifies and prints, writes nothing.
- `elto-world install` verifies, extracts to a staging dir, runs the world validator, then renames
  atomically to `~/.local/share/elto/worlds/<id>/`. Failure leaves nothing behind.
- An installed world is never overwritten. `--replace` moves the old copy to `<id>.bak-<time>`; it
  is never deleted. Install does not apply; apply is a separate step.
- No network access, no store, no scripts at any point.

## Repo split
Git: code, schema, world manifests, small previews. Bundles: wallpapers, sounds, large images.
Built bundles are release artifacts, not committed.

## LATER (not approved, not built)
- Signing or publisher identity, and a trust prompt for unsigned bundles.
- `version` per world and a `compatible` range check at install; upgrade and rollback commands.
- `uninstall` (move to backup, never delete) and a preview in `inspect`.
- Privileged helper for SDDM, Plymouth and GRUB: a fixed audited action that accepts only
  validated bundle values and asks the user to confirm. Needs approval before design or build.
- Theme Manager app and store.
- Accessibility defaults per world (reduced motion, mute).
- Trail data once the schema has a section.
