#!/usr/bin/env python3
"""ElTo Worlds store backend (user session, no root).

Stdlib only. Serves the Theme Manager (PR 3):

- reads the repo catalog (catalog.json, PR 1) for ElTo worlds
- lists KDE Store categories read-only over the public OCS API (with live
  search), with a stale cache fallback so the catalog degrades gracefully
  when the store is down
- serves item details (kdedetail) and installed-import paths (kdedir) so
  the manager can show store info and apply imported data parts
- imports KDE DATA items: the store's signed download links are
  re-resolved at install time (they expire, cached listings go stale), then
  download -> checksum (pinned per version) -> content scan under the
  bundle.py rules (no traversal, SVG sanitize, size and zip-bomb guards) ->
  staging -> atomic rename -> registry
- installable payloads are zip, tar, tar.gz, tar.xz and tar.bz2 archives,
  plus the two single-file data formats the store actually serves:
  .colors schemes and wallpaper images. Script members inside an archive
  are skipped (never written to disk) and recorded as skippedCode; an
  archive with no data at all is refused. Internal symlinks/hardlinks are
  materialized as copies; links escaping the archive refuse the install.
  Anything else (7z, rar, zstd, store notes, audio previews, HTML error
  pages) is refused with the actual format named
- KDE items that ship code are listed greyed (kind "code") and never import
- Functions (bars, widgets, ...) are listing-only from functions.json with
  their upstream links; there is no install path for them
- Rices (rices.json) are curated upstream KDE theme repos: tier A cards with
  a reviewed, commit-pinned per-file manifest install their data subset
  byte-for-byte (rices/*.files.json); anything missing or changed in the
  tarball is refused. Tier B / uncurated cards are listing-only links.
- enable/disable/remove work on the registry; system paths are the polkit
  helper's job (PR 4), this module never touches them

Nothing here executes third-party content. Archives are only ever read.

OCS category ids verified against the live API (api.opendesktop.org
/ocs/v1/content/categories) on 2026-11-28.
"""
import gzip
import hashlib
import io
import json
import os
import posixpath
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import time
import urllib.parse
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
KDE_MAX_FILES = 50000    # imported themes (icon packs) dwarf ElTo world bundles
# the total-bytes and per-file caps still come from bundle.py

CATALOG_JSON = os.path.join(HERE, "..", "catalog", "catalog.json")
FUNCTIONS_JSON = os.path.join(HERE, "functions.json")
RICES_JSON = os.path.join(HERE, "rices.json")
WORLDS_DIR = os.path.join(HERE, "..", "worlds")
WORLD_SLUG = re.compile(r"^[a-z0-9-]+$")

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


def list_rices(path=None):
    """Rice cards. Curated tier-A entries install their reviewed pinned data
    subset via Store.install_rice; everything else is a link-out card."""
    path = path or RICES_JSON
    try:
        with open(path) as f:
            items = json.load(f)
    except OSError:
        return []
    for it in items:
        if it.get("curated"):
            it.setdefault("kind", "data")
        else:
            # not installable: either a code item (kind set in the card) or a
            # tier-A repo whose reviewed pinned subset is not built yet
            it.setdefault("kind", "data")
            it["listingOnly"] = True
            if it["kind"] != "code":
                it["curationPending"] = True
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
            # smallpreviewpic1 is the card-sized image on images.pling.com;
            # preview1 is only the item's page URL, never an image
            "preview": _text(c, "smallpreviewpic1") or _text(c, "previewpic1"),
            "previews": [u for u in (_text(c, "previewpic%d" % i) for i in range(1, 5)) if u],
            "detailPage": _text(c, "detailpage"),
            "description": _text(c, "description"),
            "created": _text(c, "created"),
            "changed": _text(c, "changed"),
            "typename": _text(c, "typename"),
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


# -- conservative junk filter --
# The KDE Store's open upload policy lets spam, test uploads, duplicates and
# off-topic files into every category. These rules hide only what public
# store data marks as junk; everything filtered stays one toggle away and
# carries its reason. No taste judgments: borderline items stay visible.
MIN_ITEM_TEXT = 24  # chars of summary+description below which an entry tells you nothing

# wallpapers only: items that say they are something else entirely
WALLPAPER_MISFIT = re.compile(
    r"\b(avatars?|watchfaces?|splash(?:es)?\b|logos?\d*|banners?|calendars?|"
    r"info-?graphics?|templates?|3d models?|user pictures?|profile pics?|posters?)",
    re.I)


