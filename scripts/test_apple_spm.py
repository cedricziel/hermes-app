import tempfile
from pathlib import Path
import unittest

from check_apple_spm import missing_spm


class AppleSpmTest(unittest.TestCase):
    def test_cocoapods_only_plugin_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            manifest = {"plugins": {"ios": [{"name": "audio", "path": root}]}}
            self.assertEqual(missing_spm(manifest), ["ios: audio"])
            package = Path(root) / "ios/audio/Package.swift"
            package.parent.mkdir(parents=True)
            package.touch()
            self.assertEqual(missing_spm(manifest), [])

    def test_dart_only_plugins_need_no_native_package(self):
        manifest = {"plugins": {"macos": [{"name": "paths", "path": "/unused", "native_build": False}]}}
        self.assertEqual(missing_spm(manifest), [])

    def test_shared_darwin_package(self):
        with tempfile.TemporaryDirectory() as root:
            package = Path(root) / "darwin/shared/Package.swift"
            package.parent.mkdir(parents=True)
            package.touch()
            plugin = {"name": "shared", "path": root, "shared_darwin_source": True}
            self.assertEqual(missing_spm({"plugins": {"ios": [plugin], "macos": [plugin]}}), [])
