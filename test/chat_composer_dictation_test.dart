import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_waveform.dart';

import 'support/accessibility.dart';

void main() {
  final text = TextEditingController();
  late List<String> calls;

  setUp(() {
    text.clear();
    calls = [];
  });

  DictationView view(
    DictationPhase phase, {
    String liveTranscript = '',
    bool canRetry = false,
    Duration elapsed = Duration.zero,
  }) => DictationView(
    phase: phase,
    levels: const [0.2, 0.6, 0.4],
    elapsed: elapsed,
    liveTranscript: liveTranscript,
    canRetry: canRetry,
    onStart: () => calls.add('start'),
    onStop: () => calls.add('stop'),
    onCancel: () => calls.add('cancel'),
    onRetry: () => calls.add('retry'),
    onDismiss: () => calls.add('dismiss'),
  );

  Future<void> pump(WidgetTester tester, DictationView? dictation) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                controller: text,
                onSend: (_) => calls.add('send'),
                onRemoveAttachment: (_) {},
                dictation: dictation,
              ),
            ),
          ),
        ),
      );

  Finder button(String label) => find.bySemanticsLabel(label);

  testWidgets('without dictation there is no microphone', (tester) async {
    await pump(tester, null);

    expect(button('Dictate'), findsNothing);
  });

  testWidgets('the microphone sits beside send and starts dictation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, view(DictationPhase.idle));

    expect(tester.getSemantics(button('Dictate')), namedButton('Dictate'));
    await tester.tap(button('Dictate'));
    expect(calls, ['start']);
    semantics.dispose();
  });

  testWidgets('recording swaps the field for the waveform and the microphone '
      'for stop', (tester) async {
    text.text = 'Please';
    await pump(
      tester,
      view(DictationPhase.recording, elapsed: const Duration(seconds: 7)),
    );

    expect(find.byKey(chatComposerFieldKey), findsNothing);
    expect(find.byType(VoiceWaveform), findsOneWidget);
    expect(find.text('0:07'), findsOneWidget);
    expect(button('Dictate'), findsNothing);

    await tester.tap(button('Stop voice input'));
    await tester.tap(button('Cancel voice input'));
    expect(calls, ['stop', 'cancel']);
  });

  testWidgets('sending waits until the transcript lands', (tester) async {
    text.text = 'Please';
    await pump(tester, view(DictationPhase.recording));

    final send = tester.widget<IconButton>(
      find.ancestor(of: button('Send'), matching: find.byType(IconButton)),
    );
    expect(send.onPressed, isNull);
  });

  testWidgets('the live transcript shows over the waveform', (tester) async {
    await pump(
      tester,
      view(DictationPhase.recording, liveTranscript: 'book a table'),
    );

    expect(find.text('book a table'), findsOneWidget);
    expect(text.text, isEmpty, reason: 'the draft is not edited');
  });

  testWidgets('settling says it is transcribing', (tester) async {
    await pump(tester, view(DictationPhase.settling));

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(button('Stop voice input'), findsNothing);
  });

  testWidgets('the field returns with the draft once idle', (tester) async {
    text.text = 'Please book a table';
    await pump(tester, view(DictationPhase.idle));

    expect(find.byKey(chatComposerFieldKey), findsOneWidget);
    expect(find.byType(VoiceWaveform), findsNothing);
  });

  testWidgets('a failure offers Retry and can be dismissed', (tester) async {
    await pump(tester, view(DictationPhase.failed, canRetry: true));

    expect(find.text('Couldn’t transcribe the recording.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.tap(button('Dismiss'));
    expect(calls, ['retry', 'dismiss']);
  });

  testWidgets('silence says no speech was heard', (tester) async {
    await pump(tester, view(DictationPhase.noSpeech));

    expect(find.text('No speech detected.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('denied access says where to turn it on', (tester) async {
    await pump(tester, view(DictationPhase.denied));

    expect(find.textContaining('Microphone access is off'), findsOneWidget);
  });
}