def _norm_title(t):
    return re.sub(r"[^a-z0-9]+", " ", (t or "").casefold()).strip()


def _download_count(item):
    try:
        return int(item.get("downloads") or 0)
    except (TypeError, ValueError):
        return 0


def kde_junk_reason(item):
    """One human-readable reason this store entry is junk, or "" when it is
    fine. Conservative on purpose: a signal fires only when the entry's own
    public data condemns it."""
    if not (item.get("files") or []):
        return "no downloadable file"
    text = ((item.get("summary") or "") + " " + (item.get("description") or "")).strip()
    if len(text) < MIN_ITEM_TEXT:
        return "almost no description"
    if item.get("category") == "wallpapers":
        m = WALLPAPER_MISFIT.search((item.get("title") or "") + " " + (item.get("summary") or ""))
        if m:
            return "not a wallpaper (it says: %s)" % m.group(0).lower()
    return ""


def _annotate_junk(items):
    """Tag each entry with filtered/filter_reason; fold same-author
    duplicates into the best-downloaded copy."""
    seen = {}
    for it in items:
        reason = kde_junk_reason(it)
        key = (_norm_title(it.get("title")), (it.get("author") or "").casefold())
        if not reason and key in seen:
            keep = seen[key]
            winner, loser = (keep, it) if _download_count(it) <= _download_count(keep) else (it, keep)
            loser["filtered"] = True
            loser["filter_reason"] = "duplicate of '%s'" % winner["title"]
            seen[key] = winner
            if loser is it:
                continue
        elif not reason:
            seen[key] = it
        it["filtered"] = bool(reason)
        it["filter_reason"] = reason
    return items


