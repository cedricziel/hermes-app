import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/active_call.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import 'call_harness.dart';

void main() {
  late CallHarness h;
  late FakeDeviceAuthenticator authenticator;
  late ActiveCallRegistry registry;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    authenticator = FakeDeviceAuthenticator();
    h = CallHarness();
    registry = ActiveCallRegistry();
    addTearDown(registry.dispose);
  });
  tearDown(() => h.dispose());

  Future<AppLockController> lockedController(WidgetTester tester) async {
    final lock = AppLockController(
      authenticator: authenticator,
      coverWhenInactive: true,
    );
    addTearDown(lock.dispose);
    await tester.runAsync(() async {
      await lock.load();
      await lock.setEnabled(true);
    });
    authenticator.succeeds = false;
    return lock;
  }

  /// The chat is a page that shows the call's words, under the gate.
  Future<void> pump(WidgetTester tester, AppLockController lock) =>
      tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: lock),
            ChangeNotifierProvider.value(value: registry),
          ],
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            builder: (context, child) => AppLockGate(child: child!),
            home: ListenableBuilder(
              listenable: h.call,
              builder: (_, _) => Text('words: ${h.call.caption}'),
            ),
          ),
        ),
      );

  Future<void> startCall(WidgetTester tester) async {
    await tester.runAsync(() async {
      await h.activate();
      registry.attach(h.call);
      await h.say('Private request');
    });
  }

  testWidgets('locking never ends a call, and the cover keeps its mark', (
    tester,
  ) async {
    final lock = await lockedController(tester);
    await startCall(tester);
    await pump(tester, lock);
    expect(find.text('words: Private request'), findsOneWidget);
    // Lock it.
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    expect(lock.locked, isTrue);
    expect(h.call.ended, isFalse);
    expect(
      find.textContaining('Hands-free on', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('End'), findsOneWidget);
    expect(find.textContaining('Private'), findsNothing);
    expect(find.textContaining('words:'), findsNothing);
    expect(find.text('Hermes is locked'), findsOneWidget);
  });

  testWidgets('End on the cover ends the call', (tester) async {
    final lock = await lockedController(tester);
    await startCall(tester);
    await pump(tester, lock);
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    await tester.tap(find.text('End'));
    // The teardown's steps run in the test's fake time.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(h.call.ended, isTrue);
    expect(
      find.textContaining('Hands-free on', findRichText: true),
      findsNothing,
    );
    expect(find.text('Hermes is locked'), findsOneWidget);
  });

  testWidgets('the mark follows the microphone and goes with the call', (
    tester,
  ) async {
    final lock = await lockedController(tester);
    await startCall(tester);
    await pump(tester, lock);
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      await h.call.setMuted(true);
    });
    await tester.pump();
    expect(find.textContaining('muted', findRichText: true), findsOneWidget);
    await tester.runAsync(() => h.call.end());
    await tester.pump();
    expect(
      find.textContaining('Hands-free on', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('an unconfirmed close keeps its warning on the cover', (
    tester,
  ) async {
    h.bridge.stopCaptureGate = Completer<void>();
    final lock = await lockedController(tester);
    await startCall(tester);
    await pump(tester, lock);
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    unawaited(registry.end());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(registry.microphoneMayBeOpen, isTrue);
    expect(
      find.text('Microphone may still be open', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('End'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
    expect(find.textContaining('Private'), findsNothing);
    expect(find.text('Hermes is locked'), findsOneWidget);
  });

  testWidgets('no call, no mark', (tester) async {
    final lock = await lockedController(tester);
    await pump(tester, lock);
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    expect(find.text('Hermes is locked'), findsOneWidget);
    expect(
      find.textContaining('Hands-free on', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('the call screen and notices show nothing while covered', (
    tester,
  ) async {
    final lock = await lockedController(tester);
    await startCall(tester);
    await pump(tester, lock);
    h.call.notice = CallNotice.transcription;
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    expect(find.textContaining("Couldn't hear"), findsNothing);
    expect(find.textContaining('Private'), findsNothing);
  });
}
