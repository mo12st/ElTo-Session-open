#!/usr/bin/env python3
"""Tests for elto-worlds/manager/store.py. No network: a fake fetcher serves
fixture OCS XML and fixture archives.

Run from anywhere:  python3 elto-worlds/tests/test_store.py
"""
import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
STORE_PY = os.path.join(HERE, "..", "manager", "store.py")

spec = importlib.util.spec_from_file_location("elto_store", STORE_PY)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)

OCS_XML = b"""<?xml version="1.0"?>
<ocs><meta><status>ok</status></meta><data>
 <content><id>1001</id><name>Paper Frame</name><summary>calm aurorae</summary>
  <version>1.2</version><personid>maker</personid><license>CC-BY-SA</license>
  <score>78</score><downloads>5400</downloads><preview1>http://x/p.png</preview1>
  <detailpage>http://x/item/1001</detailpage>
  <downloadlink1>http://x/paper.zip</downloadlink1><downloadname1>paper.zip</downloadname1>
  <downloadfiletype1>application/zip</downloadfiletype1><downloadsize1>120</downloadsize1></content>
 <content><id>1002</id><name>Glass Frame</name><summary>shiny</summary>
  <version>0.9</version><personid>other</personid><license>GPL</license>
  <downloadlink1>http://x/glass.tar.gz</downloadlink1><downloadname1>glass.tar.gz</downloadname1>
  </content>
</data></ocs>"""


def make_zip(members):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for name, data in members.items():
            z.writestr(name, data)
    return buf.getvalue()


GOOD_ZIP = make_zip({
    "paper/theme.rc": "[General]\ncolor=#f5f1e6\n",
    "paper/deco.svg": '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
    "paper/preview.png": b"\x89PNG\r\n\x1a\n",
})
SCRIPT_ZIP = make_zip({"evil/run.sh": "#!/bin/sh\n"})
TRAVERSAL_ZIP = make_zip({"../escape.txt": "x"})
EXEC_DESKTOP_ZIP = make_zip({"app/run.desktop": "[Desktop Entry]\nExec=/bin/x\n"})
INERT_DESKTOP_ZIP = make_zip({"app/info.desktop": "[Desktop Entry]\nName=Info\n"})
EVIL_SVG_ZIP = make_zip({"deco.svg": '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'})


def kde_entry(**kw):
    e = {"id": "1001", "title": "Paper Frame", "version": "1.2", "author": "maker",
         "license": "CC-BY-SA", "kind": "data", "category": "window-frame",
         "ocsId": 114, "detailPage": "http://x/item/1001",
         "files": [{"url": "http://x/paper.zip", "name": "paper.zip",
                    "filetype": "application/zip", "size_kb": "120"}]}
    e.update(kw)
    return e


class ParseTest(unittest.TestCase):
    def test_parse_content_list(self):
        items = store.parse_content_list(OCS_XML)
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]["id"], "1001")
        self.assertEqual(items[0]["title"], "Paper Frame")
        self.assertEqual(items[0]["files"][0]["url"], "http://x/paper.zip")
        self.assertEqual(items[0]["license"], "CC-BY-SA")
        self.assertEqual(items[1]["files"][0]["url"], "http://x/glass.tar.gz")

    def test_bad_xml_rejected(self):
        self.assertRaises(store.StoreError, store.parse_content_list, b"<ocs><data>")


class ListingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.calls = []

        def fetcher(url, **kw):
            self.calls.append(url)
            if "categories=" in url:
                return OCS_XML
            raise OSError("no network in tests")

        self.store = store.Store(root=self.tmp.name, fetcher=fetcher)

    def tearDown(self):
        self.tmp.cleanup()

    def test_listing_marks_data_kind(self):
        items = self.store.kde_listing("window-frame")
        # window-frame maps to OCS 114 and 717, two entries each
        self.assertEqual(len(items), 4)
        self.assertTrue(all(i["kind"] == "data" for i in items))
        self.assertEqual({i["ocsId"] for i in items}, {114, 717})
        self.assertTrue(all(i["category"] == "window-frame" for i in items))

    def test_code_category_is_listing_only(self):
        items = self.store.kde_listing("greeter")
        self.assertTrue(all(i["kind"] == "code" for i in items))

    def test_cache_fallback_when_store_down(self):
        self.store.kde_listing("greeter")  # fills cache for 101
        def down(url, **kw):
            raise OSError("store down")
        s2 = store.Store(root=self.tmp.name, fetcher=down)
        items = s2.kde_listing("greeter")
        self.assertTrue(all(i["stale"] for i in items))

    def test_no_cache_reports_unavailable(self):
        def down(url, **kw):
            raise OSError("store down")
        s2 = store.Store(root=tempfile.mkdtemp(), fetcher=down)
        self.assertRaises(store.StoreError, s2.kde_listing, "greeter")


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.payload = {"http://x/paper.zip": GOOD_ZIP}

        def fetcher(url, **kw):
            if url in self.payload:
                return self.payload[url]
            raise OSError("no network in tests")

        self.fetcher = fetcher
        self.store = store.Store(root=self.tmp.name, fetcher=fetcher)

    def tearDown(self):
        self.tmp.cleanup()

    def test_install_data_item(self):
        dest = self.store.install_kde(kde_entry())
        self.assertTrue(os.path.isfile(os.path.join(dest, "part.json")))
        part = json.load(open(os.path.join(dest, "part.json")))
        self.assertEqual(part["kind"], "data")
        self.assertEqual(part["sourceSha256"], store.sha256(GOOD_ZIP))
        self.assertIn("paper/theme.rc", part["files"])
        items = self.store.list_installed()
        self.assertEqual(len(items), 1)
        self.assertTrue(items[0]["enabled"])

    def test_code_item_refused_before_download(self):
        e = kde_entry(kind="code")
        self.assertRaises(store.StoreError, self.store.install_kde, e)

    def test_script_archive_refused(self):
        self.payload["http://x/paper.zip"] = SCRIPT_ZIP
        self.assertRaises(store.StoreError, self.store.install_kde, kde_entry())

    def test_traversal_refused(self):
        self.payload["http://x/paper.zip"] = TRAVERSAL_ZIP
        self.assertRaises(store.StoreError, self.store.install_kde, kde_entry())

    def test_exec_desktop_refused(self):
        self.payload["http://x/paper.zip"] = EXEC_DESKTOP_ZIP
        self.assertRaises(store.StoreError, self.store.install_kde, kde_entry())

    def test_inert_desktop_allowed(self):
        self.payload["http://x/paper.zip"] = INERT_DESKTOP_ZIP
        dest = self.store.install_kde(kde_entry())
        self.assertTrue(os.path.isdir(dest))

    def test_evil_svg_refused(self):
        self.payload["http://x/paper.zip"] = EVIL_SVG_ZIP
        self.assertRaises(store.StoreError, self.store.install_kde, kde_entry())

    def test_checksum_change_for_pinned_version_refused(self):
        self.store.install_kde(kde_entry())
        self.payload["http://x/paper.zip"] = make_zip({"paper/theme.rc": "changed"})
        self.assertRaises(store.StoreError, self.store.install_kde, kde_entry())

    def test_failed_install_leaves_no_staging(self):
        self.payload["http://x/paper.zip"] = SCRIPT_ZIP
        try:
            self.store.install_kde(kde_entry())
        except store.StoreError:
            pass
        tmpdir = os.path.join(self.tmp.name, "tmp")
        self.assertEqual(os.listdir(tmpdir), [])
        self.assertEqual(self.store.list_installed(), [])

    def test_enable_disable_remove(self):
        self.store.install_kde(kde_entry())
        key = self.store.list_installed()[0]["key"]
        self.store.set_enabled(key, False)
        self.assertFalse(self.store.list_installed()[0]["enabled"])
        self.store.set_enabled(key, True)
        self.store.remove(key)
        self.assertEqual(self.store.list_installed(), [])

    def test_remove_unknown_raises(self):
        self.assertRaises(store.StoreError, self.store.remove, "nope")


class FunctionsTest(unittest.TestCase):
    def test_listing_only(self):
        items = store.list_functions()
        self.assertTrue(items)
        for it in items:
            self.assertTrue(it["listingOnly"])
            self.assertEqual(it["kind"], "code")
            self.assertTrue(it["url"].startswith("http"))


# ---------------------------------------------------------------- rices

def make_targz(members, root="owner-repo-deadbee"):
    import tarfile
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tf:
        for name, data in members.items():
            data = data.encode() if isinstance(data, str) else data
            info = tarfile.TarInfo("%s/%s" % (root, name))
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
    return buf.getvalue()


