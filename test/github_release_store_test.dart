import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/update/github_release_store.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

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

    /// Mounts the alert the way `HermesApp` does: `material_ui` and
    /// `cupertino_ui` localizations in the app's delegates and the
    /// `material_ui` theme above the navigator. [bridged] false leaves both out.
    Future<void> pump(
      WidgetTester tester,
      String tag, {
      bool bridged = true,
      Brightness brightness = Brightness.light,
      Locale locale = const Locale('en'),
    }) async {
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
          theme: buildHermesLightTheme(),
          darkTheme: buildHermesDarkTheme(),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            if (bridged) ...kMaterialUiLocalizationsDelegates,
          ],
          builder: (context, child) =>
              bridged ? MaterialUiThemeScope(child: child!) : child!,
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

    for (final brightness in Brightness.values) {
      testWidgets('prompts when a newer release exists, ${brightness.name}', (
        tester,
      ) async {
        await pump(tester, 'v0.2.0', brightness: brightness);

        expect(tester.takeException(), isNull);
        expect(find.text('UPDATE NOW'), findsOneWidget);
      }, variant: TargetPlatformVariant.all());
    }

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('prompts under the app delegates in ${locale.languageCode}', (
        tester,
      ) async {
        await pump(tester, 'v0.2.0', locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byType(mui.AlertDialog), findsOneWidget);
      }, variant: TargetPlatformVariant.all());
    }

    for (final bridged in [true, false]) {
      testWidgets('material_ui and cupertino_ui localizations are '
          '${bridged ? 'provided' : 'absent without the bridge'}', (
        tester,
      ) async {
        late BuildContext inside;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              if (bridged) ...kMaterialUiLocalizationsDelegates,
            ],
            home: Builder(
              builder: (context) {
                inside = context;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          Localizations.of<mui.MaterialLocalizations>(
            inside,
            mui.MaterialLocalizations,
          ),
          bridged ? isNotNull : isNull,
        );
        expect(
          Localizations.of<cui.CupertinoLocalizations>(
            inside,
            cui.CupertinoLocalizations,
          ),
          bridged ? isNotNull : isNull,
        );
      });
    }

    testWidgets('stays quiet when the app is current', (tester) async {
      await pump(tester, 'v0.1.13');

      expect(find.text('UPDATE NOW'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
