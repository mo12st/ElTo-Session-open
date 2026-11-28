"""bundle.py: hardened reader for .elworld bundles (format elworld/1, written by `elto-world pack`).

Stdlib only. A bundle is DATA ONLY; nothing in it is ever executed and there is no hook mechanism.
Everything is verified BEFORE a single byte reaches its final location:
inspect -> verify (no writes) ; unpack/install -> verify, extract into a staging dir, validate
world.json, then atomic rename. An existing world is never overwritten without `replace`, and
a replaced world is kept as a backup.
Limits are the ones of the pack command (25 MB per file, 500 files, 150 MB total).
"""
import hashlib, json, os, re, shutil, stat, sys, time, zipfile

MAX_WORLD_JSON = 1024 * 1024
MAX_ASSET = 25 * 1024 * 1024
MAX_FILES = 500
MAX_BYTES = 150 * 1024 * 1024
MAX_RATIO = 200          # uncompressed/compressed per file, zip-bomb guard
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SCRIPT_EXT = re.compile(r"\.(sh|bash|zsh|py|pl|rb|js|exe|dll|so|bin|desktop|qml|service|timer|jar|run|appimage)$", re.I)
ASSET_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".ogg", ".flac", ".json", ".txt", ".md", ".theme", ".ttf", ".otf", ".desktop", ".rc"}
EXEC_LINE = re.compile(rb"^\s*(?:Try)?Exec\s*=", re.M)
TOP_FILES = ("world.json", "manifest.json", "CREDITS")
PREVIEW = re.compile(r"^preview\.(png|jpe?g|webp)$")
# SVG that can run code or fetch things
BAD_SVG = re.compile(rb"<\s*script|\bon[a-z]+\s*=|javascript:|<\s*foreignObject|<\s*iframe|(?:href|src)\s*=\s*[\"']\s*(?:https?:|file:|//|data:text/html)|@import|url\(\s*[\"']?\s*(?:https?:|file:|//)", re.I)


class BundleError(Exception):
    def __init__(self, errors):
        self.errors = [errors] if isinstance(errors, str) else list(errors)
        Exception.__init__(self, "; ".join(self.errors))


def safe_name(n):
    if not n or "\x00" in n or "\\" in n or n.startswith("/") or re.match(r"^[A-Za-z]:", n):
        return False
    return all(p not in ("", ".", "..") and p == p.strip() and not p.endswith(".") for p in n.rstrip("/").split("/"))


def _read_limited(z, info, limit):
    """Read a member, counting real bytes (the header size may lie)."""
    out, size = [], 0
    with z.open(info) as f:
        while True:
            b = f.read(65536)
            if not b:
                break
            size += len(b)
            if size > limit:
                raise BundleError("file larger than its limit while reading: " + info.filename)
            out.append(b)
    return b"".join(out)


def verify(path):
    """Full verification without writing anything. Returns report dict, raises BundleError."""
    if not os.path.isfile(path) or not zipfile.is_zipfile(path):
        raise BundleError("not a zip file")
    errors = []
    with zipfile.ZipFile(path) as z:
        infos = [i for i in z.infolist() if not i.is_dir()]
        if len(infos) > MAX_FILES:
            raise BundleError("too many files in bundle (%d > %d)" % (len(infos), MAX_FILES))
        names, folded, total = [], set(), 0
        for i in infos:
            n = i.filename
            if not safe_name(n):
                errors.append("unsafe path in bundle: %r" % n)
                continue
            if n in names:
                errors.append("duplicate entry: " + n)
            if n.lower() in folded:
                errors.append("entries differ only by case: " + n)
            folded.add(n.lower())
            names.append(n)
            mode = (i.external_attr >> 16) & 0o170000
            if mode and mode != 0o100000:
                errors.append("symlink or special file in bundle: " + n)
            if i.flag_bits & 0x1:
                errors.append("encrypted entry: " + n)
            if n in TOP_FILES or PREVIEW.match(n):
                pass
            elif n.startswith("assets/"):
                if SCRIPT_EXT.search(n):
                    # a .desktop file is allowed only as inert metadata (no Exec=/TryExec=),
                    # e.g. an Aurorae plugin descriptor; launchers stay blocked
                    if n.lower().endswith(".desktop") and not EXEC_LINE.search(_read_limited(z, i, MAX_ASSET)):
                        pass
                    else:
                        errors.append("script or executable in bundle: " + n)
                elif os.path.splitext(n)[1].lower() not in ASSET_EXT:
                    errors.append("file type not allowed: " + n)
            else:
                errors.append("unexpected file in bundle: " + n)
            lim = MAX_WORLD_JSON if n in TOP_FILES else MAX_ASSET
            if i.file_size > lim:
                errors.append("file over %d bytes: %s" % (lim, n))
            if i.file_size > 4096 and i.compress_size and i.file_size / float(i.compress_size) > MAX_RATIO:
                errors.append("suspicious compression ratio: " + n)
            total += i.file_size
        if total > MAX_BYTES:
            errors.append("bundle uncompressed size over %d bytes" % MAX_BYTES)
        for need in ("world.json", "manifest.json"):
            if need not in names:
                errors.append("bundle must contain " + need)
        if errors:
            raise BundleError(errors)
        by = {i.filename: i for i in infos}
        try:
            manifest = json.loads(_read_limited(z, by["manifest.json"], MAX_WORLD_JSON).decode("utf-8"))
            world = json.loads(_read_limited(z, by["world.json"], MAX_WORLD_JSON).decode("utf-8"))
        except BundleError:
            raise
        except Exception as e:
            raise BundleError("manifest.json or world.json unreadable: %s" % e)
        if not isinstance(manifest, dict) or manifest.get("format") != "elworld/1":
            raise BundleError("unknown bundle format")
        if not isinstance(world, dict) or not isinstance(world.get("name"), str) or not SLUG.match(world["name"]):
            raise BundleError("world.json: bad or missing name")
        wid = world.get("id", world["name"])
        if not isinstance(wid, str) or not SLUG.match(wid):
            raise BundleError("world.json: bad id")
        if manifest.get("world") != wid:
            errors.append("manifest world does not match world.json id")
        checks = {}
        for f in manifest.get("files") or []:
            if not isinstance(f, dict) or not isinstance(f.get("path"), str):
                errors.append("bad manifest entry")
                continue
            p = f["path"]
            if p in checks:
                errors.append("duplicate manifest entry: " + p)
            if not p.startswith("assets/") or not safe_name(p):
                errors.append("manifest path not under assets/: " + p)
            if not (isinstance(f.get("sha256"), str) and SHA256.match(f["sha256"])) or not isinstance(f.get("bytes"), int):
                errors.append("manifest entry without valid sha256/bytes: " + p)
            if not str(f.get("license") or "").strip() or str(f.get("license")).strip().lower() in ("unknown", "none", "tbd", "?"):
                errors.append("no license recorded for " + p)
            checks[p] = f
        for n in names:
            if n.startswith("assets/") and n not in checks:
                errors.append("asset not in manifest: " + n)
        for p in checks:
            if p not in names:
                errors.append("manifest asset missing from bundle: " + p)
        if errors:
            raise BundleError(errors)
        real = 0
        for p, f in checks.items():
            data = _read_limited(z, by[p], MAX_ASSET)
            real += len(data)
            if real > MAX_BYTES:
                raise BundleError("bundle uncompressed size over %d bytes" % MAX_BYTES)
            if len(data) != f["bytes"] or hashlib.sha256(data).hexdigest() != f["sha256"]:
                errors.append("checksum mismatch: " + p)
            if p.lower().endswith(".svg") and BAD_SVG.search(data):
                errors.append("svg with script or external reference: " + p)
        for n in names:
            if PREVIEW.match(n):
                _read_limited(z, by[n], MAX_ASSET)
        warnings = sorted(set("world.json references an asset not in the bundle: " + a
                              for a in _referenced(world) if a not in names))
        if errors:
            raise BundleError(errors)
    return {"world": wid, "name": world["name"], "label": world.get("label", world["name"]),
            "author": world.get("author"), "license": world.get("license"),
            "assetsLicense": world.get("assetsLicense"), "files": len(names), "bytes": total, "warnings": warnings,
            "assets": [{"path": p, "bytes": f["bytes"], "license": f["license"]} for p, f in sorted(checks.items())]}