RICE_FILES = {
    "LICENSE": "GPL-3.0 text\n",
    "aurorae/paper/paperrc": "[General]\ncolor=#f5f1e6\n",
    "aurorae/paper/deco.svg": '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
    "color-schemes/Paper.colors": "[General]\nName=Paper\n",
    "wallpaper/paper/contents/metadata.desktop": "[Desktop Entry]\nName=Paper\n",
    "wallpaper/paper/contents/images/1.png": b"\x89PNG\r\n\x1a\n",
}
RICE_TAR = make_targz(RICE_FILES)


def rice_manifest(tmpdir, files=None):
    files = files or RICE_FILES
    mfiles = []
    for rel, data in sorted(files.items()):
        data = data.encode() if isinstance(data, str) else data
        mfiles.append({"path": rel, "sha256": store.sha256(data), "size": len(data)})
    m = {"format": "eltoricefiles/1", "id": "test-rice", "commit": "c" * 40,
         "subsetDirs": ["aurorae"], "fileCount": len(mfiles),
         "totalBytes": sum(f["size"] for f in mfiles), "files": mfiles}
    path = os.path.join(tmpdir, "test-rice.files.json")
    with open(path, "w") as f:
        json.dump(m, f)
    return path


def rice_cards(tmpdir, manifest_path, **kw):
    card = {"id": "test-rice", "label": "Test Rice", "author": "maker",
            "license": "GPL-3.0", "tier": "A", "curated": True,
            "commit": "c" * 40, "repo": "owner/repo",
            "manifest": manifest_path, "version": "2026-01-01",
            "upstream": "https://github.com/owner/repo",
            "applies": ["window frames (Aurorae)"], "linksOnly": ["global theme (QML)"]}
    card.update(kw)
    path = os.path.join(tmpdir, "rices.json")
    with open(path, "w") as f:
        json.dump([card], f)
    return path


class RiceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.payload = {"https://codeload.github.com/owner/repo/tar.gz/" + "c" * 40: RICE_TAR}

        def fetcher(url, **kw):
            if url in self.payload:
                return self.payload[url]
            raise OSError("no network in tests")

        self.store = store.Store(root=os.path.join(self.tmp.name, "data"), fetcher=fetcher)
        self.old_rices = store.RICES_JSON
        store.RICES_JSON = rice_cards(self.tmp.name, rice_manifest(self.tmp.name))

    def tearDown(self):
        store.RICES_JSON = self.old_rices
        self.tmp.cleanup()

    def test_cards_flag_installable_vs_listing(self):
        items = store.list_rices()
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["kind"], "data")
        self.assertNotIn("listingOnly", items[0])

    def test_install_happy_path(self):
        dest = self.store.install_rice("test-rice")
        self.assertTrue(os.path.isfile(os.path.join(dest, "part.json")))
        part = json.load(open(os.path.join(dest, "part.json")))
        self.assertEqual(part["source"], "github-rice")
        self.assertEqual(part["category"], "rices")
        self.assertEqual(part["pinnedCommit"], "c" * 40)
        self.assertEqual(part["license"], "GPL-3.0")
        self.assertIn("aurorae/paper/paperrc", part["files"])
        self.assertTrue(os.path.isfile(os.path.join(dest, "LICENSE")))
        reg = self.store.list_installed()
        self.assertEqual(len(reg), 1)
        self.assertEqual(reg[0]["key"], "rice-test-rice")
        self.assertEqual(reg[0]["pinnedCommit"], "c" * 40)

    def test_sha_drift_refused(self):
        bad = dict(RICE_FILES)
        bad["LICENSE"] = "tampered\n"
        self.payload[list(self.payload)[0]] = make_targz(bad)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")
        self.assertEqual(self.store.list_installed(), [])

    def test_missing_member_refused(self):
        bad = {k: v for k, v in RICE_FILES.items() if k != "LICENSE"}
        self.payload[list(self.payload)[0]] = make_targz(bad)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")

    def test_uncurated_refused_before_download(self):
        store.RICES_JSON = rice_cards(self.tmp.name, rice_manifest(self.tmp.name),
                                      curated=False)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")

    def test_unknown_rice_refused(self):
        self.assertRaises(store.StoreError, self.store.install_rice, "nope")

    def test_code_in_manifest_refused(self):
        bad = dict(RICE_FILES)
        bad["tools/run.sh"] = "#!/bin/sh\n"
        store.RICES_JSON = rice_cards(self.tmp.name, rice_manifest(self.tmp.name, bad))
        self.payload[list(self.payload)[0]] = make_targz(bad)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")

    def test_evil_svg_member_refused(self):
        bad = dict(RICE_FILES)
        bad["aurorae/paper/deco.svg"] = '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'
        store.RICES_JSON = rice_cards(self.tmp.name, rice_manifest(self.tmp.name, bad))
        self.payload[list(self.payload)[0]] = make_targz(bad)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")

    def test_manifest_commit_mismatch_refused(self):
        store.RICES_JSON = rice_cards(self.tmp.name, rice_manifest(self.tmp.name),
                                      commit="d" * 40)
        self.assertRaises(store.StoreError, self.store.install_rice, "test-rice")


