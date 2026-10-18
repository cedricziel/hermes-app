import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_recording_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_recording_controls.dart';

void main() {
  testWidgets('VoiceOver can start and finish without holding a pointer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var phase = VoiceRecordingPhase.idle;
      var starts = 0;
      var finishes = 0;
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HoldToRecordSend(
                recording: VoiceRecordingView(
                  phase: phase,
                  onStart: () {
                    starts++;
                    setState(() => phase = VoiceRecordingPhase.recording);
                  },
                  onFinish: () {
                    finishes++;
                    setState(() => phase = VoiceRecordingPhase.idle);
                  },
                  onCancel: () {
                    setState(() => phase = VoiceRecordingPhase.idle);
                  },
                ),
                onSend: () => sends++,
              ),
            ),
          ),
        ),
      );
      final button = tester.getSemantics(find.bySemanticsLabel('Send'));
      expect(
        button.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );
      button.owner!.performAction(button.id, SemanticsAction.longPress);
      await tester.pump();
      expect(starts, 1);
      final attach = tester.getSemantics(
        find.bySemanticsLabel('Attach voice message'),
      );
      attach.owner!.performAction(attach.id, SemanticsAction.tap);
      await tester.pump();
      expect(finishes, 1);
      expect(sends, 0);
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(sends, 1);
    } finally {
      semantics.dispose();
    }
  });
}
