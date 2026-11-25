import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_commands.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/messaging/whatsapp_pairing_screen.dart';
import 'package:hermes_app/src/messaging/widgets/qr_code_card.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_saved_banner.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/recorded_accessibility.dart';
import '../../support/test_localizations.dart';
import 'whatsapp_fixtures.dart';

const _profile = 'atlas';
const _platformsPath = '/api/messaging/platforms';

FakeResponse _ok(Object? body) => (status: 200, body: body);

/// A recorded answer with a deadline ten minutes from now: the fixtures' fixed
/// time is long past, and a pairing past it ends locally when the app returns.
Map<String, Object?> _live(Map<String, Object?> recorded) => {
  ...recorded,
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
};

Map<String, Object?> _platforms({required bool enabled}) => {
  'platforms': [
    {'id': 'whatsapp', 'name': 'WhatsApp', 'enabled': enabled},
  ],
};

/// The screen driven through the real generated client and Dio pipeline
/// against a fake dashboard. No test starts a real pairing: the server's
/// answers are the fixtures, and nothing reaches WhatsApp.
void main() {
  late FakeHermesServer server;
  late FutureOr<FakeResponse> Function(RequestOptions) startReply;
  late FutureOr<FakeResponse> Function(RequestOptions) statusReply;
  late FutureOr<FakeResponse> Function(RequestOptions) applyReply;
  late FutureOr<FakeResponse> Function(RequestOptions) platformsReply;
  Object? popped;
  var opened = false;

  int count(String method, String path) =>
      server.requestsTo(method, path).length;
  int starts() => count('POST', waStartPath);
  int polls() => count('GET', waStatusPath);
  int cancels() => count('DELETE', waStatusPath);
  int applies() => count('POST', waApplyPath);

  FutureOr<FakeResponse> hang(RequestOptions _) =>
      Completer<FakeResponse>().future;

  setUp(() {
    // A test that ends mid-lifecycle must not leave the next one inactive.
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    popped = null;
    opened = false;
    startReply = (_) => _ok(_live(waStartFresh));
    statusReply = (_) => _ok(_live(waStatusWaiting));
    applyReply = (_) => _ok(waApplyRestartStarted);
    platformsReply = (_) => _ok(_platforms(enabled: true));
    server = FakeHermesServer()
      ..onRequest('POST', waStartPath, (r) => startReply(r))
      ..onRequest('GET', waStatusPath, (r) => statusReply(r))
      ..onRequest('POST', waApplyPath, (r) => applyReply(r))
      ..onRequest('GET', _platformsPath, (r) => platformsReply(r))
      ..on('DELETE', waStatusPath, waCancelOk);
  });

  /// Lets the real Dio pipeline run to its end on the fake clock.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Closes the screen as the end of a test does, and lets the one cancel it
  /// may send go through.
  Future<void> leaveScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  /// Opens the screen as a pushed route, so a pop and its result are seen.
  Future<void> open(
    WidgetTester tester, {
    required Size size,
    TargetPlatform platform = TargetPlatform.iOS,
    AppLockController? lock,
    bool wasEnabled = true,
    VoidCallback? onUnsupported,
    HermesMessagingRepository? repository,
    DateTime Function()? now,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app = MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              opened = true;
              popped = await Navigator.push<WhatsAppSavedOutcome>(
                context,
                MaterialPageRoute(
                  builder: (_) => WhatsAppPairingScreen(
                    repository:
                        repository ??
                        HermesMessagingRepository(server.client().raw),
                    profile: _profile,
                    wasEnabled: wasEnabled,
                    onUnsupported: onUnsupported,
                    now: now,
                  ),
                ),
              );
              opened = false;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    if (lock != null) {
      app = ChangeNotifierProvider.value(value: lock, child: app);
    }
    addTearDown(() => leaveScreen(tester));
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const phone = Size(390, 844);
  const computer = Size(1100, 800);

  Future<void> begin(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await settle(tester);
  }

  /// Lets one poll (2 s) go and answer.
  Future<void> poll(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  QrCodeVisibility? tile(WidgetTester tester) {
    final found = find.byType(QrCodeTile);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<QrCodeTile>(found).visibility;
  }

  Future<AppLockController> enabledLock(WidgetTester tester) async {
    final lock = AppLockController(
      authenticator: FakeDeviceAuthenticator(),
      coverWhenInactive: false,
    );
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    await tester.runAsync(() => lock.setEnabled(true));
    return lock;
  }

  Future<void> waitForCode(WidgetTester tester) async {
    await begin(tester);
    await poll(tester);
  }

  group('starting', () {
    testWidgets('opening sends nothing and Start sends one request', (
      tester,
    ) async {
      await open(tester, size: phone);
      expect(starts(), 0);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await begin(tester);
      expect(starts(), 1);
      expect(jsonBody(server.requestsTo('POST', waStartPath).single), {
        'mode': 'bot',
        'profile': _profile,
      });
    });

    testWidgets('numbers that are not numbers send nothing', (tester) async {
      await open(tester, size: phone);
      await tester.enterText(
        find.byKey(const Key('whatsapp-numbers')),
        'everyone, *',
      );
      await begin(tester);
      expect(starts(), 0);
    });

    testWidgets('a start the server refuses keeps the form with its text', (
      tester,
    ) async {
      startReply = (_) => (status: 400, body: waBadMode);
      await open(tester, size: phone);
      await begin(tester);
      expect(find.textContaining("'bot' or 'self-chat'"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    });

    testWidgets('a 404 naming the profile ends as a deleted profile', (
      tester,
    ) async {
      startReply = (_) => (status: 404, body: waProfileGone);
      var unsupported = 0;
      await open(tester, size: phone, onUnsupported: () => unsupported++);
      await begin(tester);
      expect(find.text("This chat's profile no longer exists"), findsOneWidget);
      expect(unsupported, 0);
    });

    testWidgets('a 404 for the missing route ends as an old server', (
      tester,
    ) async {
      startReply = (_) => (status: 404, body: waRouteMissing);
      var unsupported = 0;
      await open(tester, size: phone, onUnsupported: () => unsupported++);
      await begin(tester);
      expect(
        find.text('This server cannot link WhatsApp from the app'),
        findsOneWidget,
      );
      expect(find.text("This chat's profile no longer exists"), findsNothing);
      expect(unsupported, 1);
    });
  });

  group('the code', () {
    testWidgets(
      'a handset shows it only after a tap, and again after each hide',
      (tester) async {
        await open(tester, size: phone);
        await waitForCode(tester);
        expect(tile(tester), isNull);
        expect(find.text('Show QR code'), findsOneWidget);

        await tester.tap(find.text('Show QR code'));
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.shown);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(tile(tester), isNull);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(tile(tester), isNull);
        expect(find.text('Show QR code'), findsOneWidget);

        await tester.tap(find.text('Show QR code'));
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.shown);
      },
    );

    testWidgets(
      'a tablet shows it at once and again after the lifecycle returns',
      (tester) async {
        await open(tester, size: computer);
        await waitForCode(tester);
        expect(tile(tester), QrCodeVisibility.shown);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.shown);
      },
    );

    testWidgets(
      'a desktop window hides it when it loses focus and shows it again with no tap, whatever its size',
      (tester) async {
        // A narrow window is a handset by size and still follows focus.
        await open(tester, size: phone, platform: TargetPlatform.macOS);
        await waitForCode(tester);
        expect(tile(tester), QrCodeVisibility.shown);
        expect(find.text('Show QR code'), findsNothing);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.hidden);
        expect(
          find.text('Shows again when the app is unlocked and in front.'),
          findsOneWidget,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(tile(tester), QrCodeVisibility.shown);
      },
    );

    testWidgets(
      'App Lock hides it, stops the polling, and the page says it was paused',
      (tester) async {
        final lock = await enabledLock(tester);
        await open(tester, size: computer, lock: lock);
        await waitForCode(tester);
        expect(tile(tester), QrCodeVisibility.shown);
        final before = polls();

        // Only the lock moves: the app lifecycle is not touched.
        lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump();
        expect(lock.locked, isTrue);
        expect(tile(tester), QrCodeVisibility.hidden);
        await tester.pump(const Duration(seconds: 10));
        expect(polls(), before);

        // Not in runAsync: the poll timer it starts must run on the fake clock.
        unawaited(lock.unlock());
        await tester.pump();
        await tester.pump();
        expect(find.text('Paused while the app was away.'), findsOneWidget);
        await poll(tester);
        expect(polls(), greaterThan(before));
        expect(find.text('Paused while the app was away.'), findsNothing);
      },
    );

    testWidgets('the code is in no semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, size: computer);
      await waitForCode(tester);
      expect(tile(tester), QrCodeVisibility.shown);
      expect(find.bySemanticsLabel(RegExp('DEMO-NOT-A-REAL-QR')), findsNothing);
      handle.dispose();
    });

    testWidgets('nothing is put on the clipboard', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, size: computer);
      await waitForCode(tester);
      expect(calls.where((c) => c == 'Clipboard.setData'), isEmpty);
    });
  });

  group('a screen reader', () {
    testWidgets(
      'is sent to the code after "Show QR code", and the code is in nothing it is sent',
      (tester) async {
        final handle = tester.ensureSemantics();
        final heard = RecordedAccessibility(tester);
        await open(tester, size: phone);
        await waitForCode(tester);
        expect(heard.focusEvents, 0);

        await tester.tap(find.text('Show QR code'));
        await tester.pump();
        await tester.pump();
        expect(heard.focusEvents, 1);
        expect(heard.text, isNot(contains('DEMO-NOT-A-REAL-QR')));
        handle.dispose();
      },
    );

    testWidgets(
      'hears the time left at 60, 30 and 10 seconds from the injected clock',
      (tester) async {
        final heard = RecordedAccessibility(tester);
        final start = DateTime.utc(2026, 11, 15, 12);
        var elapsed = Duration.zero;
        Map<String, Object?> at(Map<String, Object?> recorded) => {
          ...recorded,
          'expires_at': start
              .add(const Duration(seconds: 90))
              .toIso8601String(),
        };
        startReply = (_) => _ok(at(waStartFresh));
        statusReply = (_) => _ok(at(waStatusWaiting));
        await open(tester, size: computer, now: () => start.add(elapsed));
        await waitForCode(tester);
        expect(find.text('Setup closes in 1:30'), findsOneWidget);
        expect(heard.announcements, isEmpty);
        // No answer comes in: only the screen's own tick repaints the countdown.
        statusReply = hang;

        // Each step is one tick of the screen's own timer, no real waiting.
        for (final seconds in [10, 20, 29, 30, 31, 59, 60, 61, 80, 81]) {
          elapsed = Duration(seconds: seconds);
          await tester.pump(const Duration(seconds: 1));
        }
        expect(heard.announcements, [
          'Setup closes in 60 seconds.',
          'Setup closes in 30 seconds.',
          'Setup closes in 10 seconds.',
        ]);
        // The unanswered poll's own limit runs out after the screen is gone.
        await leaveScreen(tester);
        await tester.pump(const Duration(seconds: 11));
      },
    );
  });

  group('Return', () {
    testWidgets('presses Start on the form, once', (tester) async {
      await open(tester, size: computer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(starts(), 1);
      // The start is out or answered: Return has no filled button to press.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(starts(), 1);
    });

    testWidgets('keeps its own meaning in the numbers field', (tester) async {
      await open(tester, size: computer);
      await tester.tap(find.byKey(const Key('whatsapp-numbers')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(starts(), 0);
    });

    testWidgets('presses Finish once linked, which asks first', (tester) async {
      startReply = (_) => _ok(_live(waStartAlreadyLinked));
      statusReply = (_) => _ok(_live(waStatusConnected));
      await open(tester, size: computer);
      await begin(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Save and restart?'), findsOneWidget);
      expect(applies(), 0);
    });

    testWidgets(
      'does not press Cancel setup or anything else while the code waits',
      (tester) async {
        await open(tester, size: computer);
        await waitForCode(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester);
        expect(opened, isTrue);
        expect(cancels(), 0);
        expect(starts(), 1);
      },
    );
  });

  group('the Mac back chord', () {
    /// The screen under the app's own back command: the chord is a
    /// `MacCommand.back` that the menu owns and `DesktopNavigationCommands`
    /// handles through the navigation history, which pops with `maybePop`.
    /// The screen adds no key handler of its own for it.
    Future<MacCommandRegistry> openUnderHistory(WidgetTester tester) async {
      tester.view
        ..physicalSize = computer
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final registry = MacCommandRegistry();
      final history = DesktopNavigationHistory(
        canNavigate: () => true,
        resolve: (_) async => null,
      );
      addTearDown(history.dispose);
      await tester.pumpWidget(
        MacCommandScope.root(
          registry: registry,
          child: MaterialApp(
            theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [history],
            builder: (context, child) =>
                DesktopNavigationCommands(history: history, child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhatsAppPairingScreen(
                        repository: HermesMessagingRepository(
                          server.client().raw,
                        ),
                        profile: _profile,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      addTearDown(() => leaveScreen(tester));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return registry;
    }

    testWidgets('leaves like Back, asking the server to drop the setup once', (
      tester,
    ) async {
      final registry = await openUnderHistory(tester);
      await waitForCode(tester);
      expect(registry.invoke(MacCommand.back), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppPairingScreen), findsNothing);
      expect(cancels(), 1);
    });
  });

  group('leaving', () {
    testWidgets('Back while waiting asks the server to drop the setup once', (
      tester,
    ) async {
      await open(tester, size: computer);
      await waitForCode(tester);
      await tester.tap(find.byType(AdaptiveBackButton));
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(cancels(), 1);
      expect(applies(), 0);
    });

    testWidgets('Cancel setup leaves the same way', (tester) async {
      await open(tester, size: computer);
      await waitForCode(tester);
      await tester.tap(find.text('Cancel setup'));
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(cancels(), 1);
    });
  });

  group('Finish', () {
    Future<void> linked(WidgetTester tester) async {
      startReply = (_) => _ok(_live(waStartAlreadyLinked));
      statusReply = (_) => _ok(_live(waStatusConnected));
      await open(tester, size: computer);
      await begin(tester);
    }

    testWidgets(
      'asks first, Cancel sends nothing, and the question is repeatable',
      (tester) async {
        await linked(tester);
        expect(find.text('Already linked'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Save and restart?'), findsOneWidget);
        expect(applies(), 0);

        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.text('Save and restart?'), findsNothing);
        expect(applies(), 0);
        expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save and restart'));
        await tester.pumpAndSettle();
        expect(applies(), 1);
      },
    );

    testWidgets(
      'confirming sends one apply with the profile and closes with the outcome',
      (tester) async {
        await linked(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save and restart'));
        await tester.pumpAndSettle();

        final apply = server.requestsTo('POST', waApplyPath).single;
        expect(apply.queryParameters, {'profile': _profile});
        expect(jsonBody(apply), containsPair('profile', _profile));
        expect(opened, isFalse);
        final outcome = popped as WhatsAppSavedOutcome;
        expect(outcome.kind, WhatsAppSavedKind.restartRequested);
        expect(outcome.restartError, isNull);
        expect(cancels(), 0);
      },
    );

    testWidgets('a restart that could not be spawned is saved with its text', (
      tester,
    ) async {
      applyReply = (_) => _ok(waApplyRestartFailed);
      await linked(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();
      final outcome = popped as WhatsAppSavedOutcome;
      expect(outcome.kind, WhatsAppSavedKind.noRestart);
      expect(outcome.restartError, 'could not run /usr/bin/hermes');
    });

    testWidgets(
      'the server refusing keeps the page, with Finish offered again',
      (tester) async {
        applyReply = (_) => (status: 500, body: waSaveFailed);
        await linked(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save and restart'));
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        expect(find.text('Failed to save WhatsApp setup.'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);
      },
    );

    testWidgets(
      'Back is off while the apply is out, and a lost one is never resent',
      (tester) async {
        applyReply = hang;
        await linked(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save and restart'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Saving...'), findsOneWidget);

        // The route cannot be popped while the answer is awaited.
        final popped = await tester.binding.handlePopRoute();
        await tester.pump();
        expect(popped, isTrue);
        expect(opened, isTrue);
        expect(cancels(), 0);

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        expect(
          find.text('Could not confirm the setup was saved.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);
        expect(applies(), 1);

        // Leaving after a lost answer sends no second apply and no cancel.
        await tester.tap(find.byType(AdaptiveBackButton));
        await tester.pumpAndSettle();
        expect(applies(), 1);
        expect(cancels(), 0);
      },
    );

    testWidgets('Check finding WhatsApp on where it was off closes as saved', (
      tester,
    ) async {
      applyReply = (r) =>
          throw DioException.connectionError(requestOptions: r, reason: 'down');
      startReply = (_) => _ok(_live(waStartAlreadyLinked));
      await open(tester, size: computer, wasEnabled: false);
      await begin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(
        (popped as WhatsAppSavedOutcome).kind,
        WhatsAppSavedKind.unknownRestart,
      );
      expect(applies(), 1);
    });

    testWidgets('Check finding it on where it already was never says saved', (
      tester,
    ) async {
      applyReply = (r) =>
          throw DioException.connectionError(requestOptions: r, reason: 'down');
      startReply = (_) => _ok(_live(waStartAlreadyLinked));
      await open(tester, size: computer, wasEnabled: true);
      await begin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text("Couldn't confirm. Try again."), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check'), findsOneWidget);
      expect(applies(), 1);
    });

    testWidgets(
      'App Lock closing over the question cancels it, sending nothing',
      (tester) async {
        final lock = await enabledLock(tester);
        startReply = (_) => _ok(_live(waStartAlreadyLinked));
        statusReply = (_) => _ok(_live(waStatusConnected));
        await open(tester, size: computer, lock: lock);
        await begin(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Save and restart?'), findsOneWidget);

        lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump();
        await tester.tap(find.text('Save and restart'));
        // The account is being read again, a spinner that never settles.
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        expect(applies(), 0);
        expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);
      },
    );
  });
}