class ShippedRicesTest(unittest.TestCase):
    """The repo's own rices.json and manifests stay in sync."""

    def test_shipped_cards_and_manifests(self):
        items = store.list_rices()
        self.assertGreaterEqual(len(items), 3)
        curated = [i for i in items if i.get("curated")]
        self.assertEqual(len(curated), 3)
        for it in items:
            self.assertTrue(it["upstream"].startswith("https://github.com/"))
            self.assertTrue(it["license"])
            if it.get("curated"):
                mpath = os.path.join(os.path.dirname(STORE_PY), it["manifest"])
                self.assertTrue(os.path.isfile(mpath), it["id"])
                m = json.load(open(mpath))
                self.assertEqual(m["format"], "eltoricefiles/1")
                self.assertEqual(m["commit"], it["commit"])
                self.assertEqual(m["fileCount"], len(m["files"]))
                self.assertTrue(any(f["path"].split("/")[-1].startswith("LICENSE")
                                    or f["path"] == "COPYING" for f in m["files"]),
                                "license credit missing in %s" % it["id"])
            else:
                self.assertTrue(it.get("listingOnly"))




class CliTest(unittest.TestCase):
    """The UI bridge: store.py --cli as a subprocess, JSON on stdout."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = dict(os.environ, XDG_DATA_HOME=self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_cli(self, *args, stdin=None):
        import subprocess
        proc = subprocess.run([sys.executable, STORE_PY, "--cli"] + list(args),
                              input=stdin, capture_output=True, text=True, env=self.env)
        return proc.returncode, json.loads(proc.stdout)

    def test_worlds(self):
        rc, out = self.run_cli("worlds")
        self.assertEqual(rc, 0)
        self.assertTrue(out["ok"])
        self.assertTrue(out["items"])
        self.assertTrue(all(w["kind"] == "data" for w in out["items"]))

    def test_functions(self):
        rc, out = self.run_cli("functions")
        self.assertEqual(rc, 0)
        self.assertTrue(all(i["listingOnly"] for i in out["items"]))

    def test_installed_empty(self):
        rc, out = self.run_cli("installed")
        self.assertEqual(rc, 0)
        self.assertEqual(out["items"], [])

    def test_rices_lists_cards_without_network(self):
        rc, out = self.run_cli("rices")
        self.assertEqual(rc, 0)
        self.assertTrue(out["ok"])
        self.assertTrue(any(i.get("curated") for i in out["items"]))

    def test_kde_unavailable_without_network(self):
        self.env["ELTO_OCS_BASE"] = "http://127.0.0.1:9/ocs"
        rc, out = self.run_cli("kde", "window-frame")
        self.assertEqual(rc, 1)
        self.assertFalse(out["ok"])
        self.assertIn("unavailable", out["error"])

    def test_install_roundtrip_and_remove(self):
        # no network here either: install must fail cleanly, registry untouched
        rc, out = self.run_cli("install", stdin=json.dumps(kde_entry()))
        self.assertEqual(rc, 1)
        self.assertFalse(out["ok"])
        rc, out = self.run_cli("installed")
        self.assertEqual(out["items"], [])

    def test_unknown_command(self):
        rc, out = self.run_cli("frobnicate")
        self.assertEqual(rc, 1)
        self.assertFalse(out["ok"])

    def test_installarg_code_entry_refused(self):
        rc, out = self.run_cli("installarg", json.dumps(kde_entry(kind="code")))
        self.assertEqual(rc, 1)
        self.assertIn("code", out["error"])

    def test_status_command_reports_overlay(self):
        import subprocess
        elto = os.path.join(HERE, "..", "elto-world")
        env = dict(os.environ, XDG_CONFIG_HOME=self.tmp.name)
        proc = subprocess.run([elto, "status"], capture_output=True, text=True, env=env)
        out = json.loads(proc.stdout)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(out["ok"])
        self.assertIsNone(out["world"])
        self.assertEqual(out["options"], {})

    def test_code_entry_refused(self):
        rc, out = self.run_cli("install", stdin=json.dumps(kde_entry(kind="code")))
        self.assertEqual(rc, 1)
        self.assertIn("code", out["error"])

class StoreWorldTest(unittest.TestCase):
    """The ElTo world lifecycle: install copies the repo world into the user
    root and registers it; scanned-but-unregistered worlds still list and
    remove; updates diff installed versions against the catalog. Hermetic:
    a fixture worlds dir, a throwaway root, no network."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.worlds_dir = os.path.join(self.tmp.name, "repo-worlds")
        wdir = os.path.join(self.worlds_dir, "testworld", "assets")
        os.makedirs(wdir)
        with open(os.path.join(wdir, "wallpaper.jpg"), "wb") as f:
            f.write(b"\xff\xd8\xff\xd9")
        with open(os.path.join(self.worlds_dir, "testworld", "world.json"), "w") as f:
            json.dump({"name": "testworld", "id": "testworld", "label": "Test World",
                       "version": 1, "schema_version": 3,
                       "colors": {"a": "#112233"}, "roles": {"surface": "a"}}, f)
        self.root = os.path.join(self.tmp.name, "user-root")
        self.store = store.Store(root=self.root,
                                 fetcher=lambda url, **kw: (_ for _ in ()).throw(OSError("no network")),
                                 worlds_dir=self.worlds_dir)

    def test_install_world_copies_and_registers(self):
        dest = self.store.install_world("testworld")
        self.assertEqual(dest, os.path.join(self.root, "testworld"))
        self.assertTrue(os.path.isfile(os.path.join(dest, "assets", "wallpaper.jpg")))
        items = self.store.list_installed()
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["key"], "world-testworld")
        self.assertEqual(items[0]["version"], "1")
        self.assertEqual(items[0]["source"], "elto")

    def test_install_world_unknown_and_bad_id_refused(self):
        with self.assertRaises(store.StoreError):
            self.store.install_world("nosuch")
        with self.assertRaises(store.StoreError):
            self.store.install_world("../escape")

    def test_world_dir_requires_install(self):
        with self.assertRaises(store.StoreError):
            self.store.world_dir("testworld")
        self.store.install_world("testworld")
        self.assertEqual(self.store.world_dir("testworld"),
                         os.path.join(self.root, "testworld"))

    def test_scanned_world_lists_without_registry(self):
        # a world dropped into the root by elto-world directly: no registry
        # entry, still listed as a real installed item
        shutil.copytree(os.path.join(self.worlds_dir, "testworld"),
                        os.path.join(self.root, "testworld"))
        items = self.store.list_installed()
        self.assertEqual([i["key"] for i in items], ["world-testworld"])

    def test_remove_registered_and_scanned_world(self):
        self.store.install_world("testworld")
        self.store.remove("world-testworld")
        self.assertEqual(self.store.list_installed(), [])
        self.assertFalse(os.path.exists(os.path.join(self.root, "testworld")))
        shutil.copytree(os.path.join(self.worlds_dir, "testworld"),
                        os.path.join(self.root, "testworld"))
        self.store.remove("world-testworld")  # scanned, unregistered
        self.assertFalse(os.path.exists(os.path.join(self.root, "testworld")))
        with self.assertRaises(store.StoreError):
            self.store.remove("world-gone")

    def test_world_updates_diff_against_catalog(self):
        self.store.install_world("testworld")
        catalog = {"worlds": [{"id": "testworld", "label": "Test World", "version": 2}]}
        rows = self.store.world_updates(catalog=catalog)
        self.assertEqual(rows, [{"id": "testworld", "title": "Test World",
                                 "oldV": "1", "newV": "2"}])
        same = {"worlds": [{"id": "testworld", "label": "Test World", "version": 1}]}
        self.assertEqual(self.store.world_updates(catalog=same), [])


if __name__ == "__main__":
    unittest.main()
