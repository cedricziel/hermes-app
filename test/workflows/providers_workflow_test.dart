import 'dart:async';

import 'package:dio/dio.dart' show DioException;
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
    Locale? locale,
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
            locale: locale,
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
  Future<void> openProviders(
    WidgetTester tester, {
    required bool phone,
    String title = 'Model providers',
  }) async {
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
    await tester.tap(find.text(title));
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

  // ---- states, a pending row, the endpoint form, a removal, the sign-in variants ----

  Future<void> pumpPhone(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    Brightness brightness = Brightness.light,
    Locale? locale,
  }) => pumpShell(
    tester,
    shots,
    size: phoneSize,
    platform: TargetPlatform.iOS,
    brightness: brightness,
    locale: locale,
  );

  FakeProviderBackend connected() => backend
    ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_fakeKey)
    ..defaultProvider = 'openrouter'
    ..defaultModel = 'example-model-a';

  testWidgets('loading, and then the list', (tester) async {
    final shots = ScreenshotRecorder('providers-state-loading');
    final held = Completer<FakeResponse>();
    backend.server.onRequest('GET', '/api/model/options', (_) => held.future);
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    expect(find.bySemanticsLabel('Loading providers'), findsWidgets);
    await shots.capture(tester, 'loading');

    held.complete((
      status: 200,
      body: {'providers': [], 'model': '', 'provider': ''},
    ));
    await settle(tester);
    await shots.capture(tester, 'loaded');
    await letSocketsIdle(tester);
  });

  testWidgets("couldn't load", (tester) async {
    final shots = ScreenshotRecorder('providers-state-error');
    backend.server.on('GET', '/api/model/options', {
      'detail': 'x',
    }, status: 500);
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    expect(find.text("Couldn't load providers"), findsOneWidget);
    await shots.capture(tester, 'could-not-load');
    await letSocketsIdle(tester);
  });

  testWidgets('offline with nothing loaded', (tester) async {
    final shots = ScreenshotRecorder('providers-state-offline-empty');
    backend.server.onRequest('GET', '/api/model/options', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'offline');
    });
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    expect(find.text("Can't reach your Hermes server"), findsOneWidget);
    await shots.capture(tester, 'offline');
    await letSocketsIdle(tester);
  });

  testWidgets('offline with the list kept under a banner', (tester) async {
    final shots = ScreenshotRecorder('providers-state-offline-list');
    connected();
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    backend.server.onRequest('GET', '/api/model/options', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'offline');
    });
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await settle(tester);
    expect(find.text("Can't reach your Hermes server"), findsOneWidget);
    await shots.capture(tester, 'banner-over-list');
    await letSocketsIdle(tester);
  });

  testWidgets('a pending sign-in stays in the list', (tester) async {
    final shots = ScreenshotRecorder('providers-pending-sign-in');
    connected();
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
    await settle(tester);
    await closeSheet(tester);
    expect(find.text('Waiting for sign-in…'), findsOneWidget);
    await shots.capture(tester, 'waiting-row');
    await letSocketsIdle(tester);
  });

  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('desktop', desktopSize, TargetPlatform.macOS),
  ]) {
    testWidgets('$name: a custom endpoint', (tester) async {
      final shots = ScreenshotRecorder('providers-endpoint-$name');
      await pumpShell(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: Brightness.light,
      );
      await openProviders(tester, phone: size == phoneSize);
      await tester.scrollUntilVisible(find.text('Custom endpoint'), 200);
      await tester.tap(find.text('Custom endpoint'));
      await settle(tester);
      await shots.capture(tester, 'empty');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Lab server');
      await tester.enterText(fields.at(1), 'http://localhost:8000/v1');
      await tester.pump();
      await tester.tap(find.text('Check connection'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      await shots.capture(tester, 'checked');
      await letSocketsIdle(tester);
    });
  }

  testWidgets('a removal asks first', (tester) async {
    final shots = ScreenshotRecorder('providers-removal');
    connected();
    await pumpPhone(tester, shots);
    await openProviders(tester, phone: true);
    await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
    await settle(tester);
    await shots.capture(tester, 'detail');
    await tester.scrollUntilVisible(find.text('Remove key'), 200);
    await tester.tap(find.text('Remove key'));
    await settle(tester);
    await shots.capture(tester, 'confirm');
    await letSocketsIdle(tester);
  });

  group('sign-in variants', () {
    Future<void> signIn(
      WidgetTester tester,
      ScreenshotRecorder shots,
      Map<String, Object?> answer,
      String name,
      String shown,
    ) async {
      await pumpPhone(tester, shots);
      await openProviders(tester, phone: true);
      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      backend.pollAnswer = {'session_id': 's-1', ...answer};
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text(shown), findsOneWidget);
      await shots.capture(tester, name);
      await letSocketsIdle(tester);
    }

    testWidgets('declined', (tester) async {
      await signIn(
        tester,
        ScreenshotRecorder('providers-sign-in-declined'),
        {'status': 'denied'},
        'declined',
        'The sign-in was declined.',
      );
    });

    testWidgets('expired', (tester) async {
      await signIn(
        tester,
        ScreenshotRecorder('providers-sign-in-expired'),
        {'status': 'expired'},
        'expired',
        'The code expired.',
      );
    });

    testWidgets('failed with a reason', (tester) async {
      await signIn(
        tester,
        ScreenshotRecorder('providers-sign-in-failed'),
        {'status': 'error', 'error_message': 'The example provider is down.'},
        'failed',
        'The example provider is down.',
      );
    });

    testWidgets('refused to start', (tester) async {
      backend.server.on('POST', '/api/providers/oauth/nous/start', {
        'detail': 'Nous Portal is already signed in.',
      }, status: 400);
      final shots = ScreenshotRecorder('providers-sign-in-refused');
      await pumpPhone(tester, shots);
      await openProviders(tester, phone: true);
      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      expect(find.text('Nous Portal is already signed in.'), findsOneWidget);
      await shots.capture(tester, 'refused');
      await letSocketsIdle(tester);
    });

    testWidgets('no answer to the start', (tester) async {
      backend.server.onRequest('POST', '/api/providers/oauth/nous/start', (r) {
        throw DioException.connectionError(
          requestOptions: r,
          reason: 'offline',
        );
      });
      final shots = ScreenshotRecorder('providers-sign-in-no-answer');
      await pumpPhone(tester, shots);
      await openProviders(tester, phone: true);
      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      expect(find.text("Couldn't start the sign-in"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await shots.capture(tester, 'no-answer');
      await letSocketsIdle(tester);
    });
  });

  // ---- German ----

  for (final (name, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    testWidgets('$name: in German', (tester) async {
      final de = lookupAppLocalizations(const Locale('de'));
      final shots = ScreenshotRecorder('providers-de-$name');
      await pumpShell(
        tester,
        shots,
        size: size,
        platform: platform,
        brightness: brightness,
        locale: const Locale('de'),
      );
      await openProviders(
        tester,
        phone: size == phoneSize,
        title: de.providersListTitle,
      );
      expect(find.text(de.providersEmptyTitle), findsOneWidget);
      await shots.capture(tester, 'nothing-connected');

      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await settle(tester);
      await tester.enterText(find.byType(TextField), _fakeKey);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      await shots.capture(tester, 'key-typed');
      await tester.tap(find.text(de.providersFormSave));
      await settle(tester);
      expect(find.text(de.providersStepReadyTitle), findsOneWidget);
      await shots.capture(tester, 'default-model');
      await closeSheet(tester);
      await shots.capture(tester, 'connected');

      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await settle(tester);
      await shots.capture(tester, 'sign-in-code');
      await letSocketsIdle(tester);
    });
  }
}
