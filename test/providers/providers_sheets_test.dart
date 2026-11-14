import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:hermes_app/src/providers/widgets/provider_list_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import 'fake_provider_backend.dart';
import 'providers_screen_rig.dart';

const _settle = ProvidersRig.settle;
const _fakeKey = 'sk-or-v1-test-aaaa-4f2a';

Finder _row(String id) => find.byKey(ValueKey('provider-row-$id'));

/// OpenRouter connected with a default, so a second provider asks.
FakeProviderBackend _connected() => FakeProviderBackend()
  ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_fakeKey)
  ..defaultProvider = 'openrouter'
  ..defaultModel = 'example-model-a';

/// What happens when a sign-in is approved later, while the person is on the
/// list: the step opens on its own, and closing it any way leaves the screen.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Starts the Nous sign-in, leaves its sheet, and lets Hermes approve it.
  Future<ProvidersRig> approvedLater(
    WidgetTester tester, {
    required FakeProviderBackend backend,
    ProvidersEntry entry = ProvidersEntry.sidebar,
  }) async {
    final rig = ProvidersRig(backend: backend);
    await rig.pump(tester, pushed: true, entry: entry);
    await tester.tap(_row('nous'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.text('Waiting for sign-in…'), findsOneWidget);
    backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    return rig;
  }

  group('the step that opens by itself', () {
    testWidgets('Cancel leaves the screen open', (tester) async {
      await approvedLater(tester, backend: FakeProviderBackend());
      expect(find.text("You're ready"), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ProviderListView), findsOneWidget);
    });

    testWidgets('Keep leaves the screen open', (tester) async {
      await approvedLater(tester, backend: _connected());
      expect(find.text('Keep example-model-a'), findsOneWidget);

      await tester.tap(find.text('Keep example-model-a'));
      await _settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ProviderListView), findsOneWidget);
    });

    testWidgets('Not now leaves the screen open', (tester) async {
      final backend = _connected()..recommended.remove('nous');
      await approvedLater(tester, backend: backend);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await _settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ProviderListView), findsOneWidget);
    });

    testWidgets('Start chatting leaves the chat\'s screen, not Profiles', (
      tester,
    ) async {
      await approvedLater(tester, backend: FakeProviderBackend());
      await tester.tap(find.text('Start chatting'));
      await _settle(tester);
      expect(find.byType(ProviderListView), findsNothing);
      expect(find.text('open providers'), findsOneWidget);
    });

    testWidgets('Start chatting stays on the list from Profiles', (
      tester,
    ) async {
      await approvedLater(
        tester,
        backend: FakeProviderBackend(),
        entry: ProvidersEntry.profiles,
      );
      await tester.tap(find.text('Start chatting'));
      await _settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ProviderListView), findsOneWidget);
    });

    testWidgets('waits while the model picker is open', (tester) async {
      final backend = _connected();
      final rig = ProvidersRig(backend: backend);
      await rig.pump(tester, pushed: true);
      await tester.tap(_row('nous'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      // The default model row opens the picker over the screen.
      await tester.tap(find.textContaining('example-model-a').first);
      await _settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
      await tester.pump(const Duration(seconds: 6));
      await _settle(tester);
      expect(find.textContaining('Keep example-model-a'), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(find.text('Keep example-model-a'), findsOneWidget);
    });

    testWidgets('waits while "Stop signing in?" is up', (tester) async {
      final backend = _connected();
      final rig = ProvidersRig(backend: backend);
      await rig.pump(tester, pushed: true);
      await tester.tap(_row('nous'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      await tester.tap(find.text('Stop'));
      await _settle(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
      await tester.pump(const Duration(seconds: 6));
      await _settle(tester);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Keep waiting'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(find.text('Keep example-model-a'), findsOneWidget);
    });
  });

  group('App Lock', () {
    late AppLockController lock;

    Future<ProvidersRig> pump(
      WidgetTester tester,
      TargetPlatform platform, {
      FakeProviderBackend? backend,
    }) async {
      lock = AppLockController(
        authenticator: FakeDeviceAuthenticator(),
        coverWhenInactive: true,
      );
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      await tester.runAsync(() => lock.setEnabled(true));
      final rig = ProvidersRig(backend: backend);
      await rig.pump(
        tester,
        platform: platform,
        size: platform == TargetPlatform.macOS
            ? const Size(1000, 800)
            : const Size(390, 844),
        providers: [
          ChangeNotifierProvider<AppLockController>.value(value: lock),
        ],
      );
      return rig;
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets(
        '$platform: going inactive keeps the key, locking clears it',
        (tester) async {
          final rig = await pump(tester, platform);
          await tester.tap(_row('openrouter'));
          await _settle(tester);
          await tester.enterText(find.byType(TextField), _fakeKey);
          await tester.pump();
          final field = tester.widget<TextField>(find.byType(TextField));

          lock.didChangeAppLifecycleState(AppLifecycleState.inactive);
          await tester.pump();
          expect(field.controller!.text, _fakeKey);

          lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
          await tester.pump();
          expect(lock.locked, isTrue);
          expect(field.controller!.text, isEmpty);
          expect(rig.backend.server.requestsTo('PUT', '/api/env'), isEmpty);
        },
      );
    }

    testWidgets(
      'locking while "Send the key unencrypted?" is up saves nothing',
      (tester) async {
        final rig = await pump(tester, TargetPlatform.iOS);
        rig.backend.server.on(
          'POST',
          '/api/providers/custom-endpoints/validate',
          {
            'ok': true,
            'reachable': true,
            'models': ['example-model-a'],
            'resolved_base_url': 'http://models.example.net/v1',
          },
        );
        await tester.scrollUntilVisible(find.text('Custom endpoint'), 200);
        await tester.tap(find.text('Custom endpoint'));
        await _settle(tester);
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Lab');
        await tester.enterText(fields.at(1), 'http://models.example.net/v1');
        await tester.enterText(fields.at(2), 'test-key-not-real');
        await tester.pump();
        await tester.tap(find.text('Check connection'));
        await _settle(tester);
        await tester.tap(find.text('Save'));
        await _settle(tester);
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);

        lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump();
        await tester.tap(find.text('Save anyway').last);
        await _settle(tester);

        expect(
          rig.backend.server.requestsTo(
            'POST',
            '/api/providers/custom-endpoints',
          ),
          isEmpty,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(2))
              .controller!
              .text,
          isEmpty,
        );
      },
    );
  });
}
