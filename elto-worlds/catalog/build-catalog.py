#!/usr/bin/env python3
"""Build elto-worlds/catalog/catalog.json from the worlds in this repo.

Stdlib only, deterministic: the same worlds produce byte-identical output, so
a PR diff shows exactly what changed. Validates every world before it enters
the catalog (the same base rules theme-tool.py installs by: name, 6-digit
#rrggbb colors, roles that point at real colors, license fields).

Every entry is flagged kind: "data". Repo worlds are data-only by the
option-1 decision (no scripts, no QML, no executables); a world carrying an
executable payload would fail validation here, so nothing else can ever be
labeled "data" by mistake. KDE Store items that ship code are added by the
store backend (PR 2) as kind: "code", greyed, source link only - never by
this generator.

The filemanager block (per-world Trail look parts) is NOT emitted yet:
its schema shape awaits the user's decision. Set INCLUDE_FILEMANAGER = True
only after that lands; the flag defaults off.

Run from anywhere:  python3 elto-worlds/catalog/build-catalog.py [--check]
  --check   regenerate in memory and exit 1 if catalog.json on disk differs
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORLDS = os.path.join(HERE, "..", "worlds")
OUT = os.path.join(HERE, "catalog.json")

INCLUDE_FILEMANAGER = False  # pending user's schema decision

HEX6 = re.compile(r"^#[0-9a-fA-F]{6}$")
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")

REQUIRED = ("name", "label", "id", "version", "schema_version",
            "colors", "roles", "author", "license", "assetsLicense")

# Part categories a world can ship data for, mapped from the world.json keys
# that carry them. Greeter/lock/boot are rendered by built-in ElTo components
# from this data (option 1); the catalog just records what each world has.
PART_KEYS = (
    ("window-frame", "aurorae"),
    ("color-scheme", "colors"),
    ("icons", "icons"),
    ("cursor", "cursor"),
    ("wallpapers", "options.wallpapers"),
    ("sounds", "sounds"),
    ("greeter", "sddm"),
    ("lock", "lock"),
    ("boot", "plymouth"),
    ("boot-menu", "grub"),
    ("widgets", "kvantum"),
)

CATEGORIES = [
    {"id": "worlds", "label": "Worlds", "source": "elto"},
    {"id": "window-frame", "label": "Window frames", "source": "kde-import"},
    {"id": "color-scheme", "label": "Color schemes", "source": "kde-import"},
    {"id": "icons", "label": "Icons", "source": "kde-import"},
    {"id": "cursor", "label": "Cursors", "source": "kde-import"},
    {"id": "wallpapers", "label": "Wallpapers", "source": "kde-import"},
    {"id": "sounds", "label": "Sounds", "source": "kde-import"},
    {"id": "greeter", "label": "Greeter", "source": "kde-import"},
    {"id": "boot", "label": "Boot and splash", "source": "kde-import"},
    {"id": "animations", "label": "Animations", "source": "kde-import"},
    # Store category approved by the user (Trail file manager looks as data
    # parts). No per-world data ships until the filemanager schema block is
    # decided; see INCLUDE_FILEMANAGER above.
    {"id": "filemanager", "label": "File manager", "source": "elto",
     "status": "pending-schema"},
]


class CatalogError(Exception):
    pass


def _get(world, dotted):
    cur = world
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def _present(value):
    if value is None or value is False:
        return False
    if isinstance(value, (dict, list, str)) and not value:
        return False
    return True


def validate_world(world, dirname):
    errors = []
    for key in REQUIRED:
        if not _present(world.get(key)):
            errors.append("missing or empty required key: %s" % key)
    wid = world.get("id", "")
    if not SLUG.match(wid):
        errors.append("id %r is not a slug" % wid)
    if wid != dirname:
        errors.append("id %r does not match directory %r" % (wid, dirname))
    if world.get("name") != wid:
        errors.append("name %r differs from id %r" % (world.get("name"), wid))
    colors = world.get("colors", {})
    if isinstance(colors, dict):
        for cname, cval in colors.items():
            if not (isinstance(cval, str) and HEX6.match(cval)):
                errors.append("color %r is not 6-digit #rrggbb: %r" % (cname, cval))
    roles = world.get("roles", {})
    if isinstance(roles, dict):
        for rname, rval in roles.items():
            if rval not in colors:
                errors.append("role %r points at unknown color %r" % (rname, rval))
    dock = _get(world, "defaults.dock")
    if dock is not None and dock not in ("island", "bar"):
        # HANDOFF section 2 (PR #58): unknown dock values fall back to island
        # with a warning; the catalog records them but flags the warning.
        errors.append("defaults.dock %r not in island|bar (shell falls back to island)" % dock)
    if INCLUDE_FILEMANAGER and not _present(world.get("filemanager")):
        errors.append("filemanager block required by flag but absent")
    return errors


def catalog_entry(world, dirname):
    identity = world.get("identity", {}) if isinstance(world.get("identity"), dict) else {}
    parts = sorted(pid for pid, key in PART_KEYS if _present(_get(world, key)))
    entry = {
        "id": world["id"],
        "label": world["label"],
        "version": world["version"],
        "schema_version": world["schema_version"],
        "kind": "data",
        "category": "worlds",
        "story": identity.get("story", ""),
        "signature": identity.get("signature", ""),
        "description": world.get("description", ""),
        "author": world["author"],
        "license": world["license"],
        "assetsLicense": world["assetsLicense"],
        "colors": world["colors"],
        "roles": world["roles"],
        "parts": parts,
        "defaults": {
            "wallpaper": _get(world, "defaults.wallpaper"),
            "dock": _get(world, "defaults.dock") or "island",
            "sounds": bool(_get(world, "defaults.sounds")),
        },
        "source": "worlds/%s/world.json" % dirname,
    }
    dock_look = _get(world, "options.dock")
    # PR #58 dock.look tokens live under options.dock in world.json once a
    # world adopts them; pass them through verbatim, absent means island look.
    if isinstance(dock_look, dict) and dock_look:
        entry["dockLook"] = dock_look
    if INCLUDE_FILEMANAGER and _present(world.get("filemanager")):
        entry["filemanager"] = world["filemanager"]
    return entry


def build():
    errors = []
    worlds = []
    for dirname in sorted(os.listdir(WORLDS)):
        wjson = os.path.join(WORLDS, dirname, "world.json")
        if not os.path.isfile(wjson):
            continue
        try:
            with open(wjson) as f:
                world = json.load(f)
        except (ValueError, OSError) as e:
            errors.append("%s: unreadable world.json: %s" % (dirname, e))
            continue
        werrors = validate_world(world, dirname)
        errors.extend("%s: %s" % (dirname, e) for e in werrors)
        if not werrors:
            worlds.append(catalog_entry(world, dirname))
    if errors:
        raise CatalogError("\n".join(errors))
    return {
        "format": "eltocatalog/1",
        "source": "elto-worlds/worlds/*/world.json",
        "generatedBy": "build-catalog.py (deterministic; no timestamps)",
        "categories": CATEGORIES,
        "worlds": worlds,
    }


def render(catalog):
    return json.dumps(catalog, indent=2, sort_keys=True) + "\n"


def main():
    catalog = build()
    text = render(catalog)
    if "--check" in sys.argv:
        try:
            with open(OUT) as f:
                current = f.read()
        except OSError:
            current = None
        if current != text:
            print("catalog.json is stale; run build-catalog.py", file=sys.stderr)
            return 1
        print("catalog.json is up to date")
        return 0
    with open(OUT, "w") as f:
        f.write(text)
    print("wrote %s: %d worlds, %d categories" % (OUT, len(catalog["worlds"]), len(catalog["categories"])))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except CatalogError as e:
        print("catalog build failed:\n%s" % e, file=sys.stderr)
        sys.exit(1)
