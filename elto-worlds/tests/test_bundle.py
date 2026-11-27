"""Run: python3 elto-worlds/tests/test_bundle.py   (stdlib unittest, sandbox only, no VM)"""
import hashlib, json, os, subprocess, sys, tempfile, unittest, zipfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import bundle
from bundle import BundleError
TOOL = os.path.join(HERE, "..", "elto-world")

def sha(b): return hashlib.sha256(b).hexdigest()
PNG = b"\x89PNG\r\n" + bytes(range(60))

def build(path, assets=None, world=None, manifest_mut=None, extra=(), lic="CC0-1.0"):
    assets = {"assets/wallpaper.png": PNG} if assets is None else assets
    w = world or {"name": "demo", "label": "Demo", "options": {"wallpaper": "assets/wallpaper.png"}}
    m = {"format": "elworld/1", "world": w.get("id", w["name"]), "label": "Demo", "schema_version": 3,
         "files": [{"path": k, "sha256": sha(v), "bytes": len(v), "license": lic} for k, v in assets.items()]}
    if manifest_mut: manifest_mut(m)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("manifest.json", json.dumps(m)); z.writestr("world.json", json.dumps(w))
        for k, v in assets.items(): z.writestr(k, v)
        for item in extra:
            if isinstance(item, tuple): z.writestr(*item)
    return path