class Store:
    def __init__(self, root=None, fetcher=fetch_url, worlds_dir=WORLDS_DIR):
        self.root = root or default_root()
        self.fetcher = fetcher
        self.worlds_dir = worlds_dir
        for sub in ("cache", "cache/ocs", "imports", "tmp"):
            os.makedirs(os.path.join(self.root, sub), exist_ok=True)

    # -- registry --
    def _registry_path(self):
        return os.path.join(self.root, "installed.json")

    def list_installed(self):
        items = self._registry_items()
        known = {i["path"] for i in items}
        items.extend(self._scanned_worlds(known))
        return items

    def _registry_items(self):
        try:
            with open(self._registry_path()) as f:
                return json.load(f)["items"]
        except (OSError, ValueError, KeyError):
            return []

    def _scanned_worlds(self, skip_paths=()):
        """World directories already sitting in the user worlds root (e.g.
        installed by elto-world directly) that the registry does not know.
        Listed so Installed shows real items; removal works the same."""
        out = []
        try:
            names = sorted(os.listdir(self.root))
        except OSError:
            return out
        for name in names:
            d = os.path.join(self.root, name)
            wj = os.path.join(d, "world.json")
            if not os.path.isfile(wj) or d in skip_paths:
                continue
            try:
                with open(wj) as f:
                    w = json.load(f)
            except (OSError, ValueError):
                continue
            out.append({"key": "world-" + name, "kind": "data", "category": "worlds",
                        "title": w.get("label", name), "version": str(w.get("version", "?")),
                        "path": d, "source": "elto", "enabled": True})
        return out

    def _save_registry(self, items):
        tmp = self._registry_path() + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"format": "eltoinstalled/1", "items": items}, f, indent=2, sort_keys=True)
        os.replace(tmp, self._registry_path())

    # -- KDE listing (read-only, cached) --
    def _ocs_cache(self, ocs_id):
        return os.path.join(self.root, "cache", "ocs", "%d.json" % ocs_id)

    def kde_listing(self, category, search="", fresh_after=CACHE_TTL):
        """List a KDE category read-only. Falls back to a stale cache with
        stale=True when the store is unreachable - graceful, honest. A
        non-empty search queries the store live (results are never cached,
        so a search can never clobber the category cache)."""
        if category not in KDE_CATEGORIES:
            raise StoreError("unknown KDE category %r" % category)
        out = []
        for ocs_id, label, hint in KDE_CATEGORIES[category]:
            cache = self._ocs_cache(ocs_id)
            items, stale = None, False
            url = "%s/content/data?categories=%d&pagesize=40" % (OCS_BASE, ocs_id)
            if search:
                url += "&search=" + urllib.parse.quote(search)
            try:
                xml_bytes = self.fetcher(url)
                items = parse_content_list(xml_bytes)
                if not search:
                    with open(cache, "w") as f:
                        json.dump({"fetched": time.time(), "items": items}, f)
            except Exception:
                if search:
                    raise StoreError("KDE Store unavailable; search needs a live connection")
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
        return _annotate_junk(out)

    # -- KDE import --
    def install_kde(self, entry, file_index=None):
        """Download, verify and convert one KDE data item into the local
        library. kind=code entries are refused before any download. The
        download link is re-resolved first: OCS signed links expire, and a
        cached listing must still install."""
        if entry.get("kind") != "data":
            raise StoreError("item ships code; data-only rule keeps it listing-only")
        files = entry.get("files") or []
        if not files:
            raise StoreError("item has no downloadable files")
        if file_index is None:
            file_index = _pick_file_index(entry)
        if file_index >= len(files):
            raise StoreError("no such file index")
        listed_url = files[file_index].get("url") or ""
        url = self._fresh_url(entry, file_index) or listed_url
        slug = re.sub(r"[^a-z0-9-]+", "-", (entry.get("title") or "item").lower()).strip("-") or "item"
        key = "kde-%s-%s" % (entry.get("ocsId") or slug, slug)
        version = entry.get("version") or "0"

        try:
            data = self.fetcher(url)
        except StoreError:
            raise
        except (OSError, ValueError) as e:
            raise StoreError("download failed: %s" % e)
        digest = sha256(data)
        for old in self.list_installed():
            if old["key"] == key and old.get("sourceSha256") and old["sourceSha256"] != digest \
                    and old.get("version") == version:
                raise StoreError("checksum changed for pinned version %s; refusing" % version)

        dest = os.path.join(self.root, "imports", "%s-%s" % (key, version))
        staging = tempfile.mkdtemp(dir=os.path.join(self.root, "tmp"))
        try:
            if zipfile.is_zipfile(io.BytesIO(data)) or tarfile.is_tarfile(io.BytesIO(data)):
                names, skipped, skipped_links = _extract_archive(data, staging, max_files=KDE_MAX_FILES)
            else:
                names = _install_raw(data, staging, entry, files[file_index].get("name") or url)
                skipped, skipped_links = [], []
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
            if skipped:
                part["skippedCode"] = sorted(skipped)
            if skipped_links:
                part["skippedLinks"] = sorted(skipped_links)
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

    # -- rice import (reviewed, commit-pinned data subset) --
    def install_rice(self, rice_id):
        """Install the curated data subset of one rice, byte-for-byte against
        its reviewed manifest. The manifest pins the upstream commit and every
        file's sha256; the tarball is fetched fresh but only manifest bytes
        land on disk - a missing, resized or altered file refuses the whole
        install. Upstream scripts are never read, let alone run."""
        entry = next((r for r in list_rices() if r["id"] == rice_id), None)
        if entry is None:
            raise StoreError("no rice %r" % (rice_id,))
        if not entry.get("curated") or not entry.get("manifest"):
            raise StoreError("rice %r has no reviewed pinned subset; listing-only" % rice_id)
        mpath = os.path.join(HERE, entry["manifest"])
        try:
            with open(mpath) as f:
                manifest = json.load(f)
        except (OSError, ValueError) as e:
            raise StoreError("bad manifest for %r: %s" % (rice_id, e))
        if manifest.get("format") != "eltoricefiles/1" or manifest.get("commit") != entry.get("commit"):
            raise StoreError("manifest does not match the pinned card for %r" % rice_id)
        files = manifest.get("files") or []
        if not files or len(files) > bundle.MAX_FILES:
            raise StoreError("manifest file list empty or over cap for %r" % rice_id)
        for mf in files:
            rel = mf.get("path") or ""
            if not bundle.safe_name(rel):
                raise StoreError("unsafe path in manifest: %r" % rel)
            if CODE_EXTS.search(rel) and not rel.lower().endswith(".desktop"):
                raise StoreError("code file in manifest: %r" % rel)
            if int(mf.get("size", 0)) > bundle.MAX_ASSET:
                raise StoreError("manifest file over per-file cap: %r" % rel)

        url = "https://codeload.github.com/%s/tar.gz/%s" % (entry["repo"], entry["commit"])
        data = self.fetcher(url)
        if not tarfile.is_tarfile(io.BytesIO(data)):
            raise StoreError("upstream tarball is not a tar archive")
        tf = tarfile.open(fileobj=io.BytesIO(data))
        # GitHub tarballs wrap everything in one <owner>-<repo>-<sha>/ root;
        # strip that first component and match manifest paths exactly.
        members = {}
        for m in tf.getmembers():
            if not m.isfile():
                continue
            parts = m.name.split("/", 1)
            if len(parts) != 2:
                continue
            members.setdefault(parts[1], m)

        key = "rice-" + rice_id
        version = str(entry.get("version") or entry["commit"][:12])
        dest = os.path.join(self.root, "imports", "%s-%s" % (key, version))
        staging = tempfile.mkdtemp(dir=os.path.join(self.root, "tmp"))
        try:
            names = []
            for mf in files:
                rel = mf["path"]
                m = members.get(rel)
                if m is None:
                    raise StoreError("manifest file missing in tarball: %r" % rel)
                if m.size != int(mf["size"]):
                    raise StoreError("size drift for %r (pinned %d, got %d)" % (rel, mf["size"], m.size))
                fobj = tf.extractfile(m)
                blob = fobj.read(bundle.MAX_ASSET + 1)
                if sha256(blob) != mf["sha256"]:
                    raise StoreError("sha256 drift for %r; upstream content changed, refusing" % rel)
                target = os.path.join(staging, rel)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with open(target, "wb") as f:
                    f.write(blob)
                names.append(rel)
            for root, _dirs, fns in os.walk(staging):
                for fn in fns:
                    p = os.path.join(root, fn)
                    low = fn.lower()
                    if low.endswith(".desktop"):
                        _check_desktop(p)
                    if low.endswith(".svg"):
                        _check_svg(p)
            part = {
                "format": "eltopart/1",
                "source": "github-rice",
                "kind": "data",
                "category": "rices",
                "title": entry.get("label"),
                "version": version,
                "author": entry.get("author"),
                "license": entry.get("license"),
                "sourceUrl": url,
                "detailPage": entry.get("upstream"),
                "pinnedCommit": entry["commit"],
                "applies": entry.get("applies") or [],
                "linksOnly": entry.get("linksOnly") or [],
                "imported": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "files": sorted(names),
                "note": "reviewed pinned data subset (rices/%s.files.json); upstream code parts linked, never installed" % rice_id,
            }
            with open(os.path.join(staging, "part.json"), "w") as f:
                json.dump(part, f, indent=2, sort_keys=True)
            if os.path.lexists(dest):
                shutil.rmtree(dest)
            os.rename(staging, dest)
        except BaseException:
            shutil.rmtree(staging, ignore_errors=True)
            raise

        items = [i for i in self._registry_items() if i["key"] != key]
        items.append({"key": key, "kind": "data", "category": "rices",
                      "title": entry.get("label"), "version": version, "path": dest,
                      "source": "github-rice", "pinnedCommit": entry["commit"],
                      "enabled": True})
        self._save_registry(items)
        return dest

    def rice_dir(self, key):
        """Absolute path of an installed rice (registry key rice-<id>), for
        elto-world parts/applypart."""
        if not re.match(r"^rice-[a-z0-9][a-z0-9-]*$", key or ""):
            raise StoreError("bad rice key %r" % (key,))
        for it in self._registry_items():
            if it["key"] == key and os.path.isfile(os.path.join(it["path"], "part.json")):
                return it["path"]
        raise StoreError("rice %r is not installed" % key)

    def _fresh_url(self, entry, file_index):
        """Re-resolve the item's current download link from the OCS content
        detail: the signed links in a cached listing expire. None when the
        detail cannot be fetched or parsed (callers fall back to the listed
        link)."""
        cid = str(entry.get("id") or "")
        if not cid.isdigit():
            return None
        try:
            xml = self.fetcher("%s/content/data/%s?format=xml" % (OCS_BASE, cid), limit=MAX_LIST_XML)
            items = parse_content_list(xml)
        except Exception:
            return None
        if not items:
            return None
        files = items[0].get("files") or []
        if file_index < len(files):
            return files[file_index].get("url") or None
        return None

    def kde_detail(self, content_id):
        """Full public store info for one item, for the details view. The
        content detail endpoint carries the description and dates that the
        listing truncates. Read-only; the returned dict is display data,
        install still goes through the card's own entry."""
        cid = str(content_id or "")
        if not cid.isdigit():
            raise StoreError("bad store item id %r" % (content_id,))
        xml = self.fetcher("%s/content/data/%s?format=xml" % (OCS_BASE, cid), limit=MAX_LIST_XML)
        items = parse_content_list(xml)
        if not items:
            raise StoreError("no such store item %s" % cid)
        return items[0]

    def kde_dir(self, key):
        """Absolute path of an installed KDE import (registry key kde-...),
        for elto-world kdeparts/applypart."""
        if not re.match(r"^kde-[a-z0-9][a-z0-9-]*$", key or ""):
            raise StoreError("bad KDE key %r" % (key,))
        for it in self._registry_items():
            if it["key"] == key and os.path.isfile(os.path.join(it["path"], "part.json")):
                return it["path"]
        raise StoreError("KDE item %r is not installed" % key)

    # -- world install (copy from the repo worlds dir, register) --
    def install_world(self, world_id):
        """Install one ElTo world into the user worlds dir. Worlds are repo
        data, already vetted by elto-world check; this is a copy + registry
        entry, no download and no code path."""
        if not WORLD_SLUG.match(world_id or ""):
            raise StoreError("bad world id %r" % (world_id,))
        src = os.path.join(self.worlds_dir, world_id)
        wj = os.path.join(src, "world.json")
        if not os.path.isfile(wj):
            raise StoreError("no such world in the catalog: %r" % world_id)
        with open(wj) as f:
            w = json.load(f)
        dest = os.path.join(self.root, world_id)
        if os.path.lexists(dest):
            shutil.rmtree(dest)
        shutil.copytree(src, dest)
        items = [i for i in self._registry_items() if i["key"] != "world-" + world_id]
        items.append({"key": "world-" + world_id, "kind": "data", "category": "worlds",
                      "title": w.get("label", world_id), "version": str(w.get("version", "?")),
                      "path": dest, "source": "elto", "enabled": True})
        self._save_registry(items)
        return dest

    def world_dir(self, world_id):
        """Absolute path of an installed world, for elto-world apply."""
        if not WORLD_SLUG.match(world_id or ""):
            raise StoreError("bad world id %r" % (world_id,))
        d = os.path.join(self.root, world_id)
        if not os.path.isfile(os.path.join(d, "world.json")):
            raise StoreError("world %r is not installed" % world_id)
        return d

    def world_updates(self, catalog=None):
        """Installed ElTo worlds whose version differs from the repo catalog."""
        catalog = catalog or load_repo_catalog()
        fresh = {w["id"]: w for w in catalog["worlds"]}
        rows = []
        for it in self.list_installed():
            if it.get("source") != "elto" or not it["key"].startswith("world-"):
                continue
            wid = it["key"][len("world-"):]
            cur = fresh.get(wid)
            if cur and str(cur.get("version")) != str(it.get("version")):
                rows.append({"id": wid, "title": it.get("title") or cur.get("label"),
                             "oldV": str(it.get("version")), "newV": str(cur.get("version"))})
        return rows

    def set_enabled(self, key, enabled):
        items = self.list_installed()
        for it in items:
            if it["key"] == key:
                it["enabled"] = bool(enabled)
                self._save_registry(items)
                return
        raise StoreError("no installed item %r" % key)

    def remove(self, key):
        items = self._registry_items()
        kept = [i for i in items if i["key"] != key]
        if len(kept) == len(items):
            # not registered: still removable if it is a scanned world dir
            if key.startswith("world-") and WORLD_SLUG.match(key[len("world-"):]):
                d = os.path.join(self.root, key[len("world-"):])
                if os.path.isfile(os.path.join(d, "world.json")):
                    shutil.rmtree(d, ignore_errors=True)
                    return
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
    store.py --cli kde <category> [search...]
    store.py --cli functions
    store.py --cli rices
    store.py --cli installrice <id>
    store.py --cli installed
    store.py --cli install            (entry JSON on stdin)
    store.py --cli installworld <id>  (copy an ElTo world into the user dir)
    store.py --cli worlddir <id>      (installed world path, for apply)
    store.py --cli updates            (installed worlds behind the catalog)
    store.py --cli enable <key> | --cli disable <key> | --cli remove <key>
    """
    st = Store()
    try:
        if argv == ["worlds"]:
            _jprint({"ok": True, "items": list_worlds()})
        elif len(argv) >= 2 and argv[0] == "kde":
            items = st.kde_listing(argv[1], search=" ".join(argv[2:]))
            _jprint({"ok": True, "items": items, "stale": any(i.get("stale") for i in items),
                     "filtered_count": sum(1 for i in items if i.get("filtered"))})
        elif argv == ["functions"]:
            _jprint({"ok": True, "items": list_functions()})
        elif argv == ["rices"]:
            _jprint({"ok": True, "items": list_rices()})
        elif len(argv) == 2 and argv[0] == "kdedetail":
            _jprint({"ok": True, "item": st.kde_detail(argv[1])})
        elif len(argv) == 2 and argv[0] == "kdedir":
            _jprint({"ok": True, "path": st.kde_dir(argv[1])})
        elif len(argv) == 2 and argv[0] == "installrice":
            dest = st.install_rice(argv[1])
            _jprint({"ok": True, "path": dest})
        elif argv == ["installed"]:
            _jprint({"ok": True, "items": st.list_installed()})
        elif len(argv) == 2 and argv[0] == "installworld":
            dest = st.install_world(argv[1])
            _jprint({"ok": True, "path": dest})
        elif len(argv) == 2 and argv[0] == "worlddir":
            _jprint({"ok": True, "path": st.world_dir(argv[1])})
        elif len(argv) == 2 and argv[0] == "ricedir":
            _jprint({"ok": True, "path": st.rice_dir(argv[1])})
        elif argv == ["updates"]:
            _jprint({"ok": True, "worlds": st.world_updates()})
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
            _jprint({"ok": False, "error": "usage: worlds | kde <category> [search...] | kdedetail <id> | kdedir <key> | functions | rices | installrice <id> | ricedir <key> | installed | install | installarg <entry-json> | installworld <id> | worlddir <id> | updates | enable <key> | disable <key> | remove <key>"})
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


ARCHIVE_EXTS = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2")
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".svg")
AUDIO_EXTS = (".mp3", ".ogg", ".oga", ".wav", ".flac")
NOTE_EXTS = (".txt", ".md", ".pdf", ".html", ".htm")

_MAGICS = [
    ("zip", b"PK\x03\x04"),
    ("gzip", b"\x1f\x8b"),
    ("xz", b"\xfd7zXZ\x00"),
    ("bzip2", b"BZh"),
    ("zstd", b"\x28\xb5\x2f\xfd"),
    ("7z", b"7z\xbc\xaf\x27\x1c"),
    ("rar", b"Rar!\x1a\x07"),
    ("png", b"\x89PNG\r\n\x1a\n"),
    ("jpeg", b"\xff\xd8\xff"),
    ("bmp", b"BM"),
    ("audio", b"ID3"),
    ("audio", b"OggS"),
    ("audio", b"fLaC"),
    ("audio", b"\xff\xfb"),
]


def _sniff(data):
    """Format label from magic bytes, for precise answers about a payload."""
    for label, magic in _MAGICS:
        if data.startswith(magic):
            return label
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    if data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        return "audio"
    head = data[:512].lstrip()
    if head[:1] == b"<":
        return "page"
    try:
        head.decode("utf-8")
        if b"\x00" not in head:
            return "text"
    except UnicodeDecodeError:
        pass
    return "data"


def _pick_file_index(entry):
    """Choose the most installable file of an OCS entry: real archives and
    the category's raw data format first, store notes and previews last."""
    files = entry.get("files") or []
    cat = entry.get("category")

    def score(f):
        n = ((f.get("name") or f.get("url") or "").split("?")[0]).lower()
        if any(n.endswith(e) for e in ARCHIVE_EXTS):
            return 0
        if cat == "color-scheme" and n.endswith(".colors"):
            return 0
        if cat == "wallpapers" and any(n.endswith(e) for e in IMAGE_EXTS):
            return 0
        if any(n.endswith(e) for e in AUDIO_EXTS + NOTE_EXTS + (".desktop",)):
            return 2
        return 1

    return min(range(len(files)), key=lambda i: (score(files[i]), i))


