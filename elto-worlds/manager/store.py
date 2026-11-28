#!/usr/bin/env python3
"""ElTo Worlds store backend (user session, no root).

Stdlib only. Serves the Theme Manager (PR 3):

- reads the repo catalog (catalog.json, PR 1) for ElTo worlds
- lists KDE Store categories read-only over the public OCS API, with a stale
  cache fallback so the catalog degrades gracefully when the store is down
- imports KDE DATA items: download -> checksum (pinned per version) ->
  archive scan (the bundle.py rules: no scripts, no traversal, SVG sanitize,
  size and zip-bomb guards) -> staging -> atomic rename -> registry
- KDE items that ship code are listed greyed (kind "code") and never import
- Functions (bars, widgets, ...) are listing-only from functions.json with
  their upstream links; there is no install path for them
- enable/disable/remove work on the registry; system paths are the polkit
  helper's job (PR 4), this module never touches them

Nothing here executes third-party content. Archives are only ever read.

OCS category ids verified against the live API (api.opendesktop.org
/ocs/v1/content/categories) on 2026-11-28.
"""
import hashlib
import io
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import bundle  # elto-worlds/bundle.py: shared data-only rules

OCS_BASE = os.environ.get("ELTO_OCS_BASE", "https://api.opendesktop.org/ocs/v1")
OCS_UA = "elto-worlds-store/1"
MAX_DOWNLOAD = bundle.MAX_BYTES          # 150 MB
MAX_LIST_XML = 8 * 1024 * 1024
CACHE_TTL = 3600                         # seconds a live listing is fresh

CATALOG_JSON = os.path.join(HERE, "..", "catalog", "catalog.json")
FUNCTIONS_JSON = os.path.join(HERE, "functions.json")

# ElTo category -> (ocs id, store label, kind). kind "data" still gets the
# full archive scan after download; kind "code" is listing-only, greyed.
KDE_CATEGORIES = {
    "window-frame": [(114, "Plasma Window Decorations", "data"),
                     (717, "Plasma 6 Window Decorations", "data")],
    "color-scheme": [(112, "Plasma Color Schemes", "data")],
    "icons":        [(132, "Full Icon Themes", "data")],
    "cursor":       [(107, "Cursors", "data")],
    "wallpapers":   [(158, "Art (Images)", "data")],
    "sounds":       [(316, "System Sounds", "data")],
    "widgets":      [(123, "Kvantum", "data")],
    "boot-menu":    [(109, "GRUB Themes", "data")],
    # Code-shipping below: shown greyed, source link only, never imported.
    "greeter":      [(101, "SDDM Login Themes", "code")],
    "boot":         [(488, "Plasma Splashscreens", "code"),
                     (716, "Plasma 6 Splashscreens", "code"),
                     (108, "Plymouth Themes", "code")],
    "animations":   [(209, "KWin Effects", "code"),
                     (210, "KWin Scripts", "code"),
                     (719, "KWin Effects (Plasma 6)", "code"),
                     (720, "KWin Scripts (Plasma 6)", "code")],
}

CODE_EXTS = bundle.SCRIPT_EXT  # scripts, qml, binaries, .desktop with Exec
# inert .desktop (no Exec/TryExec) is the one allowed exception, option 1
EXEC_LINE = re.compile(rb"^\s*(?:Try)?Exec\s*=", re.M)


class StoreError(Exception):
    pass


def default_root():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "elto", "worlds")


