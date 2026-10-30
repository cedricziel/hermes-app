import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart'
    show kAppleMinTapTarget;

import '../../widgetbook/bot_screen_fixture.dart';

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
      await tester.tap(find.bySemanticsLabel(RegExp("^Hermes's screen")));
      expect(taps, 1);
    });
  });

  group('slots', () {
    const marker = Text('preview slot');

    testWidgets('a single call draws it below its card', (tester) async {
      await pump(
        tester,
        const ToolCallGroup(calls: [_running], preview: marker),
      );

      // Below the card, outside it.
      expect(find.byWidget(marker), findsOne);
      expect(
        find.descendant(
          of: find.byType(ToolCallCard),
          matching: find.byWidget(marker),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byWidget(marker)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(ToolCallCard)).dy,
        ),
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

  group('accessibility', () {
    testWidgets('a tappable frame is one button naming the screen and who is '
        'in control', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        BotScreenPreview(model: const BotScreenPreviewFrame(), onTap: () {}),
      );

      expect(
        find.bySemanticsLabel("Hermes's screen, live. Hermes is in control"),
        findsOne,
      );
      expect(find.bySemanticsLabel('Hermes is in control'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a person in control is named on the button too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        BotScreenPreview(
          model: const BotScreenPreviewSuppressed(),
          onTap: () {},
        ),
      );

      expect(
        find.bySemanticsLabel("Hermes's screen. Someone else is in control"),
        findsOne,
      );
      semantics.dispose();
    });

    testWidgets('the pill is at least a tap target tall under Apple chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: BotScreenPreview(
              model: const BotScreenPreviewSuppressed(),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(kAppleMinTapTarget),
      );
    });
  });

  group('the decoded frame', () {
    final one = botScreenFixturePng();

    Future<void> decode(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    testWidgets('is never upscaled, and leaves the image cache when the '
        'picture is dropped or replaced', (tester) async {
      final cache = PaintingBinding.instance.imageCache..clear();
      await pump(
        tester,
        BotScreenPreview(model: BotScreenPreviewFrame(bytes: one)),
      );
      await decode(tester);
      expect(cache.currentSize, 1);
      final provider = tester.widget<Image>(find.byType(Image)).image;
      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).allowUpscaling, isFalse);

      // The next frame replaces it.
      await pump(
        tester,
        BotScreenPreview(
          model: BotScreenPreviewFrame(bytes: Uint8List.fromList(one)),
        ),
      );
      await decode(tester);
      expect(cache.currentSize, 1);

      // App Lock drops the frame.
      await pump(
        tester,
        const BotScreenPreview(model: BotScreenPreviewFrame()),
      );
      await decode(tester);
      expect(cache.currentSize, 0);
    });

    testWidgets('leaves the image cache when the preview goes', (tester) async {
      final cache = PaintingBinding.instance.imageCache..clear();
      await pump(
        tester,
        BotScreenPreview(model: BotScreenPreviewFrame(bytes: one)),
      );
      await decode(tester);
      expect(cache.currentSize, 1);

      await pump(tester, const SizedBox());
      await decode(tester);

      expect(cache.currentSize, 0);
    });
  });
}