class T(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp(); self.z = os.path.join(self.d, "x.elworld")
    def rejects(self, text):
        with self.assertRaises(BundleError) as c: bundle.verify(self.z)
        self.assertIn(text, str(c.exception))

    def test_good(self):
        build(self.z); r = bundle.verify(self.z)
        self.assertEqual(r["world"], "demo"); self.assertEqual(r["assets"][0]["license"], "CC0-1.0")
    def test_traversal_names(self):
        for n in ("../e.png", "assets/../../e.png", "/abs.png", "assets\\x.png", "C:/x.png", "assets//x.png"):
            self.assertFalse(bundle.safe_name(n), n)
        build(self.z, extra=[("assets/../../evil.png", b"x")]); self.rejects("unsafe path")
    def test_symlink(self):
        zi = zipfile.ZipInfo("assets/l.png"); zi.external_attr = 0o120777 << 16
        build(self.z, extra=[(zi, b"/etc/passwd")]); self.rejects("symlink")
    def test_scripts(self):
        for n in ("assets/run.sh", "assets/x.PY", "assets/a.desktop", "assets/w.qml"):
            build(self.z, extra=[(n, b"x")]); self.rejects("script or executable")
    def test_odd_type_and_layout(self):
        build(self.z, extra=[("assets/a.bin2", b"x")]); self.rejects("file type not allowed")
        build(self.z, extra=[("install.sh2", b"x")]); self.rejects("unexpected file")
    def test_missing_required(self):
        with zipfile.ZipFile(self.z, "w") as z: z.writestr("world.json", "{}")
        self.rejects("manifest.json")
    def test_checksum_mismatch(self):
        build(self.z, manifest_mut=lambda m: m["files"][0].update(sha256="0" * 64)); self.rejects("checksum mismatch")
    def test_unlisted_asset(self):
        build(self.z, extra=[("assets/b.png", PNG)]); self.rejects("asset not in manifest")
    def test_manifest_missing_file(self):
        build(self.z, manifest_mut=lambda m: m["files"].append({"path": "assets/ghost.png", "sha256": "0" * 64, "bytes": 1, "license": "CC0"}))
        self.rejects("missing from bundle")
    def test_license_required(self):
        build(self.z, lic=""); self.rejects("no license")
        build(self.z, lic="unknown"); self.rejects("no license")
    def test_world_refs_missing(self):
        build(self.z, world={"name": "demo", "options": {"wallpaper": "assets/nope.png"}})
        self.assertIn("nope.png", bundle.verify(self.z)["warnings"][0])  # same as the validator: warn, art may be pending
    def test_wallpaper_forms(self):
        a = {"assets/wallpapers/a.png": PNG}
        for wl in (["assets/wallpapers/a.png"], [{"path": "assets/wallpapers/a.png", "label": "A"}]):
            build(self.z, assets=a, world={"name": "demo", "options": {"wallpapers": wl}})
            r = bundle.verify(self.z); self.assertEqual(r["warnings"], [])
        build(self.z, assets=a, world={"name": "demo", "options": {"wallpapers": [{"path": "assets/wallpapers/zz.png", "label": "Z"}]}})
        self.assertIn("zz.png", bundle.verify(self.z)["warnings"][0])
        build(self.z, assets=a, world={"name": "demo", "options": {"wallpapers": [{"path": "assets/../x.png", "label": "Z"}]}})
        self.rejects("unsafe asset path")
    def test_world_unsafe_ref(self):
        build(self.z, world={"name": "demo", "options": {"wallpaper": "assets/../../x"}}); self.rejects("unsafe asset path")
    def test_bad_names_and_mismatch(self):
        build(self.z, world={"name": "../x"}, assets={}); self.rejects("bad or missing name")
        build(self.z, manifest_mut=lambda m: m.update(world="other")); self.rejects("does not match")
    def test_bad_format(self):
        build(self.z, manifest_mut=lambda m: m.update(format="elworld/9")); self.rejects("unknown bundle format")
    def test_bomb(self):
        big = b"\0" * 5_000_000
        build(self.z, assets={"assets/wallpaper.png": big}); self.rejects("compression ratio")
    def test_header_lies_about_size(self):
        build(self.z); data = bytearray(open(self.z, "rb").read())
        open(self.z, "wb").write(bytes(data[:len(data) // 2]))  # truncated zip
        with self.assertRaises(Exception): bundle.verify(self.z)
    def test_limits(self):
        build(self.z)
        old = bundle.MAX_FILES; bundle.MAX_FILES = 1
        try: self.rejects("too many files")
        finally: bundle.MAX_FILES = old
        old = bundle.MAX_ASSET; bundle.MAX_ASSET = 10
        try: self.rejects("over 10 bytes")
        finally: bundle.MAX_ASSET = old
        old = bundle.MAX_BYTES; bundle.MAX_BYTES = 50
        try: self.rejects("uncompressed size")
        finally: bundle.MAX_BYTES = old
    def test_svg(self):
        build(self.z, assets={"assets/wallpaper.png": PNG, "assets/a.svg": b"<svg><script>1</script></svg>"}); self.rejects("svg")
        build(self.z, assets={"assets/wallpaper.png": PNG, "assets/a.svg": b"<svg onload='x()'/>"}); self.rejects("svg")
        build(self.z, assets={"assets/wallpaper.png": PNG, "assets/a.svg": b"<svg xmlns='http://www.w3.org/2000/svg'><path d='M0 0'/></svg>"}); bundle.verify(self.z)
    def test_case_collision(self):
        build(self.z, assets={"assets/wallpaper.png": PNG, "assets/A.png": b"1", "assets/a.png": b"2"}); self.rejects("differ only by case")
    def test_unpack_refuses_existing_and_leaves_no_stage(self):
        build(self.z); dest = os.path.join(self.d, "out"); os.makedirs(dest)
        with self.assertRaises(BundleError): bundle.unpack(self.z, dest)
        self.assertEqual(os.listdir(dest), [])
        self.assertEqual([n for n in os.listdir(self.d) if n.startswith(".elworld-stage")], [])
    def test_failed_validate_cleans(self):
        build(self.z); dest = os.path.join(self.d, "out")
        with self.assertRaises(BundleError): bundle.unpack(self.z, dest, lambda w, s: ["nope"])
        self.assertFalse(os.path.exists(dest))
        self.assertEqual([n for n in os.listdir(self.d) if n.startswith(".elworld-stage")], [])
    def test_install_never_overwrites(self):
        build(self.z); st = os.path.join(self.d, "store")
        bundle.install(self.z, st)
        mine = os.path.join(st, "demo", "mine.txt"); open(mine, "w").write("keep")
        with self.assertRaises(BundleError): bundle.install(self.z, st)
        self.assertTrue(os.path.exists(mine))
        r = bundle.install(self.z, st, replace=True)
        self.assertTrue(os.path.exists(os.path.join(r["backup"], "mine.txt")))
        self.assertFalse(os.path.exists(mine))
        self.assertEqual(sorted(os.listdir(st)), sorted(["demo", os.path.basename(r["backup"])]))
    def test_bad_bundle_installs_nothing(self):
        build(self.z, extra=[("assets/x.sh", b"x")]); st = os.path.join(self.d, "store")
        with self.assertRaises(BundleError): bundle.install(self.z, st)
        self.assertEqual(os.listdir(st) if os.path.isdir(st) else [], [])

class CLI(unittest.TestCase):
    """End to end through the real elto-world tool, in a sandbox HOME. Not a VM test."""
    def run_tool(self, *a):
        env = dict(os.environ, HOME=self.h, XDG_DATA_HOME=self.h + "/data", XDG_CONFIG_HOME=self.h + "/cfg")
        p = subprocess.run([sys.executable, TOOL] + list(a), capture_output=True, text=True, env=env)
        return p.returncode, (json.loads(p.stdout) if p.stdout.strip() else {})
    def setUp(self):
        self.h = tempfile.mkdtemp()
        self.w = os.path.join(self.h, "world"); os.makedirs(self.w + "/assets")
        src = json.load(open(os.path.join(HERE, "..", "worlds", "classic", "world.json")))
        src["name"] = src["id"] = "demo"; src["options"] = {"wallpaper": "assets/wallpaper.png"}
        src.setdefault("defaults", {}).pop("wallpaper", None)
        src["assetsLicense"] = "CC0-1.0"
        json.dump(src, open(self.w + "/world.json", "w")); open(self.w + "/assets/wallpaper.png", "wb").write(PNG)
        self.b = os.path.join(self.h, "demo.elworld")
    def test_pack_inspect_install_flow(self):
        rc, o = self.run_tool("pack", self.w, self.b); self.assertEqual(rc, 0, o)
        rc, o = self.run_tool("inspect", self.b); self.assertEqual(rc, 0, o); self.assertEqual(o["world"], "demo")
        rc, o = self.run_tool("install", self.b); self.assertEqual(rc, 0, o)
        self.assertTrue(os.path.isfile(self.h + "/data/elto/worlds/demo/world.json"))
        rc, o = self.run_tool("install", self.b); self.assertEqual(rc, 1)
        rc, o = self.run_tool("install", self.b, "--replace"); self.assertEqual(rc, 0); self.assertTrue(o["backup"])
        rc, o = self.run_tool("unpack", self.b, self.h + "/data/elto/worlds/demo"); self.assertEqual(rc, 1)

if __name__ == "__main__": unittest.main()
