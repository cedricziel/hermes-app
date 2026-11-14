import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_notice.dart';

import 'voice_call_widgets_support.dart';

void main() {
  testWidgets('a warning carries the triangle and its words', (tester) async {
    await pumpVoice(
      tester,
      const VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: 'Hermes could not speak this reply.',
        detail: 'The reply is in the chat.',
      ),
    );
    expect(find.byIcon(AppIcons.warning.material), findsOneWidget);
    expect(find.text('Hermes could not speak this reply.'), findsOneWidget);
    expect(find.text('The reply is in the chat.'), findsOneWidget);
  });

  testWidgets('info uses the info icon and needs no detail', (tester) async {
    await pumpVoice(
      tester,
      const VoiceCallNotice(title: 'The microphone is closed.'),
    );
    expect(find.byIcon(AppIcons.info.material), findsOneWidget);
    expect(find.byIcon(AppIcons.warning.material), findsNothing);
  });

  testWidgets('it is announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVoice(
        tester,
        const VoiceCallNotice(title: 'Couldn\'t hear that. Nothing was sent.'),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Nothing was sent')),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('long text at 2x wraps without overflow', (tester) async {
    await pumpVoice(
      tester,
      const VoiceCallNotice(
        tone: VoiceCallNoticeTone.warning,
        title: 'The call was interrupted.',
        detail:
            'Another call or app took the audio. The microphone is closed. '
            'Your earlier turns are in the chat.',
      ),
      scale: 2,
      size: const Size(360, 700),
    );
    expect(tester.takeException(), isNull);
  });
}
