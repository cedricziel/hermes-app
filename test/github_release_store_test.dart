import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

import 'package:hermes_app/src/update/github_release_store.dart';

const _releasePage =
    'https://github.com/cedricziel/hermes-app/releases/tag/v0.2.0';

http.Client _client(int status, Object body, {void Function(Uri)? onRequest}) =>
    MockClient((request) async {
      onRequest?.call(request.url);
      return http.Response(
        body is String ? body : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
    });

Future<UpgraderVersionInfo> _lookup(http.Client client) async {
  final upgrader = Upgrader(client: client);
  return GithubReleaseStore().getVersionInfo(
    state: upgrader.state,
    installedVersion: Version(0, 1, 13),
    country: null,
    language: null,
  );
}

void main() {
  group('GithubReleaseStore', () {
    test('reads the version and release page of the latest release', () async {
      Uri? asked;
      final info = await _lookup(
        _client(200, {
          'tag_name': 'v0.2.0',
          'html_url': _releasePage,
        }, onRequest: (u) => asked = u),
      );

      expect(
        asked.toString(),
        contains('/repos/cedricziel/hermes-app/releases/latest'),
      );
      expect(info.appStoreVersion, Version(0, 2, 0));
      expect(info.appStoreListingURL, _releasePage);
    });

    for (final (name, client) in [
      ('a rate limit', _client(403, {'message': 'rate limited'})),
      ('a malformed tag', _client(200, {'tag_name': 'nightly'})),
      ('a body that is not JSON', _client(200, 'oops')),
      (
        'a network failure',
        MockClient((_) async => throw http.ClientException('offline')),
      ),
    ]) {
      test('reports no version on $name', () async {
        final info = await _lookup(client);

        expect(info.appStoreVersion, isNull);
      });
    }
  });

  group('UpgradeAlert with GithubReleaseStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Hermes',
        packageName: 'com.cedricziel.hermesApp',
        version: '0.1.13',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    Future<void> pump(WidgetTester tester, String tag) async {
      final upgrader = Upgrader(
        client: _client(200, {'tag_name': tag, 'html_url': _releasePage}),
        storeController: UpgraderStoreController(
          onAndroid: GithubReleaseStore.new,
          oniOS: GithubReleaseStore.new,
          onLinux: GithubReleaseStore.new,
          onMacOS: GithubReleaseStore.new,
          onWindows: GithubReleaseStore.new,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UpgradeAlert(
            upgrader: upgrader,
            showReleaseNotes: false,
            child: const Text('home'),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('prompts when a newer release exists', (tester) async {
      await pump(tester, 'v0.2.0');

      expect(find.text('UPDATE NOW'), findsOneWidget);
    });

    testWidgets('stays quiet when the app is current', (tester) async {
      await pump(tester, 'v0.1.13');

      expect(find.text('UPDATE NOW'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
