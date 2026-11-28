# ElTo Worlds manager backend

`store.py` serves the Theme Manager UI (separate PR). User session only, no
root, no execution of third-party content.

- `load_repo_catalog()` / `list_worlds()` - the repo catalog (PR 1).
- `Store.kde_listing(category)` - KDE Store read-only over OCS, cached;
  when the store is down the listing falls back to cache marked `stale`,
  and with no cache it fails honestly. Category ids verified against the
  live API on 2026-11-28.
- `Store.install_kde(entry)` - data items only: download, sha256 pinned per
  version, archive scanned under the bundle.py data-only rules (no scripts,
  no traversal, inert-.desktop exception, SVG sanitize, size and zip-bomb
  guards), staging then atomic rename, registry update. `kind=code` items
  (SDDM QML, splashscreens, KWin scripts/effects) are refused before any
  download - they list greyed with a source link.
- `Store.list_installed()` / `set_enabled()` / `remove()` - the local
  registry under `$XDG_DATA_HOME/elto/worlds`. System paths belong to the
  polkit helper (separate PR); this module never touches them.
- `list_functions()` - GitHub functions (bars, widgets, launchers,
  notifications), listing-only with links. There is no install path.

Tests: `python3 elto-worlds/tests/test_store.py` (no network; a fake
fetcher serves fixture XML and archives).
