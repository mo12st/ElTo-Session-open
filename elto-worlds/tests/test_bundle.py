#!/usr/bin/env python3
"""Bundle security tests for elto-world pack/unpack.

Bundles are data-only (user decision, option 1): no scripts, no QML, no
executables; traversal and absolute paths rejected; checksums enforced.

Run from anywhere:  python3 elto-worlds/tests/test_bundle.py
"""
import json
import os
import subprocess
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ELTO_WORLD = os.path.join(HERE, "..", "elto-world")

WORLD = {
    "name": "packworld", "label": "Pack World", "version": 2,
    "schema_version": 3, "id": "packworld",
    "colors": {"paper": "#f5f1e6", "ink": "#2b2b26", "muted": "#8a8578",
               "accent": "#3e6b4f", "sel": "#d8e2d5", "line": "#c9c2b2",
               "dis": "#b5b0a2", "alt": "#ece7d9"},
    "roles": {"surface": "paper", "surfaceAlt": "alt", "text": "ink",
              "textMuted": "muted", "accent": "accent", "selection": "sel",
              "divider": "line", "disabled": "dis"},
    "license": "Proprietary (all rights reserved, mo12st)",
    "assetsLicense": "Proprietary (all rights reserved, mo12st)",
    "defaults": {"wallpaper": "assets/wallpapers/main.jpg", "sounds": False},
}


class BundleSecurityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.wdir = os.path.join(self.tmp.name, "packworld")
        os.makedirs(self.wdir)
        with open(os.path.join(self.wdir, "world.json"), "w") as f:
            json.dump(WORLD, f)

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args):
        proc = subprocess.run([ELTO_WORLD] + list(args),
                              capture_output=True, text=True)
        try:
            return proc.returncode, json.loads(proc.stdout)
        except json.JSONDecodeError:
            self.fail("non-JSON output (rc=%d): %s %s" % (proc.returncode, proc.stdout, proc.stderr))

    def test_pack_refuses_qml(self):
        os.makedirs(os.path.join(self.wdir, "assets"))
        with open(os.path.join(self.wdir, "assets", "theme.qml"), "w") as f:
            f.write("import QtQuick\nItem {}\n")
        rc, out = self.cli("pack", self.wdir, os.path.join(self.tmp.name, "x.elworld"))
        self.assertEqual(rc, 1)
        self.assertTrue(any("qml" in e.lower() or "script" in e.lower() or "executable" in e.lower()
                            for e in out["errors"]), out["errors"])

    def test_unpack_rejects_qml_in_bundle(self):
        bundle = os.path.join(self.tmp.name, "evil.elworld")
        with zipfile.ZipFile(bundle, "w") as z:
            z.writestr("world.json", json.dumps(WORLD))
            z.writestr("manifest.json", json.dumps({"format": "elworld/1", "files": []}))
            z.writestr("assets/theme.qml", "import QtQuick\nItem {}\n")
        rc, out = self.cli("unpack", bundle, os.path.join(self.tmp.name, "out"))
        self.assertEqual(rc, 1)
        self.assertTrue(any("script" in e.lower() or "executable" in e.lower()
                            for e in out["errors"]), out["errors"])
        self.assertFalse(os.path.exists(os.path.join(self.tmp.name, "out", "assets", "theme.qml")))

    def test_unpack_rejects_traversal(self):
        bundle = os.path.join(self.tmp.name, "trav.elworld")
        with zipfile.ZipFile(bundle, "w") as z:
            z.writestr("world.json", json.dumps(WORLD))
            z.writestr("manifest.json", json.dumps({"format": "elworld/1", "files": []}))
            z.writestr("../../../tmp/escape.txt", "x")
        rc, out = self.cli("unpack", bundle, os.path.join(self.tmp.name, "out2"))
        self.assertEqual(rc, 1)
        self.assertTrue(any("unsafe" in e.lower() for e in out["errors"]), out["errors"])

    def test_roundtrip_clean_world(self):
        rc, out = self.cli("pack", self.wdir, os.path.join(self.tmp.name, "ok.elworld"))
        self.assertEqual(rc, 0, out)
        rc, out = self.cli("unpack", os.path.join(self.tmp.name, "ok.elworld"),
                           os.path.join(self.tmp.name, "rt"))
        self.assertEqual(rc, 0, out)
        rc, out = self.cli("check", os.path.join(self.tmp.name, "rt"))
        self.assertEqual(rc, 0, out)


if __name__ == "__main__":
    unittest.main()
