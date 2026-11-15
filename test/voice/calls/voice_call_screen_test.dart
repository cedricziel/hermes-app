import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:hermes_app/src/voice/calls/voice_model_route.dart';
import 'package:hermes_app/src/voice/voice_call_screen.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_setup_view.dart';
import 'package:hermes_app/src/voice/voice_support.dart';

import 'fakes.dart';

class _Flow {
  bool microphone = true, installed = true, configured = true, current = true;
  bool gptLive = false;
  int requests = 0, settings = 0, starts = 0, asks = 0, probes = 0;
  int consentGiven = 0, dictations = 0;
  final consents = <bool>[];
  bool grant = true, accepted = true;
  Completer<bool>? permission;
  Completer<void>? setup;
  final bridge = FakeCallBridge();
  final agent = FakeCallAgent();
  VoiceCall? call;
  CallReadiness? submitted;

  CallReadinessChecker get checker => CallReadinessChecker(
    microphone: () async => permission?.future ?? microphone,
    input: () async => CallInput(useDevice: true, installed: installed),
    configuration: () async => VoiceSupport(textToSpeech: configured),
    connection: () async {
      probes++;
    },
    voiceModel: () async => VoiceModelRoute.named,
    gptLive: () async => gptLive,
    isCurrent: () => current,
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => VoiceCallScreen(
                    checker: checker,
                    isCurrent: () => current,
                    requestMicrophone: () async {
                      requests++;
                      return microphone = grant;
                    },
                    openMicrophoneSettings: () async {
                      settings++;
                    },
                    onConsentGiven: () => consentGiven++,
                    openDictation: () async {
                      dictations++;
                      installed = true;
                    },
                    askHermes: (report) async {
                      asks++;
                      submitted = report;
                      await setup?.future;
                      return accepted;
                    },
                    startCall: (_, {required consented}) {
                      starts++;
                      consents.add(consented);
                      return call = VoiceCall(
                        bridge: bridge,
                        consented: consented,
                        agent: agent,
                        connect: ([_ = const {}]) async =>
                            throw StateError('unused'),
                        transcribe: (_) async => '',
                        prepare: () async {},
                      );
                    },
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Turns the consent switch on and presses Start.
  Future<void> consentAndStart(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Start call'));
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await call?.end();
      call?.dispose();
      await bridge.controller.close();
    });
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'ready checks wait for consent and Start, without setup or permission prompts',
    (tester) async {
      final flow = _Flow();
      await flow.open(tester);
      expect(flow.starts, 0);
      expect(flow.bridge.starts, 0);
      await flow.consentAndStart(tester);
      expect(flow.starts, 1);
      expect(flow.consents, [true]);
      expect(flow.consentGiven, 1);
      expect(flow.bridge.starts, 1);
      expect(flow.requests, 0);
      expect(flow.asks, 0);
      await flow.dispose(tester);
    },
  );

  testWidgets('a GPT-Live profile gets the note and can still start', (
    tester,
  ) async {
    final flow = _Flow()..gptLive = true;
    await flow.open(tester);
    expect(find.textContaining('GPT-Live'), findsOneWidget);
    await flow.consentAndStart(tester);
    expect(flow.starts, 1);
    await flow.dispose(tester);
  });

  testWidgets('no GPT-Live, no note', (tester) async {
    final flow = _Flow();
    await flow.open(tester);
    expect(find.textContaining('GPT-Live'), findsNothing);
    await flow.dispose(tester);
  });

