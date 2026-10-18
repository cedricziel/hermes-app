import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';

import '../../support/accessibility.dart';

void main() {
  testWidgets('iOS call controls are named, selected and actionable', (
    tester,
  ) async {
    var mute = 0, speaker = 0, end = 0, chat = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: VoiceCallView(
            phase: CallPhase.listening,
            elapsed: const Duration(seconds: 12),
            muted: true,
            speaker: false,
            route: 'iPhone',
            onMute: () => mute++,
            onSpeaker: () => speaker++,
            onEnd: () => end++,
            onShowChat: () => chat++,
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    try {
      for (final label in ['Unmute', 'Speaker', 'End call']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label).first),
          namedButton(label),
        );
      }
      await tester.tap(find.bySemanticsLabel('Unmute').first);
      await tester.tap(find.bySemanticsLabel('Speaker').first);
      await tester.tap(find.bySemanticsLabel('End call').first);
      await tester.tap(find.text('Show chat'));
      expect([mute, speaker, end, chat], [1, 1, 1, 1]);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
