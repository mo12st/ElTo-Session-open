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

    def add_launcher_asset(self):
        asset_dir = os.path.join(self.wdir, "assets")
        os.makedirs(asset_dir, exist_ok=True)
        with open(os.path.join(asset_dir, "launcher.png"), "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n")

    def world_with_dock(self):
        world = dict(WORLD)
        world["dock"] = {"launcherMark": "logo", "launcherLogo": "assets/launcher.png"}
        with open(os.path.join(self.wdir, "world.json"), "w") as f:
            json.dump(world, f)

    def test_launcher_logo_rewritten_absolute(self):
        # Dock.qml resolves relative launcherLogo against the shell root, so
        # apply must write an absolute path into the overlay.
        self.world_with_dock()
        self.add_launcher_asset()
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        dock = self.read_overlay()["dock"]
        self.assertEqual(dock.get("launcherMark"), "logo")
        self.assertEqual(dock.get("launcherLogo"),
                         os.path.join(self.wdir, "assets", "launcher.png"))
        self.assertTrue(os.path.isabs(dock["launcherLogo"]))
        self.assertTrue(os.path.isfile(dock["launcherLogo"]))

    def test_launcher_logo_missing_asset_falls_back_to_label(self):
        self.world_with_dock()
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        dock = self.read_overlay()["dock"]
        self.assertNotIn("launcherLogo", dock)
        self.assertTrue(any("launcherLogo" in w and "label" in w
                            for w in out["warnings"]), out["warnings"])

    def test_launcher_logo_unknown_mark_warns(self):
        world = dict(WORLD)
        world["dock"] = {"launcherMark": "banana"}
        with open(os.path.join(self.wdir, "world.json"), "w") as f:
            json.dump(world, f)
        rc, out = self.cli("apply", self.wdir)
        self.assertEqual(rc, 0, out)
        self.assertTrue(any("launcherMark" in w for w in out["warnings"]), out["warnings"])


# ---------------------------------------------------------------- rice parts

SVG = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>'


