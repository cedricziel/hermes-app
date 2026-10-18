import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:hermes_app/src/voice/voice_call_screen.dart';
import 'package:hermes_app/src/voice/voice_support.dart';

import 'fakes.dart';

class _Flow {
  bool microphone = true, installed = true, configured = true, current = true;
  int requests = 0, settings = 0, starts = 0, asks = 0, probes = 0;
  bool grant = true, accepted = true;
  Completer<bool>? permission;
  Completer<void>? setup;
  final bridge = FakeCallBridge();
  VoiceCall? call;
  CallReadiness? submitted;

  CallReadinessChecker get checker => CallReadinessChecker(
    microphone: () async => permission?.future ?? microphone,
    input: () async => CallInput(useDevice: true, installed: installed),
    configuration: () async => VoiceSupport(textToSpeech: configured),
    connection: () async {
      probes++;
    },
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
                    openDictation: () async {
                      installed = true;
                    },
                    askHermes: (report) async {
                      asks++;
                      submitted = report;
                      await setup?.future;
                      return accepted;
                    },
                    startCall: (_) {
                      starts++;
                      return call = VoiceCall(
                        bridge: bridge,
                        agent: FakeCallAgent(),
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
    'ready checks start one call without setup or permission prompts',
    (tester) async {
      final flow = _Flow();
      await flow.open(tester);
      expect(flow.starts, 1);
      expect(flow.bridge.starts, 1);
      expect(flow.requests, 0);
      expect(flow.asks, 0);
      await flow.dispose(tester);
    },
  );

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