def _is_code_name(n):
    return bool(CODE_EXTS.search(n)) and not n.lower().endswith(".desktop")


def _write_bytes(staging, name, data):
    dst = os.path.join(staging, name)
    d = os.path.dirname(dst)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(dst, "wb") as f:
        f.write(data)
    return dst


def _write_member(staging, name, fileobj):
    dst = os.path.join(staging, name)
    d = os.path.dirname(dst)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(dst, "wb") as out:
        shutil.copyfileobj(fileobj, out)


def _link_canonical(member_name, linkname, hardlink=False):
    """Canonical archive-relative path of a link target, or None when the
    link is absolute or escapes the archive root."""
    if not linkname or linkname.startswith("/") or "\x00" in linkname or "\\" in linkname:
        return None
    if hardlink:
        cand = linkname
    else:
        base = posixpath.dirname(member_name)
        cand = posixpath.join(base, linkname) if base else linkname
    cand = posixpath.normpath(cand)
    if cand == ".." or cand.startswith("../") or posixpath.isabs(cand):
        return None
    return cand


def _resolve_link(name, linkmap, regulars, depth=0):
    """Follow a link (through further links, as cursor and icon themes
    chain aliases) to a regular data file. None when the chain escapes,
    cycles or ends at something that is not data."""
    if name in regulars:
        return name
    if depth > 40 or name not in linkmap:
        return None
    target, hard = linkmap[name]
    cand = _link_canonical(name, target, hardlink=hard)
    if cand is None:
        return None
    return _resolve_link(cand, linkmap, regulars, depth + 1)