def fetch_url(url, limit=MAX_DOWNLOAD, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": OCS_UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        out = io.BytesIO()
        left = limit + 1
        while left > 0:
            chunk = resp.read(min(65536, left))
            if not chunk:
                break
            out.write(chunk)
            left -= len(chunk)
        data = out.getvalue()
    if len(data) > limit:
        raise StoreError("download exceeds %d bytes" % limit)
    return data


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------- catalog

def load_repo_catalog(path=CATALOG_JSON):
    with open(path) as f:
        return json.load(f)


def list_worlds(catalog=None):
    catalog = catalog or load_repo_catalog()
    return catalog["worlds"]


def list_functions(path=FUNCTIONS_JSON):
    """Listing-only GitHub functions: no install path, link out."""
    try:
        with open(path) as f:
            items = json.load(f)
    except OSError:
        return []
    for it in items:
        it["kind"] = "code"
        it["listingOnly"] = True
    return items


# ---------------------------------------------------------------- OCS

def _text(elem, tag, default=""):
    child = elem.find(tag)
    return (child.text or default).strip() if child is not None and child.text else default


def parse_content_list(xml_bytes):
    if len(xml_bytes) > MAX_LIST_XML:
        raise StoreError("OCS listing too large")
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as e:
        raise StoreError("bad OCS listing: %s" % e)
    items = []
    for c in root.iter("content"):
        entry = {
            "id": _text(c, "id"),
            "title": _text(c, "name"),
            "summary": _text(c, "summary"),
            "version": _text(c, "version"),
            "author": _text(c, "personid"),
            "license": _text(c, "license"),
            "score": _text(c, "score"),
            "downloads": _text(c, "downloads"),
            "preview": _text(c, "preview1"),
            "detailPage": _text(c, "detailpage"),
            "files": [],
        }
        for i in range(1, 5):
            link = _text(c, "downloadlink%d" % i)
            if link:
                entry["files"].append({
                    "url": link,
                    "name": _text(c, "downloadname%d" % i),
                    "filetype": _text(c, "downloadfiletype%d" % i),
                    "size_kb": _text(c, "downloadsize%d" % i),
                })
        if entry["id"] and entry["title"]:
            items.append(entry)
    return items


class Store:
    def __init__(self, root=None, fetcher=fetch_url):
        self.root = root or default_root()
        self.fetcher = fetcher
        for sub in ("cache", "cache/ocs", "imports", "tmp"):
            os.makedirs(os.path.join(self.root, sub), exist_ok=True)

    # -- registry --
    def _registry_path(self):
        return os.path.join(self.root, "installed.json")

    def list_installed(self):
        try:
            with open(self._registry_path()) as f:
                return json.load(f)["items"]
        except (OSError, ValueError, KeyError):
            return []

    def _save_registry(self, items):
        tmp = self._registry_path() + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"format": "eltoinstalled/1", "items": items}, f, indent=2, sort_keys=True)
        os.replace(tmp, self._registry_path())

    # -- KDE listing (read-only, cached) --
    def _ocs_cache(self, ocs_id):
        return os.path.join(self.root, "cache", "ocs", "%d.json" % ocs_id)

    def kde_listing(self, category, fresh_after=CACHE_TTL):
        """List a KDE category read-only. Falls back to a stale cache with
        stale=True when the store is unreachable - graceful, honest."""
        if category not in KDE_CATEGORIES:
            raise StoreError("unknown KDE category %r" % category)
        out = []
        for ocs_id, label, hint in KDE_CATEGORIES[category]:
            cache = self._ocs_cache(ocs_id)
            items, stale = None, False
            try:
                xml_bytes = self.fetcher("%s/content/data?categories=%d&pagesize=40"
                                         % (OCS_BASE, ocs_id))
                items = parse_content_list(xml_bytes)
                with open(cache, "w") as f:
                    json.dump({"fetched": time.time(), "items": items}, f)
            except Exception:
                try:
                    with open(cache) as f:
                        items = json.load(f)["items"]
                    stale = True
                except (OSError, ValueError, KeyError):
                    raise StoreError("KDE Store unavailable and no cache for %s" % label)
            for it in items:
                it.update(source="kde", ocsId=ocs_id, ocsCategory=label,
                          category=category, stale=stale,
                          kind="data" if hint == "data" else "code")
            out.extend(items)
        return out

    # -- KDE import --
    def install_kde(self, entry, file_index=0):
        """Download, verify and convert one KDE data item into the local
        library. kind=code entries are refused before any download."""
        if entry.get("kind") != "data":
            raise StoreError("item ships code; data-only rule keeps it listing-only")
        if not entry.get("files"):
            raise StoreError("item has no downloadable files")
        if file_index >= len(entry["files"]):
            raise StoreError("no such file index")
        url = entry["files"][file_index]["url"]
        slug = re.sub(r"[^a-z0-9-]+", "-", (entry.get("title") or "item").lower()).strip("-") or "item"
        key = "kde-%s-%s" % (entry.get("ocsId") or slug, slug)
        version = entry.get("version") or "0"

        data = self.fetcher(url)
        digest = sha256(data)
        for old in self.list_installed():
            if old["key"] == key and old.get("sourceSha256") and old["sourceSha256"] != digest \
                    and old.get("version") == version:
                raise StoreError("checksum changed for pinned version %s; refusing" % version)

        dest = os.path.join(self.root, "imports", "%s-%s" % (key, version))
        staging = tempfile.mkdtemp(dir=os.path.join(self.root, "tmp"))
        try:
            names = _extract_archive(data, staging)
            part = {
                "format": "eltopart/1",
                "source": "kde",
                "kind": "data",
                "category": entry.get("category"),
                "title": entry.get("title"),
                "version": version,
                "author": entry.get("author"),
                "license": entry.get("license"),
                "sourceUrl": url,
                "detailPage": entry.get("detailPage"),
                "sourceSha256": digest,
                "imported": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "files": sorted(names),
                "note": "approximate conversion where the KDE format does not map 1:1",
            }
            with open(os.path.join(staging, "part.json"), "w") as f:
                json.dump(part, f, indent=2, sort_keys=True)
            if os.path.lexists(dest):
                shutil.rmtree(dest)
            os.rename(staging, dest)
        except BaseException:
            shutil.rmtree(staging, ignore_errors=True)
            raise

        items = [i for i in self.list_installed() if i["key"] != key]
        items.append({"key": key, "kind": "data", "category": entry.get("category"),
                      "title": entry.get("title"), "version": version, "path": dest,
                      "source": "kde", "sourceSha256": digest, "enabled": True})
        self._save_registry(items)
        return dest

    def set_enabled(self, key, enabled):
        items = self.list_installed()
        for it in items:
            if it["key"] == key:
                it["enabled"] = bool(enabled)
                self._save_registry(items)
                return
        raise StoreError("no installed item %r" % key)

    def remove(self, key):
        items = self.list_installed()
        kept = [i for i in items if i["key"] != key]
        if len(kept) == len(items):
            raise StoreError("no installed item %r" % key)
        gone = next(i for i in items if i["key"] == key)
        shutil.rmtree(gone["path"], ignore_errors=True)
        self._save_registry(kept)


