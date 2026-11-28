#!/usr/bin/env python3
"""Tests for elto-worlds/manager/store.py. No network: a fake fetcher serves
fixture OCS XML and fixture archives.

Run from anywhere:  python3 elto-worlds/tests/test_store.py
"""
import importlib.util
import io
import json
import os
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


if __name__ == "__main__":
    unittest.main()
