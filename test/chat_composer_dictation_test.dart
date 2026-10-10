import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
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
    bool canRetry = false,
    Duration elapsed = Duration.zero,
  }) => DictationView(
    phase: phase,
    levels: const [0.2, 0.6, 0.4],
    elapsed: elapsed,
    canRetry: canRetry,
    engine: DictationEngine.device,
    onSend: () => calls.add('stop and send'),
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

  testWidgets('recording keeps the field and puts the waveform, stop and '
      'send in one row', (tester) async {
    text.text = 'Please book a';
    await pump(tester, view(DictationPhase.recording));

    final field = tester.widget<TextField>(find.byKey(chatComposerFieldKey));
    expect(field.readOnly, isTrue);
    expect(find.text('Please book a'), findsOneWidget);
    expect(find.byType(VoiceWaveform), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(button('Dictate'), findsNothing);
    expect(button('Add attachment'), findsNothing);

    await tester.tap(button('Stop voice input'));
    await tester.tap(button('Cancel voice input'));
    expect(calls, ['stop', 'cancel']);
  });

  testWidgets('send while recording stops and sends', (tester) async {
    text.text = 'Please';
    await pump(tester, view(DictationPhase.recording));

    await tester.tap(button('Send'));

    expect(calls, ['stop and send']);
  });

  testWidgets('settling says it is transcribing and still offers send', (
    tester,
  ) async {
    await pump(tester, view(DictationPhase.settling));

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(button('Stop voice input'), findsNothing);
    await tester.tap(button('Send'));
    expect(calls, ['stop and send']);
  });

  testWidgets('the field is editable again once idle', (tester) async {
    text.text = 'Please book a table';
    await pump(tester, view(DictationPhase.idle));

    final field = tester.widget<TextField>(find.byKey(chatComposerFieldKey));
    expect(field.readOnly, isFalse);
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
