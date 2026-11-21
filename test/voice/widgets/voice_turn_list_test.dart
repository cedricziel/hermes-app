import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_phase.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';
import 'package:hermes_app/src/voice/widgets/voice_turn_list.dart';

import 'voice_call_widgets_support.dart';

const _long =
    'You have two meetings. The design review runs from 14:00 to 15:00 in the large room, and the call with Sam moved to video. Between them you have an hour, which is enough for the report. After 17:00 nothing is planned, so the evening is free.';

VoiceCallView _view({
  CallPhase phase = CallPhase.listening,
  String caption = '',
  String you = '',
  String hermes = '',
  bool inChat = false,
  bool speak = true,
  ValueChanged<bool>? onSpeak,
}) => VoiceCallView(
  phase: phase,
  elapsed: Duration.zero,
  muted: false,
  speaker: false,
  route: '',
  caption: caption,
  turnYou: you,
  turnHermes: hermes,
  replyInChat: inChat,
  speakReplies: speak,
  onSpeakRepliesChanged: onSpeak,
  onMute: () {},
  onSpeaker: () {},
  onEnd: () {},
  onShowChat: () {},
);

void main() {
  group('VoiceTurnList', () {
    testWidgets('draws nothing without a line', (tester) async {
      await pumpVoice(tester, const VoiceTurnList());
      expect(tester.getSize(find.byType(VoiceTurnList)), Size.zero);
    });

    testWidgets('two plain lines, You then Hermes, no bubble', (tester) async {
      await pumpVoice(
        tester,
        const VoiceTurnList(you: 'Hello there', hermes: 'Hi, how can I help?'),
      );
      final you = tester.getTopLeft(find.textContaining('Hello there'));
      final hermes = tester.getTopLeft(find.textContaining('Hi, how'));
      expect(hermes.dy, greaterThan(you.dy));
      expect(find.textContaining('You  ', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('Hermes  ', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('a reply not started shows only the user line', (tester) async {
      await pumpVoice(tester, const VoiceTurnList(you: 'Hello there'));
      expect(find.textContaining('Hermes', findRichText: true), findsNothing);
    });

    testWidgets('Reply is in the chat replaces the words', (tester) async {
      await pumpVoice(
        tester,
        const VoiceTurnList(you: 'Hi', hermes: 'ignored', replyInChat: true),
      );
      expect(
        find.textContaining('Reply is in the chat', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('ignored', findRichText: true), findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('long words end in an ellipsis at ${scale}x, in bounds', (
        tester,
      ) async {
        await pumpVoice(
          tester,
          const VoiceTurnList(you: _long, hermes: _long),
          scale: scale,
          size: const Size(390, 844),
        );
        expect(tester.takeException(), isNull);
        final texts = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((t) => t.maxLines != null)
            .toList();
        expect(texts.map((t) => t.maxLines), [
          VoiceTurnList.youLines,
          VoiceTurnList.hermesLines,
        ]);
        expect(texts.every((t) => t.overflow == TextOverflow.ellipsis), isTrue);
        expect(tester.getSize(find.byType(VoiceTurnList)).width, lessThan(391));
      });
    }
  });

  group('VoiceCallView', () {
    testWidgets('shows the two lines under the hint', (tester) async {
      await pumpVoice(tester, _view(you: 'Hello there', hermes: 'Hi!'));
      final hint = tester.getTopLeft(find.textContaining('Speak, then pause'));
      final line = tester.getTopLeft(find.textContaining('Hello there'));
      expect(line.dy, greaterThan(hint.dy));
    });

    testWidgets('the caption of a turn being sent replaces them', (
      tester,
    ) async {
      await pumpVoice(
        tester,
        _view(
          phase: CallPhase.sending,
          caption: 'Next question',
          you: 'Old question',
          hermes: 'Old answer',
        ),
      );
      expect(find.text('Next question'), findsOneWidget);
      expect(find.textContaining('Old', findRichText: true), findsNothing);
    });

    for (final phase in [CallPhase.ended, CallPhase.failed]) {
      testWidgets('a stopped call ($phase) shows none', (tester) async {
        await pumpVoice(tester, _view(phase: phase, you: 'Old', hermes: 'Old'));
        expect(find.byType(VoiceTurnList), findsNothing);
        expect(find.textContaining('Old', findRichText: true), findsNothing);
      });
    }

    testWidgets('no switch without a callback, one under the controls with', (
      tester,
    ) async {
      await pumpVoice(tester, _view());
      expect(find.byType(Switch), findsNothing);
      final changes = <bool>[];
      await pumpVoice(tester, _view(onSpeak: changes.add));
      expect(find.text('Speak replies'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      expect(changes, [false]);
    });

    testWidgets('off changes the listening hint only', (tester) async {
      await pumpVoice(tester, _view(speak: false, onSpeak: (_) {}));
      expect(
        find.text('Replies are not spoken. The answer will be in the chat.'),
        findsOneWidget,
      );
      expect(find.textContaining('Speak, then pause'), findsNothing);
      await pumpVoice(
        tester,
        _view(phase: CallPhase.thinking, speak: false, onSpeak: (_) {}),
      );
      expect(find.text('Hermes is working on your request.'), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('long lines and the switch fit at ${scale}x', (tester) async {
        await pumpVoice(
          tester,
          _view(you: _long, hermes: _long, onSpeak: (_) {}),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
