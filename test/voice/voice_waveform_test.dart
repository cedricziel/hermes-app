import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/widgets/voice_waveform.dart';

void main() {
  /// The waveform sits between cancel and stop in a phone's composer row.
  Future<void> pump(WidgetTester tester, VoiceWaveform waveform) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildHermesDarkTheme(),
          home: Scaffold(
            body: Center(child: SizedBox(width: 200, child: waveform)),
          ),
        ),
      );

  testWidgets('recording shows the dot and no clock', (tester) async {
    await pump(
      tester,
      const VoiceWaveform(
        levels: [0.1, 0.9],
        elapsed: Duration(minutes: 1, seconds: 5),
      ),
    );

    expect(find.bySemanticsLabel('Recording'), findsOneWidget);
    expect(find.text('1:05'), findsNothing);
  });

  for (final (onDevice, label) in [
    (true, 'On this device'),
    (false, 'Hermes'),
  ]) {
    testWidgets('names the engine: $label', (tester) async {
      await pump(
        tester,
        VoiceWaveform(
          levels: const [0.1, 0.9],
          elapsed: const Duration(seconds: 3),
          onDevice: onDevice,
        ),
      );

      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('settling drops the dot and says it is transcribing', (
    tester,
  ) async {
    await pump(
      tester,
      const VoiceWaveform(
        levels: [0.1, 0.9],
        elapsed: Duration(seconds: 12),
        settling: true,
        onDevice: true,
      ),
    );

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.text('On this device'), findsNothing);
    expect(find.bySemanticsLabel('Recording'), findsNothing);
  });

  testWidgets('more levels than fit are cut from the oldest end', (
    tester,
  ) async {
    await pump(
      tester,
      VoiceWaveform(
        levels: List.generate(500, (i) => (i % 10) / 10),
        elapsed: Duration.zero,
        onDevice: true,
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow row at large text drops the name, not the controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesDarkTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 110,
                child: VoiceWaveform(
                  levels: const [0.1, 0.9],
                  elapsed: Duration.zero,
                  onDevice: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