def _copy_extracted(staging, target, name):
    """Materialize a link as a plain copy of its already-extracted target:
    no symlink ever lands on disk, so nothing can escape later."""
    src = os.path.join(staging, target)
    dst = os.path.join(staging, name)
    d = os.path.dirname(dst)
    if d:
        os.makedirs(d, exist_ok=True)
    shutil.copyfile(src, dst)
    return os.path.getsize(dst)


def _unsupported_reason(data, name):
    fmt = _sniff(data)
    label = {
        "gzip": "gzip-compressed data that is not a tar archive",
        "xz": "xz-compressed data that is not a tar archive",
        "bzip2": "bzip2-compressed data that is not a tar archive",
        "zstd": "a zstd archive (not supported: no standard zstd reader)",
        "7z": "a 7z archive (not supported)",
        "rar": "a RAR archive (not supported)",
        "page": "a web page, not a file (the store link expired or moved; reopen the category and retry)",
        "text": "plain text, not a theme file",
        "audio": "an audio file, not a theme archive",
        "png": "a PNG image",
        "jpeg": "a JPEG image",
        "webp": "a WebP image",
        "bmp": "a BMP image",
    }.get(fmt, "unrecognized data")
    return "unsupported download: got %s; installable formats are zip, tar, tar.gz, tar.xz and tar.bz2" % label


