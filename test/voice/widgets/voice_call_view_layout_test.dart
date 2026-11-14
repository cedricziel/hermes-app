import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';

import 'voice_call_widgets_support.dart';

Widget _view(CallPhase phase, {bool caption = true, bool notice = false}) =>
    VoiceCallView(
      phase: phase,
      elapsed: const Duration(seconds: 75),
      muted: false,
      speaker: false,
      route: 'iPhone',
      caption: caption
          ? 'Could you check the third paragraph of the report for me and '
                'tell me whether the numbers still add up?'
          : '',
      footer: VoiceCallFooter.androidLeave,
      notice: notice
          ? const VoiceCallNotice(
              tone: VoiceCallNoticeTone.warning,
              title: "Couldn't send. Nothing was sent.",
              detail: 'Your words are not in the chat.',
            )
          : null,
      onEnd: () {},
      onMute: () {},
      onSpeaker: () {},
      onShowChat: () {},
    );

bool _inside(WidgetTester tester, Finder f, Size size) {
  final r = tester.getRect(f.first);
  return r.top >= 0 &&
      r.bottom <= size.height &&
      r.left >= 0 &&
      r.right <= size.width;
}

void main() {
  const sizes = [
    Size(390, 667),
    Size(390, 844),
    Size(844, 390),
    Size(667, 375),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'no overflow, End reachable, ${size.width.toInt()}x${size.height.toInt()} at ${scale}x',
        (tester) async {
          for (final (phase, notice) in [
            (CallPhase.listening, false),
            (CallPhase.listening, true),
            (CallPhase.ended, true),
          ]) {
            await pumpVoice(
              tester,
              _view(phase, notice: notice),
              size: size,
              scale: scale,
            );
            expect(tester.takeException(), isNull, reason: '$phase');
            final word = phase == CallPhase.ended ? 'Call ended' : 'Listening';
            if (scale == 1) {
              // The state word and the caption are in view without scrolling.
              expect(
                _inside(tester, find.text(word), size),
                isTrue,
                reason: word,
              );
              expect(
                _inside(tester, find.textContaining('Could you check'), size),
                isTrue,
              );
            }
            final end = phase == CallPhase.ended
                ? find.text('Back to chat')
                : find.text('End call');
            if (scale == 1) {
              expect(_inside(tester, end, size), isTrue, reason: 'end $phase');
            } else {
              // Large text may scroll the controls, which stay reachable.
              await tester.ensureVisible(end.first);
              await tester.pump();
              expect(_inside(tester, end, size), isTrue);
            }
          }
        },
      );
    }
  }

  testWidgets('a notice is in view above the controls on a short phone', (
    tester,
  ) async {
    const size = Size(390, 667);
    await pumpVoice(
      tester,
      _view(CallPhase.listening, notice: true),
      size: size,
    );
    expect(_inside(tester, find.textContaining("Couldn't send"), size), isTrue);
  });
}