# ---------------------------------------------------------------- archives

def _jprint(obj):
    sys.stdout.write(json.dumps(obj) + "\n")


def cli(argv):
    """JSON bridge for the manager UI (and anything else that can spawn a
    process). Mirrors elto-world: {"ok": true, ...} or {"ok": false,
    "error": ...} on stdout. Read-only except install/enable/disable/remove,
    which stay inside the user data home.

    store.py --cli worlds
    store.py --cli kde <category>
    store.py --cli functions
    store.py --cli installed
    store.py --cli install            (entry JSON on stdin)
    store.py --cli enable <key> | --cli disable <key> | --cli remove <key>
    """
    st = Store()
    try:
        if argv == ["worlds"]:
            _jprint({"ok": True, "items": list_worlds()})
        elif len(argv) == 2 and argv[0] == "kde":
            items = st.kde_listing(argv[1])
            _jprint({"ok": True, "items": items, "stale": any(i.get("stale") for i in items)})
        elif argv == ["functions"]:
            _jprint({"ok": True, "items": list_functions()})
        elif argv == ["installed"]:
            _jprint({"ok": True, "items": st.list_installed()})
        elif argv == ["install"]:
            entry = json.load(sys.stdin)
            dest = st.install_kde(entry)
            _jprint({"ok": True, "path": dest})
        elif len(argv) == 2 and argv[0] == "installarg":
            entry = json.loads(argv[1])
            dest = st.install_kde(entry)
            _jprint({"ok": True, "path": dest})
        elif len(argv) == 2 and argv[0] in ("enable", "disable"):
            st.set_enabled(argv[1], argv[0] == "enable")
            _jprint({"ok": True})
        elif len(argv) == 2 and argv[0] == "remove":
            st.remove(argv[1])
            _jprint({"ok": True})
        else:
            _jprint({"ok": False, "error": "usage: worlds | kde <category> | functions | installed | install | installarg <entry-json> | enable <key> | disable <key> | remove <key>"})
            return 1
        return 0
    except (StoreError, ValueError, OSError) as e:
        _jprint({"ok": False, "error": str(e)})
        return 1


