#!/usr/bin/env python3
"""Build a reviewed, pinned rice manifest from a local upstream clone.

A rice manifest (rices/<id>.files.json) is the data-only review record for
one upstream KDE theme repo at one pinned commit: the exact subset of files
ElTo will install, each with its sha256 and size. store.py install_rice
fetches the upstream tarball at the pinned commit and installs exactly these
bytes - anything missing, changed, or extra is refused, so what was reviewed
here is what lands on the user's machine, byte for byte.

Review rules (the data-only rule, option 1):
- script/code extensions are refused outright (bundle.SCRIPT_EXT)
- .desktop files are data only while they carry no Exec/TryExec line
- SVGs are refused on script or remote references (bundle.BAD_SVG)
- per-file and total size caps and path safety come from bundle.py
- the upstream LICENSE file is always included in the subset

Usage:
  python3 build-manifest.py <clone-dir> <commit> <id> <subset-dir>...
Example:
  python3 build-manifest.py /tmp/WhiteSur-kde cf4df59... whitesur-kde \
      aurorae color-schemes plasma/desktoptheme wallpaper

Writes rices/<id>.files.json next to this script. Re-run after bumping the
pin; the diff is the re-review.
"""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))
import bundle  # elto-worlds/bundle.py: shared data-only rules

EXEC_LINE = None  # imported lazily from store to avoid a hard import cycle


def _exec_line():
    global EXEC_LINE
    if EXEC_LINE is None:
        sys.path.insert(0, os.path.join(HERE, ".."))
        import re
        EXEC_LINE = re.compile(rb"^\s*(?:Try)?Exec\s*=", re.M)
    return EXEC_LINE


def fail(msg):
    sys.stderr.write("manifest review FAILED: %s\n" % msg)
    sys.exit(1)


def main(argv):
    if len(argv) < 4:
        sys.stderr.write(__doc__)
        return 2
    clone, commit, rice_id = argv[0], argv[1], argv[2]
    subset = argv[3:]
    if not os.path.isdir(clone):
        fail("no such clone dir %r" % clone)

    files = []
    total = 0
    tops = list(subset)
    lic = os.path.join(clone, "LICENSE")
    lic_rel = None
    if os.path.isfile(lic):
        lic_rel = "LICENSE"
    else:
        for cand in ("LICENSE.md", "COPYING"):
            if os.path.isfile(os.path.join(clone, cand)):
                lic_rel = cand
                break
    if lic_rel is None:
        fail("no LICENSE file found at repo root; license credit is required")
    for top in tops:
        base = os.path.join(clone, top)
        if not os.path.isdir(base):
            fail("subset dir %r not found in clone" % top)
        for root, dirs, names in os.walk(base):
            dirs.sort()
            for fn in sorted(names):
                p = os.path.join(root, fn)
                rel = os.path.relpath(p, clone).replace(os.sep, "/")
                if not bundle.safe_name(rel):
                    fail("unsafe path %r" % rel)
                low = fn.lower()
                if bundle.SCRIPT_EXT.search(low):
                    if low.endswith(".desktop"):
                        with open(p, "rb") as f:
                            head = f.read(65536)
                        if _exec_line().search(head):
                            fail(".desktop with Exec line %r" % rel)
                    else:
                        fail("code file in subset %r" % rel)
                if low.endswith(".svg"):
                    with open(p, "rb") as f:
                        data = f.read(bundle.MAX_ASSET + 1)
                    if bundle.BAD_SVG.search(data):
                        fail("svg with script or remote reference %r" % rel)
                size = os.path.getsize(p)
                if size > bundle.MAX_ASSET:
                    fail("file over per-file cap %r" % rel)
                total += size
                if total > bundle.MAX_BYTES:
                    fail("subset over total cap")
                with open(p, "rb") as f:
                    digest = hashlib.sha256(f.read()).hexdigest()
                files.append({"path": rel, "sha256": digest, "size": size})

    base = os.path.join(clone, lic_rel)
    with open(base, "rb") as f:
        data = f.read()
    if len(data) > bundle.MAX_ASSET:
        fail("license file over per-file cap")
    files.append({"path": lic_rel, "sha256": hashlib.sha256(data).hexdigest(),
                  "size": len(data)})
    total += len(data)

    files.sort(key=lambda f: f["path"])
    if len(files) > bundle.MAX_FILES:
        fail("subset has %d files (cap %d)" % (len(files), bundle.MAX_FILES))

    out = {
        "format": "eltoricefiles/1",
        "id": rice_id,
        "commit": commit,
        "subsetDirs": subset,
        "fileCount": len(files),
        "totalBytes": total,
        "files": files,
    }
    dest = os.path.join(HERE, "%s.files.json" % rice_id)
    with open(dest, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")
    print("reviewed %d files, %d bytes -> %s" % (len(files), total, dest))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
