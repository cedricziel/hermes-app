import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/soul/open_soul.dart';
import 'package:hermes_app/src/profiles/soul/soul_availability.dart';
import 'package:hermes_app/src/profiles/soul/soul_screen.dart';
import 'package:hermes_app/src/profiles/soul/soul_telemetry.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

// Invented text: screenshots are published.
const _profile = 'work';
const _path = '/api/profiles/$_profile/soul';

const _loaded =
    'You are Mara, the support assistant for a small bakery.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and brief.\n'
    "- Answer in the customer's language.\n"
    '- Never promise a delivery date you cannot check.';

const _edited = '$_loaded\n- Offer the opening hours when someone asks.';

String _paragraphs(int length) {
  const paragraph =
      'Keep answers short and concrete. When a question is unclear, ask one '
      'question back before answering. Use plain words, avoid jargon, and '
      'say when you are not sure.\n\n';
  final out = StringBuffer();
  while (out.length < length) {
    out.write(paragraph);
  }
  return out.toString().substring(0, length);
}

/// A connection whose requests can be paused, as an expiry that a newer
/// session may still rescue does.
class _Auth extends AuthController {
  var _allowed = true;

  @override
  HermesConnectionState get state => HermesConnectionState.ready;
  @override
  bool get protectedRequestsAllowed => _allowed;
  @override
  int get ownerGeneration => 1;
  @override
  String? get baseUrl => 'https://hermes.example';

  void pauseRequests() {
    _allowed = false;
    notifyListeners();
  }
}