def _classify_names(names):
    """data | code, from member names alone (the pre-download hint comes
    from the OCS category; this is the content check that decides)."""
    for n in names:
        if CODE_EXTS.search(n):
            if n.lower().endswith(".desktop"):
                continue  # .desktop is data until its contents say otherwise
            return "code"
    return "data"


def _check_desktop(path):
    try:
        with open(path, "rb") as f:
            head = f.read(65536)
    except OSError:
        return
    if EXEC_LINE.search(head):
        raise StoreError(".desktop file with Exec line is not inert data: %s" % path)


def _check_svg(path):
    with open(path, "rb") as f:
        data = f.read(bundle.MAX_ASSET + 1)
    if bundle.BAD_SVG.search(data):
        raise StoreError("svg with script or remote reference: %s" % path)


def _extract_archive(data, staging):
    """Extract a zip/tar into staging under the bundle.py data-only rules.
    Returns member names. Raises StoreError on anything hostile or code."""
    total = 0
    names = []
    if zipfile.is_zipfile(io.BytesIO(data)):
        zf = zipfile.ZipFile(io.BytesIO(data))
        infos = zf.infolist()
        if len(infos) > bundle.MAX_FILES:
            raise StoreError("too many files")
        if _classify_names([i.filename for i in infos]) == "code":
            raise StoreError("archive contains code; data-only rule")
        for info in infos:
            if not bundle.safe_name(info.filename):
                raise StoreError("unsafe path in archive: %r" % info.filename)
            if info.file_size > bundle.MAX_ASSET:
                raise StoreError("file too large: %s" % info.filename)
            if info.compress_size and info.file_size / max(1, info.compress_size) > bundle.MAX_RATIO:
                raise StoreError("zip-bomb ratio: %s" % info.filename)
            total += info.file_size
            if total > bundle.MAX_BYTES:
                raise StoreError("archive too large")
            if info.is_dir():
                continue
            names.append(info.filename)
            zf.extract(info, staging)
    elif tarfile.is_tarfile(io.BytesIO(data)):
        tf = tarfile.open(fileobj=io.BytesIO(data))
        members = tf.getmembers()
        if len(members) > bundle.MAX_FILES:
            raise StoreError("too many files")
        if _classify_names([m.name for m in members]) == "code":
            raise StoreError("archive contains code; data-only rule")
        for m in members:
            if not bundle.safe_name(m.name) or m.issym() or m.islnk() or m.isdev():
                raise StoreError("unsafe member in archive: %r" % m.name)
            if m.size > bundle.MAX_ASSET:
                raise StoreError("file too large: %s" % m.name)
            total += m.size
            if total > bundle.MAX_BYTES:
                raise StoreError("archive too large")
            if m.isdir():
                continue
            names.append(m.name)
            tf.extract(m, staging, filter="data") if hasattr(tarfile, "data_filter") else tf.extract(m, staging)
    else:
        raise StoreError("unsupported archive (need zip or tar)")

    for root, _dirs, files in os.walk(staging):
        for fn in files:
            p = os.path.join(root, fn)
            low = fn.lower()
            if low.endswith(".desktop"):
                _check_desktop(p)
            if low.endswith(".svg"):
                _check_svg(p)
    return names


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--cli":
        sys.exit(cli(sys.argv[2:]))
    sys.stderr.write(__doc__)
    sys.exit(2)
