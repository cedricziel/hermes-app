#!/usr/bin/env python3
import argparse
import json
import pathlib
import plistlib
import re
import subprocess
import urllib.request
import uuid


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def validate_identity(bundle_id, run_id):
    require(bool(re.fullmatch(r'[a-z0-9]+', run_id)), 'Invalid run namespace')
    require(bundle_id.startswith(f'app.hermes.fixture.{run_id}.'), 'Non-fixture bundle identity')


def validate_bundle(info, entitlements):
    for key in ('CFBundleURLTypes', 'NSServices', 'NSUserActivityTypes'):
        require(not info.get(key), f'Unisolated routing: {key}')
    require(not entitlements.get('com.apple.security.application-groups'), 'Shared app groups')
    for key in ('com.apple.developer.ubiquity-container-identifiers',
                'com.apple.developer.icloud-container-identifiers',
                'com.apple.developer.ubiquity-kvstore-identifier'):
        require(not entitlements.get(key), 'Shared iCloud')
    require(not entitlements.get('com.apple.developer.associated-domains'), 'Associated-domain routing')
    groups = entitlements.get('keychain-access-groups', [])
    identity = info.get('CFBundleIdentifier', '')
    require(all(group.endswith('.' + identity) for group in groups), 'Shared keychain access')


def validate(manifest, inventory, status):
    run = manifest.get('run_id', '')
    require(bool(run), 'Missing fixture namespace')
    home = pathlib.Path(manifest.get('backend_home', '')).resolve()
    root = pathlib.Path(manifest.get('fixture_root', '')).resolve()
    require(root.name == f'watch-fixture-{run}', 'Unverified fixture root')
    require(home.is_relative_to(root) and home != root, 'Backend home outside fixture')
    require(pathlib.Path(status.get('hermes_home', '')).resolve() == home, 'Backend home mismatch')
    require(manifest.get('credentials') == 'synthetic', 'Unverified credentials')
    require(manifest.get('storage_review') == 'fresh-pair-no-host-storage', 'Unverified storage')
    require(manifest.get('routing_review') == 'disabled', 'Unverified routing')
    devices = {d['udid']: d for entries in inventory.get('devices', {}).values() for d in entries}
    ids = []
    for role in ('phone', 'watch'):
        entry = manifest.get(role, {})
        identifier = entry.get('udid', '')
        uuid.UUID(identifier)
        ids.append(identifier)
        device = devices.get(identifier, {})
        require(device.get('name') == f'watch-fixture-{run}-{role}', 'Non-fixture simulator')
        require(device.get('isAvailable') is True, 'Unavailable simulator')
        require(entry.get('created_for_run') is True, 'Unverified simulator creation')
        require(entry.get('empty_before_install') is True, 'Unverified empty simulator')
        app = pathlib.Path(entry.get('app', '')).resolve()
        require(app.is_relative_to(root), 'Build outside fixture')
        with (app / 'Info.plist').open('rb') as source:
            info = plistlib.load(source)
        signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)],
                                capture_output=True, check=True).stdout
        entitlements = plistlib.loads(signed) if signed.strip() else {}
        validate_identity(info.get('CFBundleIdentifier', ''), run)
        validate_bundle(info, entitlements)
        require(entry.get('built_plist_review') is True, 'Missing built plist review')
        require(entry.get('built_entitlements_review') is True, 'Missing entitlement review')
    require(len(set(ids)) == 2, 'Pair identifiers overlap')
    pairs = inventory.get('pairs', {}).values()
    require(any(p.get('phone', {}).get('udid') == ids[0] and
                p.get('watch', {}).get('udid') == ids[1] for p in pairs), 'Unverified simulator pair')


def main():
    parser = argparse.ArgumentParser(description='Reject unverified watch fixtures before launch')
    parser.add_argument('manifest', type=pathlib.Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '-j']))
    url = manifest.get('backend_url', '')
    require(bool(re.fullmatch(r'http://127\.0\.0\.1:[0-9]+', url)), 'Backend must use loopback')
    with urllib.request.urlopen(url + '/api/status', timeout=5) as response:
        status = json.load(response)
    validate(manifest, inventory, status)
    print('Preflight passed. Launch only the recorded fixture pair.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Preflight rejected: {error}')
