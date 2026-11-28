#!/usr/bin/env python3
"""Tests for elto-worlds/catalog/build-catalog.py.

Run from anywhere:  python3 elto-worlds/tests/test_catalog.py
"""
import importlib.util
import json
import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
BUILDER = os.path.join(HERE, "..", "catalog", "build-catalog.py")
CATALOG = os.path.join(HERE, "..", "catalog", "catalog.json")
WORLDS = os.path.join(HERE, "..", "worlds")


def load_builder():
    spec = importlib.util.spec_from_file_location("build_catalog", BUILDER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class CatalogBuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_builder()
        cls.catalog = cls.mod.build()

    def test_every_world_dir_is_catalogued(self):
        on_disk = sorted(
            d for d in os.listdir(WORLDS)
            if os.path.isfile(os.path.join(WORLDS, d, "world.json")))
        in_catalog = sorted(w["id"] for w in self.catalog["worlds"])
        self.assertEqual(on_disk, in_catalog)

    def test_every_entry_is_data_kind(self):
        for w in self.catalog["worlds"]:
            self.assertEqual(w["kind"], "data", w["id"])
            self.assertEqual(w["category"], "worlds", w["id"])

    def test_required_entry_fields(self):
        for w in self.catalog["worlds"]:
            for key in ("label", "version", "schema_version", "story",
                        "author", "license", "assetsLicense", "colors",
                        "roles", "parts", "defaults", "source"):
                self.assertIn(key, w, "%s missing %s" % (w["id"], key))
            self.assertTrue(w["story"], "%s has an empty story" % w["id"])
            self.assertTrue(w["parts"], "%s ships no parts" % w["id"])

    def test_colors_and_roles_are_consistent(self):
        for w in self.catalog["worlds"]:
            for cname, cval in w["colors"].items():
                self.assertRegex(cval, r"^#[0-9a-fA-F]{6}$",
                                 "%s color %s" % (w["id"], cname))
            for rname, rval in w["roles"].items():
                self.assertIn(rval, w["colors"],
                              "%s role %s" % (w["id"], rname))

    def test_dock_default_is_valid(self):
        for w in self.catalog["worlds"]:
            self.assertIn(w["defaults"]["dock"], ("island", "bar"), w["id"])

    def test_filemanager_block_not_emitted_yet(self):
        # Pending the user's schema decision; builder flag defaults off.
        self.assertFalse(self.mod.INCLUDE_FILEMANAGER)
        for w in self.catalog["worlds"]:
            self.assertNotIn("filemanager", w, w["id"])

    def test_categories_include_filemanager_category(self):
        ids = [c["id"] for c in self.catalog["categories"]]
        self.assertIn("worlds", ids)
        self.assertIn("filemanager", ids)
        fm = next(c for c in self.catalog["categories"] if c["id"] == "filemanager")
        self.assertEqual(fm.get("status"), "pending-schema")

    def test_output_is_deterministic(self):
        self.assertEqual(self.mod.render(self.mod.build()),
                         self.mod.render(self.mod.build()))

    def test_on_disk_catalog_is_fresh(self):
        with open(CATALOG) as f:
            self.assertEqual(f.read(), self.mod.render(self.catalog),
                             "catalog.json is stale; run build-catalog.py")

    def test_check_mode_passes(self):
        proc = subprocess.run([sys.executable, BUILDER, "--check"],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)


class CatalogValidationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_builder()

    def base_world(self):
        return {
            "name": "testworld", "label": "Test World", "id": "testworld",
            "version": 1, "schema_version": 3, "author": "mo12st",
            "license": "x", "assetsLicense": "x",
            "colors": {"paper": "#f5f1e6", "ink": "#2b2b26"},
            "roles": {"surface": "paper", "text": "ink"},
        }

    def test_clean_world_passes(self):
        self.assertEqual(self.mod.validate_world(self.base_world(), "testworld"), [])

    def test_bad_color_rejected(self):
        w = self.base_world()
        w["colors"]["paper"] = "red"
        self.assertTrue(any("paper" in e for e in self.mod.validate_world(w, "testworld")))

    def test_dangling_role_rejected(self):
        w = self.base_world()
        w["roles"]["accent"] = "nope"
        self.assertTrue(any("accent" in e for e in self.mod.validate_world(w, "testworld")))

    def test_id_dir_mismatch_rejected(self):
        self.assertTrue(self.mod.validate_world(self.base_world(), "otherdir"))

    def test_unknown_dock_value_flagged(self):
        w = self.base_world()
        w["defaults"] = {"dock": "ridge-shelf"}
        self.assertTrue(any("dock" in e for e in self.mod.validate_world(w, "testworld")))


if __name__ == "__main__":
    unittest.main()
