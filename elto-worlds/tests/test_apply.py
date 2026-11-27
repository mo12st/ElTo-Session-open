#!/usr/bin/env python3
"""Sandbox tests for elto-world apply/reset wallpaper handling.

Regression: applying or resetting a world whose wallpaper asset is missing
used to write options.wallpaper pointing at a file that was never installed,
turning the desktop blank. The overlay may only point at a wallpaper the
same run actually installed (as the basename the shell looks up in
~/.config/elto/wallpapers/); otherwise the existing value is kept with a
warning.

Run from anywhere:  python3 elto-worlds/tests/test_apply.py
Uses a throwaway HOME/XDG sandbox; touches nothing outside it.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ELTO_WORLD = os.path.join(HERE, "..", "elto-world")

WORLD = {
    "name": "testworld",
    "label": "Test World",
    "version": 2,
    "schema_version": 3,
    "id": "testworld",
    "colors": {
        "paper": "#f5f1e6", "ink": "#2b2b26", "muted": "#8a8578",
        "accent": "#3e6b4f", "sel": "#d8e2d5", "line": "#c9c2b2",
        "dis": "#b5b0a2", "alt": "#ece7d9",
    },
    "roles": {
        "surface": "paper", "surfaceAlt": "alt", "text": "ink",
        "textMuted": "muted", "accent": "accent", "selection": "sel",
        "divider": "line", "disabled": "dis",
    },
    "defaults": {
        "wallpaper": "assets/wallpapers/main.jpg",
        "dock": "island", "notch": "clock", "notchMode": "show", "sounds": False,
    },
    "options": {
        "wallpapers": [{"path": "assets/wallpapers/main.jpg", "label": "Main"}],
    },
    "sounds": {"enabled": False, "events": {}},
    "kde": {"colorscheme": {"generate": False}},
}


class ApplyWallpaperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.env = dict(os.environ)
        self.env["HOME"] = root
        self.env["XDG_CONFIG_HOME"] = os.path.join(root, ".config")
        self.env["XDG_DATA_HOME"] = os.path.join(root, ".local", "share")
        self.env["XDG_STATE_HOME"] = os.path.join(root, ".local", "state")
        self.env.pop("ELTO_THEME", None)
        self.wdir = os.path.join(root, "testworld")
        os.makedirs(self.wdir)
        with open(os.path.join(self.wdir, "world.json"), "w") as f:
            json.dump(WORLD, f)
        self.overlay = os.path.join(self.env["XDG_CONFIG_HOME"], "elto", "theme.json")

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args):
        proc = subprocess.run([ELTO_WORLD] + list(args),
                              capture_output=True, text=True, env=self.env)
        try:
            return proc.returncode, json.loads(proc.stdout)
        except json.JSONDecodeError:
            self.fail("non-JSON output (rc=%d): %s %s" % (proc.returncode, proc.stdout, proc.stderr))

    def write_overlay(self, options):
        os.makedirs(os.path.dirname(self.overlay), exist_ok=True)
        with open(self.overlay, "w") as f:
            json.dump({"name": "whatever", "options": options}, f)

    def read_overlay(self):
        with open(self.overlay) as f:
            return json.load(f)

    def add_wallpaper_asset(self):
        asset_dir = os.path.join(self.wdir, "assets", "wallpapers")
        os.makedirs(asset_dir)
        with open(os.path.join(asset_dir, "main.jpg"), "wb") as f:
            f.write(b"\xff\xd8\xff\xd9")

    def test_missing_asset_keeps_existing_wallpaper(self):
        self.write_overlay({"wallpaper": "my-old.jpg"})
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        opts = self.read_overlay()["options"]
        self.assertEqual(opts.get("wallpaper"), "my-old.jpg")
        self.assertTrue(any("not installed" in w and "my-old.jpg" in w
                            for w in out["warnings"]), out["warnings"])

    def test_missing_asset_fresh_overlay_sets_nothing(self):
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        opts = self.read_overlay()["options"]
        self.assertNotIn("wallpaper", opts)
        self.assertTrue(any("not installed" in w for w in out["warnings"]), out["warnings"])

    def test_installed_asset_sets_basename(self):
        self.add_wallpaper_asset()
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        opts = self.read_overlay()["options"]
        self.assertEqual(opts.get("wallpaper"), "main.jpg")
        installed = os.path.join(self.env["XDG_CONFIG_HOME"], "elto", "wallpapers", "main.jpg")
        self.assertTrue(os.path.isfile(installed))

    def test_reset_missing_asset_keeps_user_pick(self):
        self.add_wallpaper_asset()
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.read_overlay()["options"].get("wallpaper"), "main.jpg")
        # user overrides the wallpaper, then the asset disappears from the world dir
        overlay = self.read_overlay()
        overlay["options"]["wallpaper"] = "user-pick.jpg"
        self.write_overlay(overlay["options"])
        os.remove(os.path.join(self.wdir, "assets", "wallpapers", "main.jpg"))
        rc, out = self.cli("reset", self.wdir)
        self.assertEqual(rc, 0, out)
        opts = self.read_overlay()["options"]
        self.assertEqual(opts.get("wallpaper"), "user-pick.jpg")
        self.assertTrue(any("not installed" in w and "user-pick.jpg" in w
                            for w in out["warnings"]), out["warnings"])


if __name__ == "__main__":
    unittest.main()
