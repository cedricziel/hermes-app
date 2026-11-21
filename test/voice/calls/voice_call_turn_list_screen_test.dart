import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:hermes_app/src/voice/voice_call_screen.dart';
import 'package:hermes_app/src/voice/widgets/voice_turn_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import 'call_harness.dart';

/// The open call screen over a call that is already running, with the turn
/// list and the Speak replies switch it draws from the call's own state.
void main() {
  late CallHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    h = CallHarness();
  });
  tearDown(() => h.dispose());

  Widget screen({AppLockController? lock}) {
    Widget app(Widget? gate) => MaterialApp(
      theme: buildHermesLightTheme(),
      builder: lock == null
          ? null
          : (context, child) => AppLockGate(child: child!),
      home: VoiceCallScreen(
        ongoing: h.call,
        checker: CallReadinessChecker(
          microphone: () async => true,
          input: () async => const CallInput(useDevice: true, installed: true),
          configuration: () async => throw StateError('unused'),
          connection: () async {},
          voiceModel: () async => throw StateError('unused'),
          gptLive: () async => false,
          isCurrent: () => true,
        ),
        isCurrent: () => true,
        startCall: (_, {required consented}) => throw StateError('unused'),
        requestMicrophone: () async => true,
        openMicrophoneSettings: () async {},
        openDictation: () async {},
        askHermes: (_) async => false,
      ),
    );
    return lock == null
        ? app(null)
        : ChangeNotifierProvider.value(value: lock, child: app(null));
  }

  Future<void> reply(WidgetTester tester, String words) => tester
      .runAsync(() async {
        h.agent.text!(words);
        h.agent.pending!.complete();
        h.socket.foreign.sink
          ..add(
            jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
          )
          ..add([0, 1, 2, 3])
          ..add(jsonEncode({'type': 'end'}));
        await pumpEventQueue();
      })
      .then((_) => tester.pump());

  Future<void> turn(WidgetTester tester) async {
    await tester.runAsync(() async {
      await h.activate();
      await h.say('What is on today?');
    });
    await tester.pump();
  }

  testWidgets('the caption of a turn being sent replaces the two lines', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await turn(tester);
    // The caption alone, in the slot above the controls.
    expect(find.text('What is on today?'), findsOneWidget);
    expect(find.byType(VoiceTurnList), findsNothing);
    await reply(tester, 'Two meetings.');
    expect(find.byType(VoiceTurnList), findsOneWidget);
    expect(
      find.textContaining('What is on today?', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Two meetings.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('You  ', findRichText: true), findsOneWidget);
    expect(find.textContaining('Hermes  ', findRichText: true), findsOneWidget);
  });

  testWidgets('Speak replies is a switch under the controls, on by default', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.runAsync(h.activate);
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Speak replies'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Speak replies')).dy,
      greaterThan(tester.getBottomLeft(find.text('End call')).dy),
    );
    expect(
      find.text('Speak, then pause. Hermes sends what you said.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(h.call.speakReplies, isFalse);
    expect(
      find.text('Replies are not spoken. The answer will be in the chat.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(h.call.speakReplies, isTrue);
  });

  testWidgets('with it off the finished reply says it is in the chat', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.runAsync(h.activate);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.runAsync(() => h.say('What is on today?'));
    await tester.runAsync(() async {
      h.agent.text!('Two meetings.');
      h.agent.pending!.complete();
      await pumpEventQueue();
    });
    await tester.pump();
    expect(
      find.textContaining('Reply is in the chat', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Two meetings.', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('a stopped call shows no turn text', (tester) async {
    await tester.pumpWidget(screen());
    await turn(tester);
    await reply(tester, 'Two meetings.');
    await tester.runAsync(() => h.call.end());
    await tester.pump();
    expect(h.call.phase, CallPhase.ended);
    expect(find.byType(VoiceTurnList), findsNothing);
    expect(
      find.textContaining('What is on today?', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Two meetings.', findRichText: true),
      findsNothing,
    );
    expect(find.text('Speak replies'), findsNothing);
  });

  testWidgets('under App Lock the words are not shown', (tester) async {
    final authenticator = FakeDeviceAuthenticator();
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
    await tester.pumpWidget(screen(lock: lock));
    await turn(tester);
    await reply(tester, 'Two meetings.');
    expect(
      find.textContaining('Two meetings.', findRichText: true),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
    await tester.pump();
    expect(lock.locked, isTrue);
    expect(find.byType(VoiceTurnList), findsNothing);
    expect(
      find.textContaining('Two meetings.', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('What is on today?', findRichText: true),
      findsNothing,
    );
    expect(find.text('Hermes is locked'), findsOneWidget);
    expect(h.call.ended, isFalse);
  });
}