def _referenced(w):
    out = []
    def walk(v):
        if isinstance(v, dict):
            for x in v.values():
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
        elif isinstance(v, str) and v.startswith("assets/") and safe_name(v):
            out.append(v)
        elif isinstance(v, str) and v.startswith("assets/"):
            raise BundleError("world.json has an unsafe asset path: %r" % v)
    walk(w)
    return out


def unpack(path, dest, validate=None):
    """Verify, extract to staging, optional validate(world, stagedir)->errors, then atomic rename.
    dest must not exist."""
    rep = verify(path)
    if os.path.lexists(dest):
        raise BundleError("destination exists, not overwriting: " + dest)
    parent = os.path.dirname(os.path.abspath(dest))
    os.makedirs(parent, exist_ok=True)
    stage = os.path.join(parent, ".elworld-stage-%d-%d" % (os.getpid(), time.time() * 1000))
    os.makedirs(stage)
    try:
        root = os.path.realpath(stage)
        with zipfile.ZipFile(path) as z:
            for i in z.infolist():
                if i.is_dir():
                    continue
                t = os.path.realpath(os.path.join(stage, i.filename))
                if not t.startswith(root + os.sep):
                    raise BundleError("path escape: " + i.filename)
                os.makedirs(os.path.dirname(t), exist_ok=True)
                with z.open(i) as src, open(t, "xb") as out:
                    shutil.copyfileobj(src, out)
                os.chmod(t, 0o644)
        if validate:
            errs = validate(json.load(open(os.path.join(stage, "world.json"), encoding="utf-8")), stage)
            if errs:
                raise BundleError(errs)
        os.rename(stage, dest)
    except BaseException:
        shutil.rmtree(stage, ignore_errors=True)
        raise
    rep["extracted"] = dest
    return rep


def install(path, store, replace=False, validate=None):
    """Install into store/<world-id>/. Refuses to overwrite; with replace the old copy is moved to
    <id>.bak-<timestamp> (never deleted). Installing does not apply the world."""
    rep = verify(path)
    dest = os.path.join(store, rep["world"])
    backup = None
    if os.path.lexists(dest):
        if not replace:
            raise BundleError("world %r is already installed; nothing changed. Re-run with --replace to swap it (the old copy is kept as a backup)" % rep["world"])
        backup = "%s.bak-%s" % (dest, time.strftime("%Y%m%d-%H%M%S"))
        n = 0
        while os.path.lexists(backup):
            n += 1
            backup = "%s.bak-%s-%d" % (dest, time.strftime("%Y%m%d-%H%M%S"), n)
    tmp = dest + ".new-%d" % os.getpid()
    unpack(path, tmp, validate)
    try:
        if backup:
            os.rename(dest, backup)
        os.rename(tmp, dest)
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        if backup and not os.path.lexists(dest) and os.path.lexists(backup):
            os.rename(backup, dest)
        raise
    rep["installed"] = dest
    rep["backup"] = backup
    return rep
