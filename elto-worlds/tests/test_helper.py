#!/usr/bin/env python3
"""Tests for elto-worlds/helper/elto-worlds-helper. No root, no pkexec:
the validation and install functions are exercised directly with temp dirs,
with the caller uid faked as the current user.

Run from anywhere:  python3 elto-worlds/tests/test_helper.py
"""
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "helper", "elto-worlds-helper")

loader = importlib.machinery.SourceFileLoader("elto_helper", HELPER)
spec = importlib.util.spec_from_loader("elto_helper", loader)
helper = importlib.util.module_from_spec(spec)
loader.exec_module(helper)

UID = os.getuid()


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = os.path.join(self.tmp.name, "home", "user")
        self.source_root = os.path.join(self.home, ".local", "share", "elto", "worlds")
        self.dest_root = os.path.join(self.tmp.name, "usr", "share", "elto", "worlds")
        os.makedirs(self.source_root)
        os.makedirs(self.dest_root)

    def _src(self, rel, data=b"x"):
        path = os.path.join(self.source_root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        return path

    def _manifest(self, entries):
        path = os.path.join(self.tmp.name, "m.json")
        with open(path, "w") as f:
            json.dump({"files": entries}, f)
        return path

    # caller_uid

    def test_caller_uid_requires_pkexec(self):
        with self.assertRaises(helper.Refusal):
            helper.caller_uid(env={})

    def test_caller_uid_parses(self):
        self.assertEqual(helper.caller_uid(env={"PKEXEC_UID": "1000"}), 1000)

    # source root confinement

    def test_source_root_outside_home_refused(self):
        with mock.patch.object(helper, "caller_home", return_value=self.home):
            with self.assertRaises(helper.Refusal):
                helper.validate_source_root("/etc", UID)

    def test_source_root_under_home_ok(self):
        with mock.patch.object(helper, "caller_home", return_value=self.home):
            self.assertEqual(helper.validate_source_root(self.source_root, UID),
                             os.path.realpath(self.source_root))

    # source validation

    def test_source_escape_refused(self):
        self._src("ok.png")
        with self.assertRaises(helper.Refusal):
            helper.validate_source("../../etc/passwd", self.source_root, UID)

    def test_source_symlink_escape_refused(self):
        outside = os.path.join(self.tmp.name, "secret.txt")
        with open(outside, "w") as f:
            f.write("s")
        os.symlink(outside, os.path.join(self.source_root, "link.txt"))
        with self.assertRaises(helper.Refusal):
            helper.validate_source("link.txt", self.source_root, UID)

    def test_source_owned_by_other_refused(self):
        # the file is owned by the current user; claiming the caller is a
        # different uid must be refused on ownership grounds
        self._src("mine.png")
        with self.assertRaises(helper.Refusal) as cm:
            helper.validate_source("mine.png", self.source_root, UID + 1)
        self.assertIn("owned by", str(cm.exception))

    def test_source_directory_refused(self):
        os.makedirs(os.path.join(self.source_root, "adir"))
        with self.assertRaises(helper.Refusal):
            helper.validate_source("adir", self.source_root, UID)

    # destination validation

    def test_dest_escape_refused(self):
        for bad in ("../x", "a/../../x", "/abs/x"):
            with self.assertRaises(helper.Refusal, msg=bad):
                helper.validate_dest(bad, self.dest_root)

    def test_dest_root_itself_refused(self):
        with self.assertRaises(helper.Refusal):
            helper.validate_dest(".", self.dest_root)

    def test_dest_ok(self):
        self.assertEqual(
            helper.validate_dest("meadow/wallpaper.jpg", self.dest_root),
            os.path.join(os.path.realpath(self.dest_root), "meadow", "wallpaper.jpg"))

    # manifest authorization

    def test_manifest_shape(self):
        with self.assertRaises(helper.Refusal):
            helper.load_manifest(self._manifest([]), UID)
        bad = os.path.join(self.tmp.name, "bad.json")
        with open(bad, "w") as f:
            f.write("not json")
        with self.assertRaises(helper.Refusal):
            helper.load_manifest(bad, UID)
        entries = helper.load_manifest(
            self._manifest([{"src": "a", "dest": "b"}]), UID)
        self.assertEqual(entries, [("a", "b")])

    def test_manifest_owned_by_other_refused(self):
        with self.assertRaises(helper.Refusal) as cm:
            helper.load_manifest(
                self._manifest([{"src": "a", "dest": "b"}]), UID + 1)
        self.assertIn("owned by", str(cm.exception))

    # install end to end (temp dest root)

    def test_install_copies_validated_files(self):
        self._src("meadow/assets/launcher.png", b"PNG")
        entries = [("meadow/assets/launcher.png", "meadow/launcher.png")]
        installed = helper.install(entries, self.source_root, UID, self.dest_root)
        self.assertEqual(installed, ["meadow/launcher.png"])
        with open(os.path.join(self.dest_root, "meadow", "launcher.png"), "rb") as f:
            self.assertEqual(f.read(), b"PNG")

    def test_install_all_or_nothing(self):
        self._src("ok.png")
        entries = [("ok.png", "ok.png"), ("../escape", "evil.png")]
        with self.assertRaises(helper.Refusal):
            helper.install(entries, self.source_root, UID, self.dest_root)
        self.assertEqual(os.listdir(self.dest_root), [])


if __name__ == "__main__":
    unittest.main()