/// The states the Personality canvas draws beyond the main flow: no file, an
/// empty one, a very long text, a refused save, offline, a paused connection,
/// the App Lock cover, the largest text, German and the keyboard; and the
/// entry points (the phone drawer, the Mac Profiles page).
void main() {
  late FakeHermesServer server;
  late SoulAvailability availability;
  var fileText = _loaded;

  setUp(() {
    fileText = _loaded;
    availability = SoulAvailability();
    server = FakeHermesServer()
      ..onRequest(
        'GET',
        _path,
        (_) => (status: 200, body: {'content': fileText, 'exists': true}),
      )
      ..onRequest('PUT', _path, (request) {
        fileText =
            (jsonBody(request)! as Map<String, Object?>)['content']! as String;
        return (status: 200, body: {'ok': true});
      });
  });

  tearDown(() => availability.dispose());

  Widget opener() => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => unawaited(
            openSoul(context, profile: _profile, from: SoulOpenedFrom.sidebar),
          ),
          child: const Text('Personality'),
        ),
      ),
    ),
  );

  /// Mounts an app with a button that opens the page, then opens it. Frames,
  /// not a settle, so a spinner may be up.
  Future<void> open(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    Size size = phoneSize,
    TargetPlatform platform = TargetPlatform.iOS,
    Brightness brightness = Brightness.light,
    Locale? locale,
    AuthController? auth,
    AppLockController? lock,
    bool settle = true,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await shots.start(tester, size);
    // A fresh app, so the page opens anew.
    await tester.pumpWidget(const SizedBox.shrink());
    final dark = brightness == Brightness.dark;
    await tester.pumpWidget(
      shots.frame(
        MultiProvider(
          providers: [
            Provider<HermesRepositories>.value(
              value: HermesRepositories(server.client()),
            ),
            ChangeNotifierProvider<SoulAvailability?>.value(
              value: availability,
            ),
            if (auth != null)
              ChangeNotifierProvider<AuthController>.value(value: auth),
            if (lock != null)
              ChangeNotifierProvider<AppLockController>.value(value: lock),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: withScreenshotFont(
              dark
                  ? buildHermesDarkTheme(platform: platform)
                  : buildHermesLightTheme(platform: platform),
            ),
            builder: lock == null
                ? null
                : (context, child) => AppLockGate(child: child!),
            home: opener(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personality'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  Finder phoneSave() => find.widgetWithText(TextButton, 'Save');

  group('the file and the save', () {
    for (final (name, size, platform) in [
      ('phone', phoneSize, TargetPlatform.iOS),
      ('desktop', desktopSize, TargetPlatform.macOS),
    ]) {
      testWidgets('$name: not set, empty, long, refused, offline', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('personality-file-$name');
        // No file yet: an empty editor and "No personality set yet."
        server.onRequest(
          'GET',
          _path,
          (_) => (status: 200, body: {'content': '', 'exists': false}),
        );
        await open(tester, shots, size: size, platform: platform);
        await shots.capture(tester, 'not-set');
        expect(find.text('No personality set yet.'), findsOneWidget);

        // An empty file says Hermes uses its default personality.
        server.onRequest(
          'GET',
          _path,
          (_) => (status: 200, body: {'content': '', 'exists': true}),
        );
        await open(tester, shots, size: size, platform: platform);
        await shots.capture(tester, 'empty-file');
        expect(
          find.text('Hermes uses its default personality while this is empty.'),
          findsOneWidget,
        );

        // Over 20,000 characters: the note, and still editable.
        final long = _paragraphs(20250);
        server.onRequest(
          'GET',
          _path,
          (_) => (status: 200, body: {'content': long, 'exists': true}),
        );
        await open(tester, shots, size: size, platform: platform);
        await shots.capture(tester, 'long-text');
        expect(find.textContaining('Hermes may shorten text'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The server refuses the new text: an error banner, the text stays.
        server
          ..onRequest(
            'GET',
            _path,
            (_) => (status: 200, body: {'content': fileText, 'exists': true}),
          )
          ..on('PUT', _path, {'detail': 'Invalid'}, status: 500);
        await open(tester, shots, size: size, platform: platform);
        await tester.enterText(find.byType(TextField), _edited);
        await animate(tester);
        await tester.tap(
          platform == TargetPlatform.macOS
              ? find.widgetWithText(FilledButton, 'Save')
              : phoneSave(),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'save-refused');
        expect(find.text("Couldn't save"), findsOneWidget);
        expect(find.text(_edited), findsOneWidget);

        // No answer at all on load: offline, Try again, no editor.
        server.onRequest(
          'GET',
          _path,
          (request) => throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          ),
        );
        await open(tester, shots, size: size, platform: platform);
        await shots.capture(tester, 'offline-on-load');
        expect(find.text("You're offline."), findsOneWidget);
      });
    }
  });

  group('text size, language and keyboard', () {
    testWidgets('largest text: loaded, with a banner, at the keyboard', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final shots = ScreenshotRecorder('personality-largest-text');
      await open(tester, shots);
      await shots.capture(tester, 'loaded');
      await tester.enterText(find.byType(TextField), _edited);
      await animate(tester);
      await shots.capture(tester, 'edited');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await animate(tester);
      await shots.capture(tester, 'keyboard');
      expect(tester.takeException(), isNull);
    });

    for (final (name, platform) in [
      ('ios', TargetPlatform.iOS),
      ('android', TargetPlatform.android),
    ]) {
      testWidgets('keyboard open on $name', (tester) async {
        final shots = ScreenshotRecorder('personality-keyboard-$name');
        await open(tester, shots, platform: platform);
        await tester.enterText(find.byType(TextField), _edited);
        await animate(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await animate(tester);
        await shots.capture(tester, 'keyboard');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('German: loaded, save question, lost answer', (tester) async {
      final shots = ScreenshotRecorder('personality-german');
      server.onRequest(
        'PUT',
        _path,
        (_) => (status: 200, body: <String, Object?>{}),
      );
      await open(tester, shots, locale: const Locale('de'));
      await shots.capture(tester, 'loaded');
      await tester.enterText(find.byType(TextField), _edited);
      await animate(tester);
      await shots.capture(tester, 'edited');
      await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-question');
      await tester.tap(find.text('Ersetzen'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'lost-answer');
      expect(tester.takeException(), isNull);
    });
  });

  group('connection and App Lock', () {
    testWidgets('paused: the only banner, the editor read-only', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('personality-paused');
      final auth = _Auth();
      addTearDown(auth.dispose);
      server.onRequest(
        'PUT',
        _path,
        (_) => (status: 200, body: <String, Object?>{}),
      );
      await open(tester, shots, auth: auth);
      await tester.enterText(find.byType(TextField), _edited);
      await animate(tester);
      // A save whose answer is lost: the warning banner with Check.
      await tester.tap(phoneSave());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'lost-answer');
      expect(find.text("Couldn't confirm the save"), findsOneWidget);

      // Paused: one banner, which says why nothing can be pressed.
      auth.pauseRequests();
      await tester.pumpAndSettle();
      await shots.capture(tester, 'paused');
      expect(find.text('The connection is paused.'), findsOneWidget);
      expect(find.text("Couldn't confirm the save"), findsNothing);
    });

    testWidgets('App Lock covers the page and drops the text', (tester) async {
      final shots = ScreenshotRecorder('personality-app-lock');
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final lock = AppLockController(
        authenticator: FakeDeviceAuthenticator(),
        coverWhenInactive: true,
      );
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      await open(tester, shots, lock: lock);
      await tester.enterText(find.byType(TextField), _edited);
      await animate(tester);
      await shots.capture(tester, 'before-lock');

      await tester.runAsync(() => lock.setEnabled(true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // Back in front, still locked: the binding draws no frame while hidden.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await shots.capture(tester, 'locked');
      expect(find.text(_edited), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(lock.unlock);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      await shots.capture(tester, 'unlocked');
      // The server's text is read again; the unsaved edit is gone.
      expect(find.text(_edited), findsNothing);
      expect(find.text(_loaded), findsOneWidget);
    });
  });

  group('entry points', () {
    void routes() {
      server
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([
            profileRow(name: 'default', isDefault: true),
            profileRow(name: _profile, description: 'Day job'),
          ]),
        )
        ..on('GET', '/api/profiles/active', activeProfileBody(active: _profile))
        ..on('GET', '/api/sessions', sessionListBody([]))
        ..on('GET', '/api/skills', <Object?>[])
        ..on('GET', '/api/learning/graph', {
          'nodes': <Object?>[],
          'edges': <Object?>[],
          'memory': <Object?>[],
        })
        ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
    }

    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> pumpShell(
      WidgetTester tester,
      ScreenshotRecorder shots, {
      required Size size,
      required TargetPlatform platform,
    }) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await shots.start(tester, size);
      final auth = ProtectedCatalogAuth(server);
      addTearDown(auth.dispose);
      final lock = await newAppLock(tester);
      await tester.pumpWidget(
        shots.frame(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SoulAvailability?>.value(
                value: availability,
              ),
            ],
            child: withAppProviders(
              auth,
              lock: lock,
              MaterialApp(
                debugShowCheckedModeBanner: false,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: withScreenshotFont(
                  buildHermesLightTheme(platform: platform),
                ),
                home: const AppShell(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('the phone drawer lists Personality after Memory on '
          '$platform', (tester) async {
        routes();
        server.on('GET', _path, {'content': _loaded, 'exists': true});
        final shots = ScreenshotRecorder(
          'personality-entry-phone-${platform.name}',
        );
        await pumpShell(tester, shots, size: phoneSize, platform: platform);
        await tester.tap(find.byKey(const Key('shell-menu')));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'drawer');
        final drawer = find.byType(Drawer);
        expect(
          tester
              .getTopLeft(
                find.descendant(of: drawer, matching: find.text('Personality')),
              )
              .dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.descendant(of: drawer, matching: find.text('Memory')),
                )
                .dy,
          ),
        );
        await tester.tap(
          find.descendant(of: drawer, matching: find.text('Personality')),
        );
        await frames(tester);
        await shots.capture(tester, 'page');
        expect(find.byType(SoulScreen), findsOneWidget);
      });
    }

    testWidgets('the Mac Profiles page has a Personality row after Memory', (
      tester,
    ) async {
      routes();
      server.on('GET', _path, {'content': _loaded, 'exists': true});
      final shots = ScreenshotRecorder('personality-entry-mac');
      await pumpShell(
        tester,
        shots,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text('Profiles'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-row-work')));
      await frames(tester);
      await shots.capture(tester, 'profiles-page');
      final row = find.byKey(const ValueKey('profile-section-personality'));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await frames(tester);
      await shots.capture(tester, 'page');
      expect(find.byType(SoulScreen), findsOneWidget);
    });
  });
}
