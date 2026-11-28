#!/usr/bin/env python3
"""Trail helper: read-only drive and folder facts as JSON, plus Eject.
  trail-helper.py drives            -> JSON list of mounted drives with usage
  trail-helper.py counts P1 P2 ...  -> JSON {path: item_count}
  trail-helper.py eject /dev/sdX1   -> unmount and power off (udisksctl)
File operations (copy, move, delete) are not part of v1; they will use KDE KIO later."""
import json, os, shutil, subprocess, sys

FSNAME = {"btrfs": "Btrfs", "ext4": "ext4", "ext3": "ext3", "xfs": "XFS", "vfat": "FAT32",
          "exfat": "exFAT", "ntfs": "NTFS", "ntfs3": "NTFS", "f2fs": "F2FS"}
SKIP_MP = ("/boot", "/efi", "[SWAP]", "/var/lib", "/snap")

def pick_mount(mps):
    mps = [m for m in (mps or []) if m]
    if "/" in mps:
        return "/"
    for m in mps:
        if not m.startswith(SKIP_MP):
            return m
    return ""

def drives():
    out = subprocess.run(["lsblk", "-J", "-b", "-o",
        "NAME,PATH,PKNAME,LABEL,FSTYPE,MOUNTPOINTS,RM,TRAN,ROTA,TYPE"],
        capture_output=True, text=True, timeout=8).stdout
    devs = json.loads(out).get("blockdevices", [])
    flat, seen, res = [], set(), []
    def walk(d, parent):
        d["_parent"] = parent
        flat.append(d)
        for c in d.get("children") or []:
            walk(c, d)
    for d in devs:
        walk(d, None)
    for d in flat:
        if d.get("type") in ("loop", "rom") or not d.get("fstype"):
            continue
        mp = pick_mount(d.get("mountpoints"))
        if not mp or d["path"] in seen:
            continue
        seen.add(d["path"])
        top = d["_parent"] or d
        while top["_parent"]:
            top = top["_parent"]
        tran = (top.get("tran") or "")
        removable = tran == "usb" or str(top.get("rm")).lower() in ("1", "true")
        rota = str(top.get("rota")).lower() in ("1", "true")
        try:
            u = shutil.disk_usage(mp)
        except OSError:
            continue
        fs = FSNAME.get(d["fstype"], d["fstype"])
        if removable:
            kind = "USB drive, " + fs
        else:
            kind = ("Internal HDD, " if rota else "Internal SSD, ") + fs
        name = d.get("label") or ("System" if mp == "/" else os.path.basename(mp.rstrip("/")) or mp)
        res.append({"dev": d["path"], "disk": top["path"], "name": name, "kind": kind,
                    "mount": mp, "removable": removable, "total": u.total, "used": u.used,
                    "free": u.free})
    if not res:  # no block-device info (container, odd setup): show the root filesystem
        u = shutil.disk_usage("/")
        res.append({"dev": "", "disk": "", "name": "System", "kind": "Internal, root filesystem",
                    "mount": "/", "removable": False, "total": u.total, "used": u.used, "free": u.free})
    res.sort(key=lambda r: (r["mount"] != "/", r["removable"], r["name"]))
    return res

def count(p):
    try:
        return sum(1 for e in os.scandir(p) if not e.name.startswith("."))
    except OSError:
        return 0

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "drives":
        fixture = os.environ.get("TRAIL_DRIVES_JSON")  # test fixture for screenshots
        if fixture:
            print(open(fixture).read())
        else:
            print(json.dumps(drives()))
    elif cmd == "counts":
        print(json.dumps({p: count(p) for p in sys.argv[2:]}))
    elif cmd == "eject" and len(sys.argv) == 3 and sys.argv[2].startswith("/dev/"):
        dev = sys.argv[2]
        r = subprocess.run(["udisksctl", "unmount", "-b", dev], capture_output=True, text=True)
        if r.returncode != 0:
            print(json.dumps({"ok": False, "error": r.stderr.strip()})); return
        disk = dev.rstrip("0123456789")
        if disk.endswith("p"): disk = disk[:-1]
        subprocess.run(["udisksctl", "power-off", "-b", disk], capture_output=True, text=True)
        print(json.dumps({"ok": True}))
    else:
        sys.exit(2)

main()
