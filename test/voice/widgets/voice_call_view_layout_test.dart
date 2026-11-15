import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_footer.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';

import 'voice_call_widgets_support.dart';

const _caption =
    'Could you check the third paragraph of the report for me and tell me '
    'whether the numbers still add up?';

Widget _view(CallPhase phase, {bool notice = false, bool caption = true}) =>
    VoiceCallView(
      phase: phase,
      elapsed: const Duration(seconds: 75),
      muted: false,
      speaker: false,
      route: 'iPhone',
      caption: caption ? _caption : '',
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

/// Whether [f] lies fully inside the screen and inside the viewport of the
/// scroll view it sits in, without scrolling.
void _inView(WidgetTester tester, Finder f, Size size, String reason) {
  expect(f, findsWidgets, reason: reason);
  final r = tester.getRect(f.first);
  expect(
    r.top >= -0.5 &&
        r.bottom <= size.height + 0.5 &&
        r.left >= -0.5 &&
        r.right <= size.width + 0.5,
    isTrue,
    reason: '$reason is off screen: $r',
  );
  final scrollables = find.ancestor(
    of: f.first,
    matching: find.byType(Scrollable),
  );
  for (final e in scrollables.evaluate()) {
    final v = tester.getRect(find.byWidget(e.widget));
    expect(
      r.top >= v.top - 0.5 && r.bottom <= v.bottom + 0.5,
      isTrue,
      reason: '$reason is scrolled out of its viewport $v: $r',
    );
  }
}

Widget _stopped({required bool words}) => VoiceCallView(
  phase: CallPhase.failed,
  elapsed: const Duration(seconds: 75),
  muted: false,
  speaker: false,
  route: 'iPhone',
  error: words ? _caption : 'The call was interrupted.',
  notice: words
      ? const VoiceCallNotice(
          tone: VoiceCallNoticeTone.warning,
          title: "Couldn't send. Nothing was sent.",
          detail: 'Your words are not in the chat.',
        )
      : null,
  onAskHermes: () {},
  onStartNew: () {},
  onEnd: () {},
  onMute: () {},
  onSpeaker: () {},
  onShowChat: () {},
);

void main() {
  // The controls are pinned: what is heard or noticed never moves them.
  for (final size in const [Size(390, 844), Size(390, 667), Size(480, 800)]) {
    testWidgets(
      'End does not move with a caption or a notice, ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final at = <Offset>[];
        for (final (caption, notice) in [
          (false, false),
          (true, false),
          (false, true),
          (true, true),
        ]) {
          await pumpVoice(
            tester,
            _view(CallPhase.listening, caption: caption, notice: notice),
            size: size,
          );
          at.add(tester.getTopLeft(find.text('End call')));
        }
        expect(at.toSet(), hasLength(1), reason: '$at');
      },
    );

    testWidgets(
      'the stopped buttons do not move with words, ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final labels = [
          'Back to chat',
          'Ask Hermes for help',
          'Start a new call',
        ];
        final positions = <List<Offset>>[];
        for (final words in [false, true]) {
          await pumpVoice(tester, _stopped(words: words), size: size);
          positions.add([
            for (final l in labels) tester.getTopLeft(find.text(l)),
          ]);
        }
        expect(positions[0], positions[1]);
      },
    );
  }

  const sizes = [
    Size(390, 667),
    Size(390, 844),
    Size(480, 800),
    Size(844, 390),
    Size(667, 375),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'state word and End in view, ${size.width.toInt()}x${size.height.toInt()} at ${scale}x',
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
            final ended = phase == CallPhase.ended;
            _inView(
              tester,
              find.text(ended ? 'Call ended' : 'Listening'),
              size,
              'state word $phase',
            );
            _inView(
              tester,
              find.text(ended ? 'Back to chat' : 'End call'),
              size,
              'End $phase',
            );
          }
        },
      );
    }
  }

  testWidgets('large text leaves the state room: the controls are capped', (
    tester,
  ) async {
    await pumpVoice(
      tester,
      _view(CallPhase.listening),
      size: const Size(390, 667),
      scale: 3,
    );
    final stateView = tester.getRect(
      find
          .ancestor(
            of: find.text('Listening'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(stateView.height, greaterThan(70));
  });

  testWidgets('End is one unwrapped row in landscape at 3x', (tester) async {
    await pumpVoice(
      tester,
      _view(CallPhase.listening),
      size: const Size(844, 390),
      scale: 3,
    );
    final mute = tester.getRect(find.text('Mute'));
    final end = tester.getRect(find.text('End call'));
    expect(end.top, mute.top, reason: '$mute $end');
  });

  for (final size in const [Size(390, 667), Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'notice and caption in view, ${size.width.toInt()}x${size.height.toInt()} at ${scale}x',
        (tester) async {
          await pumpVoice(
            tester,
            _view(CallPhase.listening, notice: true),
            size: size,
            scale: scale,
          );
          if (scale == 1) {
            _inView(
              tester,
              find.textContaining("Couldn't send"),
              size,
              'notice',
            );
            _inView(
              tester,
              find.textContaining('not in the chat'),
              size,
              'detail',
            );
          }
          if (scale > 1) {
            // At large text the notice is longer than the slot: it starts in
            // view and the rest scrolls inside the slot.
            final title = tester.getRect(find.textContaining("Couldn't send"));
            final slot = tester.getRect(
              find
                  .ancestor(
                    of: find.textContaining("Couldn't send"),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(title.top, greaterThanOrEqualTo(slot.top - 0.5));
            expect(title.top, lessThan(slot.bottom - 20));
          }
          // The slot sits below the state, not in its scroll view.
          final slotView = tester.getRect(
            find
                .ancestor(
                  of: find.textContaining('add up?'),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            slotView.top,
            greaterThanOrEqualTo(tester.getRect(find.text('Listening')).bottom),
          );
          // A long caption shows its last lines: its bottom edge is in the
          // slot's viewport.
          final caption = tester.getRect(find.textContaining('add up?'));
          final viewport = tester.getRect(
            find
                .ancestor(
                  of: find.textContaining('add up?'),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(caption.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
          expect(caption.bottom, greaterThan(viewport.top + 20));
        },
      );
    }
  }

  testWidgets('cut state content scrolls to its end behind the fade', (
    tester,
  ) async {
    // Text at 3x on a short phone does not fit its area. The fade itself is
    // looked at in the workflow screenshots; here the content must still
    // scroll, also after the fade has come in.
    await pumpVoice(
      tester,
      _view(CallPhase.listening),
      size: const Size(390, 667),
      scale: 3,
    );
    await tester.pump();
    await tester.pump();
    final area = find.ancestor(
      of: find.text('Listening'),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(area.first).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(
      find.ancestor(of: area.first, matching: find.byType(ShaderMask)),
      findsWidgets,
    );
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(position.pixels, position.maxScrollExtent);
  });
}