  testWidgets('a start without consent is refused even when called directly', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    tester
        .widget<VoiceCallSetupView>(find.byType(VoiceCallSetupView))
        .onStart();
    await tester.pump();
    expect(flow.starts, 0);
    expect(flow.call, isNull);
    await flow.dispose(tester);
  });

  testWidgets('Start is disabled until the switch is on', (tester) async {
    final flow = _Flow();
    await flow.open(tester);
    FilledButton start() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Start call'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(start().onPressed, isNull);
    await tester.tap(find.text('Start call'), warnIfMissed: false);
    await tester.pump();
    expect(flow.starts, 0);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(start().onPressed, isNotNull);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(start().onPressed, isNull);
    expect(flow.starts, 0);
    await flow.dispose(tester);
  });

  testWidgets('Start a new call reopens the setup with the switch off', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(() => flow.call!.end());
    await tester.pump();
    await tester.tap(find.text('Start a new call'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start call'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(flow.starts, 1);
    await flow.consentAndStart(tester);
    expect(flow.starts, 2);
    expect(flow.consents, [true, true]);
    await flow.dispose(tester);
  });

  testWidgets('the switch is off again on every open', (tester) async {
    final flow = _Flow();
    await flow.open(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await flow.open(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await flow.dispose(tester);
  });

  testWidgets('Use dictation instead opens dictation and closes the screen', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await tester.tap(find.text('Use dictation instead'));
    await tester.pumpAndSettle();
    expect(flow.dictations, 1);
    expect(flow.starts, 0);
    expect(find.text('Open'), findsOneWidget);
    await flow.dispose(tester);
  });

  testWidgets(
    'a second quick tap on Mute unmutes, before the bridge confirms',
    (tester) async {
      final flow = _Flow();
      await flow.open(tester);
      await flow.consentAndStart(tester);
      await tester.runAsync(() async {
        flow.bridge.emit('activated');
        await pumpEventQueue();
      });
      await tester.pump();
      flow.bridge.muteGate = Completer<void>();
      await tester.tap(find.bySemanticsLabel('Mute').first);
      await tester.pump();
      expect(flow.call!.mutedRequested, isTrue);
      expect(flow.call!.muted, isFalse, reason: 'not confirmed yet');
      expect(find.text('Unmute'), findsOneWidget, reason: 'drawn at the tap');
      await tester.tap(find.bySemanticsLabel('Unmute').first);
      await tester.pump();
      expect(flow.call!.mutedRequested, isFalse);
      flow.bridge.muteGate!.complete();
      await flow.dispose(tester);
    },
  );

  testWidgets('End shows the ended notice', (tester) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(() => flow.call!.end());
    await tester.pump();
    expect(find.text('The microphone is closed.'), findsOneWidget);
    await flow.dispose(tester);
  });

  group('the notices of a turn that was not sent or was answered at once', () {
    for (final (notice, text) in [
      (CallNotice.busy, 'Hermes is still answering. Nothing was sent.'),
      (CallNotice.notSent, "Couldn't send. Nothing was sent."),
      (
        CallNotice.hermesQueued,
        'Hermes will answer your words after its current reply.',
      ),
      (
        CallNotice.hermesSteered,
        'Hermes took your words into its current reply.',
      ),
      (
        CallNotice.hermesRedirected,
        'Hermes is adjusting its current reply to your words.',
      ),
    ]) {
      testWidgets('$notice says "$text"', (tester) async {
        final flow = _Flow();
        await flow.open(tester);
        await flow.consentAndStart(tester);
        await tester.runAsync(() async {
          await pumpEventQueue();
          // The call's own turn logic is tested with the call; this shows
          // what the screen says for each notice it can be left with.
          flow.call!.notice = notice;
          await flow.call!.setSpeaker(true);
        });
        await tester.pump();
        expect(find.text(text), findsOneWidget);
        await flow.dispose(tester);
      });
    }

    testWidgets('only busy says Hermes is still answering', (tester) async {
      final flow = _Flow();
      await flow.open(tester);
      await flow.consentAndStart(tester);
      await tester.runAsync(() async {
        await pumpEventQueue();
        flow.call!.notice = CallNotice.notSent;
        await flow.call!.setSpeaker(true);
      });
      await tester.pump();
      expect(find.textContaining('still answering'), findsNothing);
      await flow.dispose(tester);
    });
  });

  testWidgets('a microphone that cannot be confirmed closed says so', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(() async {
      await pumpEventQueue();
      flow.bridge.stopCaptureError = StateError('no answer');
      await flow.call!.end();
    });
    await tester.pump();
    expect(
      find.text('The call ended, but the microphone may still be open.'),
      findsOneWidget,
    );
    await flow.dispose(tester);
  });

  testWidgets('Waiting for you tells the user capture is paused', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(() async {
      await pumpEventQueue();
      flow.bridge.emit('activated');
      flow.agent.setThreadAttention(true);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.textContaining('Capture is paused'), findsOneWidget);
    expect(flow.bridge.pauses, greaterThan(0));
    await flow.dispose(tester);
  });

  testWidgets('hiding the app ends the call with a notice off iOS', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(() async {
      await pumpEventQueue();
      flow.bridge.emit('activated');
      flow.call!.lifecycleChanged(AppLifecycleState.hidden);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(flow.call!.endReason, 'background');
    expect(find.text('The call ended.'), findsOneWidget);
    await flow.dispose(tester);
  });

  testWidgets(
    'microphone and language fixes require explicit taps then recheck',
    (tester) async {
      final flow = _Flow()
        ..microphone = false
        ..installed = false;
      await flow.open(tester);
      expect(flow.starts, 0);
      expect(flow.requests, 0);
      await tester.tap(find.text('Allow microphone'));
      await tester.pumpAndSettle();
      expect(flow.requests, 1);
      expect(flow.starts, 0);
      await tester.tap(find.text('Open Dictation settings'));
      await tester.pump();
      await tester.pump();
      expect(flow.starts, 0, reason: 'a fixed check never starts the call');
      await flow.consentAndStart(tester);
      expect(flow.starts, 1);
      expect(flow.asks, 0);
      await flow.dispose(tester);
    },
  );

  testWidgets(
    'denied permission offers Settings without repeating the prompt',
    (tester) async {
      final flow = _Flow()
        ..microphone = false
        ..grant = false;
      await flow.open(tester);
      await tester.tap(find.text('Allow microphone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open iOS Settings'));
      await tester.pumpAndSettle();
      expect(flow.requests, 1);
      expect(flow.settings, 1);
      expect(flow.starts, 0);
      expect(flow.asks, 0);
      await flow.dispose(tester);
    },
  );

  testWidgets(
    'failed submission stays retryable and duplicate taps send once',
    (tester) async {
      final flow = _Flow()
        ..configured = false
        ..accepted = false
        ..setup = Completer<void>();
      await flow.open(tester);
      expect(flow.asks, 0);
      await tester.tap(find.text('Ask Hermes to set this up'));
      await tester.pump();
      await tester.tap(find.text('Ask Hermes to set this up'));
      expect(flow.asks, 1);
      flow.setup!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('The setup request could not be sent. Try again.'),
        findsOneWidget,
      );
      flow.accepted = true;
      await tester.tap(find.text('Ask Hermes to set this up'));
      await tester.pumpAndSettle();
      expect(flow.asks, 2);
      expect(flow.submitted!.setupPrompt, contains('/api/audio/speak-stream'));
      expect(find.text('Open'), findsOneWidget);
      expect(flow.starts, 0);
      await flow.dispose(tester);
    },
  );

  testWidgets('runtime failure offers help only after an explicit tap', (
    tester,
  ) async {
    final flow = _Flow();
    await flow.open(tester);
    await flow.consentAndStart(tester);
    await tester.runAsync(
      () => flow.call!.end('Speech output could not be played.'),
    );
    await tester.pumpAndSettle();
    expect(flow.asks, 0);
    await tester.tap(find.text('Ask Hermes for help'));
    await tester.pumpAndSettle();
    expect(flow.asks, 1);
    expect(
      flow.submitted!.setupPrompt,
      contains('Speech output could not be played.'),
    );
    expect(find.text('Open'), findsOneWidget);
    await flow.dispose(tester);
  });

  testWidgets('retired chat never starts or submits when checks finish late', (
    tester,
  ) async {
    final flow = _Flow()..permission = Completer<bool>();
    await flow.open(tester);
    flow.current = false;
    flow.permission!.complete(true);
    await tester.pumpAndSettle();
    expect(flow.starts, 0);
    expect(flow.asks, 0);
    expect(flow.probes, 0);
    expect(find.textContaining('This chat changed.'), findsOneWidget);
    await flow.dispose(tester);
  });
}
