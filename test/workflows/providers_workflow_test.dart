import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../providers/fake_provider_backend.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart' show letSocketsIdle;

const _fakeKey = 'sk-or-v1-test-aaaa-4f2a';

/// Model providers through the real shell, on a fresh server with no
/// provider: add an OpenRouter key and choose the default model, and sign in
/// with a code. Phone and desktop, light and dark; look at the screenshots in
/// `build/workflow_screenshots/`.
void main() {
  late FakeProviderBackend backend;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    backend = FakeProviderBackend();
    backend.server
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'default', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
  });

  Future<void> pumpShell(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    required TargetPlatform platform,
    required Brightness brightness,
  }) async {
    await shots.start(tester, size);
    final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    final auth = CatalogAuth(server: backend.server, gated: true);
    addTearDown(auth.dispose);
    final theme = brightness == Brightness.dark
        ? buildHermesDarkTheme(platform: platform)
        : buildHermesLightTheme(platform: platform);
    await tester.pumpWidget(
      shots.frame(
        withAppProviders(
          auth,
          lock: lock,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: withScreenshotFont(theme),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The sheet's way out: Cancel on iOS, the close button on Material, the
  /// back button of a Mac dialog.
  Future<void> closeSheet(WidgetTester tester) async {
    final cancel = find.text('Cancel');
    final close = find.byType(CloseButton);
    await tester.tap(
      cancel.evaluate().isNotEmpty
          ? cancel
          : close.evaluate().isNotEmpty
          ? close
          : find.byKey(const Key('settings-back')).last,
    );
    await settle(tester);
  }

  /// The chat's entry to the screen: the drawer on a phone, and on a Mac the
  /// Profiles page, since its sidebar has no management rows.
  Future<void> openProviders(WidgetTester tester, {required bool phone}) async {
    if (!phone) {
      await tester.tap(find.text('Profiles').first);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('profile-row-default')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('profile-section-providers')));
      await settle(tester);
      return;
    }
    if (phone) {
      await tester.tap(findAppIcon(AppIcons.menu).first);
      await settle(tester);
    }
    await tester.tap(find.text('Model providers'));
    await settle(tester);
  }

  for (final (name, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.android, Brightness.dark),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    final phone = size == phoneSize;

    testWidgets('$name: connect OpenRouter with a key', (tester) async {
      final shots = ScreenshotRecorder('providers-key-$name');
      await pumpShell(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await openProviders(tester, phone: phone);
      expect(find.text('No model provider yet'), findsOneWidget);
      await shots.capture(tester, 'nothing-connected');

      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await settle(tester);
      await shots.capture(tester, 'key-form');

      await tester.enterText(find.byType(TextField), _fakeKey);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      await shots.capture(tester, 'key-typed');

      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text("You're ready"), findsOneWidget);
      await shots.capture(tester, 'default-model');

      // Close the sheet without leaving the screen, to see the list.
      await closeSheet(tester);
      expect(find.textContaining('API key ending in 4f2a'), findsWidgets);
      await shots.capture(tester, 'connected');

      expect(backend.defaultModel, 'example-model-a');
      await letSocketsIdle(tester);
    });
  }

  for (final (name, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    final phone = size == phoneSize;

    testWidgets('$name: sign in to Nous Portal with a code', (tester) async {
      final shots = ScreenshotRecorder('providers-sign-in-$name');
      await pumpShell(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await openProviders(tester, phone: phone);

      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      expect(find.textContaining('ABCD'), findsWidgets);
      await shots.capture(tester, 'code');

      backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text("You're ready"), findsOneWidget);
      await shots.capture(tester, 'ready');

      await closeSheet(tester);
      await shots.capture(tester, 'connected');
      await letSocketsIdle(tester);
    });
  }
}
