import importlib.util
import pathlib
import plistlib
import tempfile
import types
import unittest
from unittest.mock import patch

MODULE = pathlib.Path(__file__).parents[1] / 'watch-preflight.py'
spec = importlib.util.spec_from_file_location('watch_preflight', MODULE)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class WatchPreflightTests(unittest.TestCase):
    def test_unverified_fixture_rejected(self):
        with self.assertRaises(ValueError):
            preflight.validate({}, {}, {})

    def test_personal_bundle_rejected(self):
        with self.assertRaisesRegex(ValueError, 'bundle'):
            preflight.validate_identity('com.cedricziel.hermesApp', 'abc')

    def test_fixture_bundle_requires_run_namespace(self):
        with self.assertRaisesRegex(ValueError, 'bundle'):
            preflight.validate_identity('app.hermes.fixture.other.phone', 'abc')

    def test_fixture_bundle_accepted(self):
        preflight.validate_identity('app.hermes.fixture.abc.phone', 'abc')

    def test_unisolated_routing_rejected(self):
        with self.assertRaisesRegex(ValueError, 'routing'):
            preflight.validate_bundle({'CFBundleURLTypes': [{}]}, {})

    def test_shared_app_groups_rejected(self):
        with self.assertRaisesRegex(ValueError, 'groups'):
            preflight.validate_bundle({}, {'com.apple.security.application-groups': ['group.personal']})

    def test_shared_keychain_group_rejected(self):
        with self.assertRaisesRegex(ValueError, 'keychain'):
            preflight.validate_bundle({'CFBundleIdentifier': 'app.hermes.fixture.abc.phone'},
                                      {'keychain-access-groups': ['TEAMID.com.personal.app']})

    def test_shared_icloud_store_rejected(self):
        with self.assertRaisesRegex(ValueError, 'iCloud'):
            preflight.validate_bundle({}, {'com.apple.developer.ubiquity-kvstore-identifier': 'shared'})


class ManifestTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = pathlib.Path(temporary.name) / 'watch-fixture-abc'
        phone = root / 'phone.app'
        watch = root / 'watch.app'
        phone.mkdir(parents=True)
        watch.mkdir()
        (phone / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'app.hermes.fixture.abc.phone'}))
        (watch / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'app.hermes.fixture.abc.watch'}))
        phone_id = '00000000-0000-0000-0000-000000000001'
        watch_id = '00000000-0000-0000-0000-000000000002'
        self.manifest = {
            'run_id': 'abc', 'fixture_root': str(root), 'backend_home': str(root / 'home'),
            'credentials': 'synthetic', 'storage_review': 'fresh-pair-no-host-storage',
            'routing_review': 'disabled',
            'phone': {'udid': phone_id, 'app': str(phone), 'created_for_run': True,
                      'empty_before_install': True, 'built_plist_review': True, 'built_entitlements_review': True},
            'watch': {'udid': watch_id, 'app': str(watch), 'created_for_run': True,
                      'empty_before_install': True, 'built_plist_review': True, 'built_entitlements_review': True},
        }
        self.inventory = {'devices': {'runtime': [
            {'udid': phone_id, 'name': 'watch-fixture-abc-phone', 'isAvailable': True},
            {'udid': watch_id, 'name': 'watch-fixture-abc-watch', 'isAvailable': True},
        ]}, 'pairs': {'pair': {'phone': {'udid': phone_id}, 'watch': {'udid': watch_id}}}}
        self.status = {'hermes_home': str(root / 'home')}
        signed = types.SimpleNamespace(stdout=plistlib.dumps({}))
        codesign = patch.object(preflight.subprocess, 'run', return_value=signed)
        codesign.start()
        self.addCleanup(codesign.stop)

    def test_reviewed_manifest_with_built_artifacts_and_live_pair_accepted(self):
        preflight.validate(self.manifest, self.inventory, self.status)

    def test_unverified_empty_device_rejected(self):
        self.manifest['phone']['empty_before_install'] = False
        with self.assertRaisesRegex(ValueError, 'empty simulator'):
            preflight.validate(self.manifest, self.inventory, self.status)

    def test_backend_home_mismatch_rejected(self):
        self.status['hermes_home'] = '/personal/home'
        with self.assertRaisesRegex(ValueError, 'home mismatch'):
            preflight.validate(self.manifest, self.inventory, self.status)

    def test_unverified_storage_rejected(self):
        self.manifest['storage_review'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'storage'):
            preflight.validate(self.manifest, self.inventory, self.status)

    def test_unverified_pair_rejected(self):
        self.inventory['pairs'] = {}
        with self.assertRaisesRegex(ValueError, 'pair'):
            preflight.validate(self.manifest, self.inventory, self.status)


if __name__ == '__main__':
    unittest.main()
