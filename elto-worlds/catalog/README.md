# ElTo Worlds catalog

`catalog.json` is the store-facing index of every world in this repo. The
Theme Manager (and the web store, same catalog) reads it to list worlds and
their parts. It is generated, never edited by hand:

    python3 elto-worlds/catalog/build-catalog.py        # rewrite catalog.json
    python3 elto-worlds/catalog/build-catalog.py --check  # CI: is it fresh?
    python3 elto-worlds/tests/test_catalog.py           # tests

The generator is deterministic: no timestamps, sorted keys, so a PR diff
shows exactly what a world change does to the catalog.

## What an entry carries

Per world, straight from its `world.json`:

- identity: `id`, `label`, `version`, `story`, `signature`, `description`
- provenance: `author`, `license`, `assetsLicense`
- `colors` and `roles` verbatim (the manager renders swatches from these)
- `parts`: which part categories the world ships data for (window frame,
  color scheme, icons, cursor, wallpapers, sounds, greeter, lock, boot,
  widgets), derived from the world.json keys that are present
- `defaults`: wallpaper, dock (`island` or `bar`, PR #58 contract), sounds
- `dockLook`: the PR #58 per-world dock tokens, passed through when the
  world sets them; absent means the shared island look
- `kind`: always `data` for repo worlds

## kind: data vs code

Repo worlds are data-only (option-1 decision): nothing executable, ever. The
generator validates before cataloguing (required keys, slug id matching the
directory, 6-digit `#rrggbb` colors, roles pointing at real colors, dock in
`island|bar`), so a world that fails never gets labeled `data`.

KDE Store items that ship code are not catalogued here. The store backend
adds them at read time as `kind: "code"`: shown greyed, source link only,
never installed. Functions and KWin scripts stay listing-only with their
GitHub link until the user decides the code policy.

## KDE Store import

The backend (separate PR) talks to the KDE Store read-only over OCS and maps
data-only items into catalog entries of the matching category, converted on
install per the data-only bundle spec. The catalog on disk lists only what
this repo ships.

## File manager category

The store has a `filemanager` category (user-approved design): each world
ships its Trail file manager look as data parts (sidebar, toolbar, view
modes, drive tiles). The per-world `filemanager` block is NOT emitted yet -
its schema shape awaits the user's decision. `build-catalog.py` carries it
behind `INCLUDE_FILEMANAGER`, default off; the category is marked
`pending-schema` until then.
