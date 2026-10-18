import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/widgets/voice_message_view.dart';

void main() {
  testWidgets('playback, seek and save controls are named and usable on iOS', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;
    var saves = 0;
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: VoiceMessageView(
            name: 'A voice message with a long generated filename.ogg',
            position: const Duration(seconds: 12),
            duration: const Duration(seconds: 48),
            onToggle: () => toggles++,
            onSave: () => saves++,
            onSeek: (value) => sought = value,
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Play voice message'));
    await tester.tap(find.bySemanticsLabel('Save voice message'));
    await tester.tap(find.byType(Slider));
    expect(toggles, 1);
    expect(saves, 1);
    expect(sought, isNotNull);
    expect(find.bySemanticsLabel('Voice message position'), findsOneWidget);
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'a transcript is collapsed without adding height to the phone player',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: VoiceMessageView(
              name: 'voice.ogg',
              transcript: 'Here is the spoken briefing.',
              onToggle: () {},
              onSave: () {},
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(VoiceMessageView)).height,
        lessThanOrEqualTo(56),
      );
      expect(find.text('Here is the spoken briefing.'), findsNothing);
      await tester.tap(find.byTooltip('Show transcript'));
      await tester.pumpAndSettle();
      expect(find.text('Here is the spoken briefing.'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide transcript'));
      await tester.pumpAndSettle();
      expect(find.text('Here is the spoken briefing.'), findsNothing);
    },
  );
}