def build_rice_dir(root):
    """A fake installed rice dir covering both aurorae layouts."""
    rd = os.path.join(root, "rice")
    def w(rel, content):
        p = os.path.join(rd, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        mode = "wb" if isinstance(content, bytes) else "w"
        with open(p, mode) as f:
            f.write(content)
    w("color-schemes/TestRice.colors", "[General]\nName=TestRice\n")
    # split layout (WhiteSur-style): rc + variant svg dir + common assets
    w("aurorae/main/TestRicerc", "[General]\nActiveTextColor=68,68,68\n")
    w("aurorae/main/TestRice/decoration.svg", SVG)
    w("aurorae/main/TestRice-darkrc", "[General]\nActiveTextColor=240,240,240\n")
    w("aurorae/main/TestRice-dark/decoration.svg", SVG)
    w("aurorae/common/assets/close.svg", SVG)
    w("aurorae/common/assets-dark/close.svg", SVG.replace("rect", "circle"))
    w("aurorae/metadata.desktop", "[Desktop Entry]\nName=TestRice\n")
    w("aurorae/metadata.json", "{}\n")
    # self-contained layout (Graphite-style)
    w("aurorae/Solo/Solorc", "[General]\nActiveTextColor=1,2,3\n")
    w("aurorae/Solo/decoration.svg", SVG)
    w("aurorae/Solo/close.svg", SVG)
    # wallpapers: packaged dir and plain file
    w("wallpaper/TestWp/contents/images/1920x1080.png", b"small")
    w("wallpaper/TestWp/contents/images/2560x1440.png", b"largest-image-bytes")
    w("wallpaper/plain.png", b"plain-image")
    # plasma desktop theme
    w("plasma/desktoptheme/TestTheme/metadata.json", "{}\n")
    w("plasma/desktoptheme/TestTheme/widgets/panel.svg", SVG)
    return rd


class RicePartsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.env = dict(os.environ)
        self.env["HOME"] = root
        self.env["XDG_CONFIG_HOME"] = os.path.join(root, ".config")
        self.env["XDG_DATA_HOME"] = os.path.join(root, ".local", "share")
        self.env["XDG_STATE_HOME"] = os.path.join(root, ".local", "state")
        self.env.pop("ELTO_THEME", None)
        self.rdir = build_rice_dir(root)
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

    def test_parts_lists_every_format(self):
        rc, out = self.cli("parts", self.rdir)
        self.assertEqual(rc, 0, out)
        p = out["parts"]
        self.assertEqual(p["colorschemes"], ["TestRice"])
        self.assertEqual(p["aurorae"], ["Solo", "TestRice", "TestRice-dark"])
        self.assertEqual(p["wallpapers"], ["TestWp", "plain.png"])
        self.assertEqual(p["desktopthemes"], ["TestTheme"])

    def test_apply_colorscheme(self):
        rc, out = self.cli("applypart", self.rdir, "colorscheme", "TestRice")
        self.assertEqual(rc, 0, out)
        dst = os.path.join(self.env["XDG_DATA_HOME"], "color-schemes", "TestRice.colors")
        self.assertTrue(os.path.isfile(dst))
        step = [s for s in out["steps"] if s["step"] == "kde-apply"][0]
        self.assertIn(step["status"], ("done", "failed", "skipped"))  # tool may be absent here

    def test_apply_aurorae_split_layout_light_gets_light_assets(self):
        rc, out = self.cli("applypart", self.rdir, "aurorae", "TestRice")
        self.assertEqual(rc, 0, out)
        theme = os.path.join(self.env["XDG_DATA_HOME"], "aurorae", "themes", "TestRice")
        self.assertTrue(os.path.isfile(os.path.join(theme, "TestRicerc")))
        self.assertTrue(os.path.isfile(os.path.join(theme, "decoration.svg")))
        with open(os.path.join(theme, "close.svg")) as f:
            self.assertIn("rect", f.read())  # from common/assets, not assets-dark
        self.assertTrue(os.path.isfile(os.path.join(theme, "metadata.json")))

    def test_apply_aurorae_dark_variant_gets_dark_assets(self):
        rc, out = self.cli("applypart", self.rdir, "aurorae", "TestRice-dark")
        self.assertEqual(rc, 0, out)
        theme = os.path.join(self.env["XDG_DATA_HOME"], "aurorae", "themes", "TestRice-dark")
        self.assertTrue(os.path.isfile(os.path.join(theme, "TestRice-darkrc")))
        with open(os.path.join(theme, "close.svg")) as f:
            self.assertIn("circle", f.read())  # assets-dark won

    def test_apply_aurorae_self_contained(self):
        rc, out = self.cli("applypart", self.rdir, "aurorae", "Solo")
        self.assertEqual(rc, 0, out)
        theme = os.path.join(self.env["XDG_DATA_HOME"], "aurorae", "themes", "Solo")
        self.assertTrue(os.path.isfile(os.path.join(theme, "Solorc")))
        self.assertTrue(os.path.isfile(os.path.join(theme, "close.svg")))

    def test_apply_wallpaper_sets_overlay(self):
        rc, out = self.cli("applypart", self.rdir, "wallpaper", "TestWp")
        self.assertEqual(rc, 0, out)
        dst = os.path.join(self.env["XDG_CONFIG_HOME"], "elto", "wallpapers", "2560x1440.png")
        self.assertTrue(os.path.isfile(dst))  # largest resolution won
        with open(self.overlay) as f:
            ov = json.load(f)
        self.assertEqual(ov["options"]["wallpaper"], "2560x1440.png")

    def test_apply_desktoptheme_copies_with_honest_note(self):
        rc, out = self.cli("applypart", self.rdir, "desktoptheme", "TestTheme")
        self.assertEqual(rc, 0, out)
        dst = os.path.join(self.env["XDG_DATA_HOME"], "plasma", "desktoptheme",
                           "TestTheme", "widgets", "panel.svg")
        self.assertTrue(os.path.isfile(dst))
        self.assertTrue(any(s["step"] == "desktoptheme-note" for s in out["steps"]))

    def test_bad_part_name_rejected(self):
        rc, out = self.cli("applypart", self.rdir, "wallpaper", "../../etc")
        self.assertEqual(rc, 1)
        self.assertFalse(out["ok"])

    def test_unknown_variant_fails_and_writes_nothing(self):
        rc, out = self.cli("applypart", self.rdir, "aurorae", "Nope")
        self.assertEqual(rc, 1)
        self.assertFalse(out["ok"])
        self.assertFalse(os.path.isdir(os.path.join(self.env["XDG_DATA_HOME"], "aurorae")))


if __name__ == "__main__":
    unittest.main()
