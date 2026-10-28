import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _running = ToolCall(
  id: 'c2',
  name: 'computer_use',
  summary: 'click',
  status: ToolCallStatus.running,
);

void main() {
  group('model', () {
    test('only a running screen has something to show', () {
      expect(
        BotScreenPreviewModel.from(const BotScreenShowing()),
        isA<BotScreenPreviewFrame>(),
      );
      expect(
        BotScreenPreviewModel.from(const BotScreenControlled(byYou: true)),
        isA<BotScreenPreviewSuppressed>().having((m) => m.byYou, 'byYou', true),
      );
      for (final card in <BotScreenCardModel?>[
        null,
        const BotScreenNotOffered(),
        const BotScreenNotInstalled(),
        const BotScreenBlocked(text: 'no memory'),
        const BotScreenStarting(),
        const BotScreenOff(),
        const BotScreenReadFailed(),
      ]) {
        expect(
          BotScreenPreviewModel.from(card).visible,
          isFalse,
          reason: '$card',
        );
      }
    });
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('widget', () {
    testWidgets('a frame has the Live badge and says who is in control', (
      tester,
    ) async {
      await pump(
        tester,
        const BotScreenPreview(model: BotScreenPreviewFrame()),
      );

      expect(find.text('Live'), findsOne);
      expect(find.text('Hermes is in control'), findsOne);
      expect(find.text('Waiting for the first picture…'), findsOne);
    });

    testWidgets('a person in control leaves no Live badge', (tester) async {
      await pump(
        tester,
        const BotScreenPreview(model: BotScreenPreviewSuppressed(byYou: true)),
      );

      expect(find.text("You're in control"), findsOne);
      expect(find.text('Live'), findsNothing);
    });

    testWidgets('a hidden model draws nothing and a tap calls onTap', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        const BotScreenPreview(model: BotScreenPreviewHidden()),
      );
      expect(find.byType(Text), findsNothing);

      await pump(
        tester,
        BotScreenPreview(
          model: const BotScreenPreviewFrame(),
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.bySemanticsLabel("Open Hermes's screen"));
      expect(taps, 1);
    });
  });

  group('slots', () {
    const marker = Text('preview slot');

    testWidgets('a single call hands the slot to its card', (tester) async {
      await pump(
        tester,
        const ToolCallGroup(calls: [_running], preview: marker),
      );

      expect(
        find.descendant(
          of: find.byType(ToolCallCard),
          matching: find.byWidget(marker),
        ),
        findsOne,
      );
    });

    testWidgets('a folded group draws it under its header, not on a card', (
      tester,
    ) async {
      await pump(
        tester,
        const ToolCallGroup(
          calls: [
            ToolCall(name: 'computer_use', summary: 'shot'),
            _running,
          ],
          preview: marker,
        ),
      );

      expect(find.byWidget(marker), findsOne);
      expect(find.byType(ToolCallCard), findsNothing);
    });

    testWidgets('no slot, nothing extra', (tester) async {
      await pump(tester, const ToolCallGroup(calls: [_running]));

      expect(find.byType(ToolCallCard), findsOne);
      expect(find.byWidget(marker), findsNothing);
    });
  });
}