def _install_raw(data, staging, entry, fname):
    """Single-file downloads. Installable only where the category's data IS
    one file: .colors schemes and wallpaper images. Everything else is
    refused with the actual format named."""
    cat = entry.get("category")
    base = os.path.basename((fname or "").split("?")[0]) or "download"
    if not bundle.safe_name(base):
        base = "download"
    low = base.lower()
    if len(data) > bundle.MAX_ASSET:
        raise StoreError("file too large (%d bytes, cap %d)" % (len(data), bundle.MAX_ASSET))
    fmt = _sniff(data)
    if fmt == "page":
        raise StoreError(_unsupported_reason(data, base))
    if fmt == "gzip":
        try:
            data = gzip.decompress(data)
        except OSError:
            raise StoreError("corrupt gzip download: %s" % base)
        if low.endswith(".gz"):
            base = base[:-3]
            low = low[:-3]
        fmt = _sniff(data)
    if cat == "color-scheme" and low.endswith(".colors"):
        if fmt != "text":
            raise StoreError(".colors file is not text (got %s)" % fmt)
        _write_bytes(staging, base, data)
        return [base]
    if cat == "wallpapers":
        if fmt in ("png", "jpeg", "webp", "bmp"):
            _write_bytes(staging, base, data)
            return [base]
        if low.endswith(".svg") and fmt == "text":
            path = _write_bytes(staging, base, data)
            _check_svg(path)
            return [base]
        if low.endswith(".desktop"):
            raise StoreError("a bare .desktop wallpaper stub (%s) has no image with it; this entry ships no usable wallpaper file" % base)
    if fmt == "audio" or low.endswith(AUDIO_EXTS):
        raise StoreError("a single audio file (%s) is a preview, not a sound theme; nothing installable in this entry" % base)
    if fmt == "text" or low.endswith(NOTE_EXTS):
        raise StoreError("this file is a store note (%s), not an installable theme; nothing usable in this entry" % base)
    raise StoreError(_unsupported_reason(data, base))


