import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/widgets/voice_waveform.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoiceWaveform waveform) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildHermesDarkTheme(),
          home: Scaffold(body: waveform),
        ),
      );

  testWidgets('recording shows the dot and the time as m:ss', (tester) async {
    await pump(
      tester,
      const VoiceWaveform(
        levels: [0.1, 0.9],
        elapsed: Duration(minutes: 1, seconds: 5),
      ),
    );

    expect(find.text('1:05'), findsOneWidget);
    expect(find.bySemanticsLabel('Recording'), findsOneWidget);
  });

  testWidgets('settling drops the dot and says it is transcribing', (
    tester,
  ) async {
    await pump(
      tester,
      const VoiceWaveform(
        levels: [0.1, 0.9],
        elapsed: Duration(seconds: 12),
        settling: true,
      ),
    );

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.text('0:12'), findsNothing);
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
        liveTranscript: 'a long ' * 40,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