def _extract_archive(data, staging, max_files=bundle.MAX_FILES):
    """Extract a zip/tar (gz, xz and bz2 auto-detected) into staging under
    the bundle.py data-only rules. Script members are skipped, never
    written; an archive with no data at all is refused. Internal links to
    regular files are materialized as copies; links escaping the archive
    refuse the install. Returns (data member names, skipped code names)."""
    total = 0
    names = []
    skipped = []
    skipped_links = []
    linkmap = {}
    if zipfile.is_zipfile(io.BytesIO(data)):
        zf = zipfile.ZipFile(io.BytesIO(data))
        infos = zf.infolist()
        if len(infos) > max_files:
            raise StoreError("archive has %d files (cap %d)" % (len(infos), max_files))
        for info in infos:
            n = info.filename
            if not bundle.safe_name(n):
                raise StoreError("unsafe path in archive: %r" % n)
            if info.is_dir():
                continue
            mode = info.external_attr >> 16
            if stat.S_IFMT(mode) == stat.S_IFLNK:
                linkmap[n] = (zf.read(info)[:4096].decode("utf-8", "replace").strip(), False)
                continue
            if _is_code_name(n):
                skipped.append(n)
                continue
            if info.file_size > bundle.MAX_ASSET:
                raise StoreError("file too large: %s" % n)
            if info.compress_size and info.file_size / max(1, info.compress_size) > bundle.MAX_RATIO:
                raise StoreError("zip-bomb ratio: %s" % n)
            total += info.file_size
            if total > bundle.MAX_BYTES:
                raise StoreError("archive too large (over %d bytes uncompressed)" % bundle.MAX_BYTES)
            names.append(n)
            zf.extract(info, staging)
    elif tarfile.is_tarfile(io.BytesIO(data)):
        tf = tarfile.open(fileobj=io.BytesIO(data))
        members = tf.getmembers()
        if len(members) > max_files:
            raise StoreError("archive has %d files (cap %d)" % (len(members), max_files))
        for m in members:
            if not bundle.safe_name(m.name) or m.isdev() or m.isfifo():
                raise StoreError("unsafe member in archive: %r" % m.name)
            if m.isdir():
                continue
            if m.issym() or m.islnk():
                linkmap[m.name] = (m.linkname, m.islnk())
                continue
            if not m.isfile():
                raise StoreError("unsafe member in archive: %r" % m.name)
            if _is_code_name(m.name):
                skipped.append(m.name)
                continue
            if m.size > bundle.MAX_ASSET:
                raise StoreError("file too large: %s" % m.name)
            total += m.size
            if total > bundle.MAX_BYTES:
                raise StoreError("archive too large (over %d bytes uncompressed)" % bundle.MAX_BYTES)
            names.append(m.name)
            _write_member(staging, m.name, tf.extractfile(m))
    else:
        raise StoreError(_unsupported_reason(data, ""))

    regulars = set(names)
    for n in linkmap:
        if _is_code_name(n):
            skipped.append(n)
            continue
        t = _resolve_link(n, linkmap, regulars)
        if t is None:
            # upstream ships aliases whose target is a directory, another
            # alias chain that dead-ends, or an absolute path from the
            # author's machine. Nothing is written for them: the link is
            # only ever resolved to archive members, never the filesystem.
            skipped_links.append(n)
            continue
        total += _copy_extracted(staging, t, n)
        names.append(n)
        regulars.add(n)

    if not names:
        if skipped:
            raise StoreError("archive ships only code (%s); the data-only rule keeps it out"
                             % ", ".join(sorted(skipped)[:3]))
        raise StoreError("archive has no files in it")

    for root, _dirs, files in os.walk(staging):
        for fn in files:
            p = os.path.join(root, fn)
            low = fn.lower()
            if low.endswith(".desktop"):
                _check_desktop(p)
            if low.endswith(".svg"):
                _check_svg(p)
    return names, skipped, skipped_links

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--cli":
        sys.exit(cli(sys.argv[2:]))
    sys.stderr.write(__doc__)
    sys.exit(2)
