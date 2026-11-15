import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/chat_text_message.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/type_scale.dart';

/// The look of a text message through the real chat path. Distinct colours for
/// the chat theme's `onPrimary` (text on the user's bubble) and `onSurface`
/// (text on the reply), so a link takes the right one.
const _onPrimary = Color(0xFFD50000);
const _onSurface = Color(0xFF0000D5);

ChatTheme _chatTheme() {
  final base = buildChatTheme(buildHermesLightTheme());
  return base.copyWith(
    colors: base.colors.copyWith(onPrimary: _onPrimary, onSurface: _onSurface),
  );
}

Future<void> _pump(
  WidgetTester tester,
  String authorId,
  String text, {
  double textScale = 1,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = InMemoryChatController(
    messages: [
      Message.text(
        id: 'm-1',
        authorId: authorId,
        text: text,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Chat(
          currentUserId: kUserAuthorId,
          resolveUser: (id) async => User(id: id),
          chatController: controller,
          theme: _chatTheme(),
          builders: buildChatBuilders(onPickPrompt: (_) {})
              .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// The style a run of [text] is drawn in, with every ancestor span merged in,
/// and the scaler of the paragraph that holds it.
({TextStyle style, TextScaler scaler}) _run(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(
    find.descendant(
      of: find.byType(ChatTextMessage),
      matching: find.byType(RichText),
    ),
  )) {
    TextStyle? found;
    void visit(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = span.style == null
          ? inherited
          : inherited.merge(span.style);
      if (span.text == text) found = style;
      span.children?.forEach((c) => visit(c, style));
    }

    visit(rich.text, const TextStyle());
    if (found != null) return (style: found!, scaler: rich.textScaler);
  }
  throw TestFailure('no run "$text" in a ChatTextMessage');
}

void main() {
  final scheme = buildHermesLightTheme().colorScheme;

  group('a text message in the chat', () {
    testWidgets('the user bubble draws its text in the surface text colour', (
      tester,
    ) async {
      await _pump(tester, kUserAuthorId, 'hello there');
      expect(_run(tester, 'hello there').style.color, scheme.onSurface);
    });

    testWidgets('a reply draws its text in the surface text colour', (
      tester,
    ) async {
      await _pump(tester, kAssistantAuthorId, 'general answer');
      expect(_run(tester, 'general answer').style.color, scheme.onSurface);
    });

    testWidgets(
      'a link in a reply is underlined, in the chat colour of its surface',
      (tester) async {
        await _pump(
          tester,
          kAssistantAuthorId,
          'see [the site](https://a.b/c)',
        );
        final reply = _run(tester, 'the site').style;
        expect(reply.decoration, TextDecoration.underline);
        expect(reply.decorationColor, _onSurface);
      },
    );

    testWidgets('a link in the user bubble takes the colour of its text', (
      tester,
    ) async {
      await _pump(tester, kUserAuthorId, 'see [the site](https://a.b/c)');
      final mine = _run(tester, 'the site').style;
      expect(mine.decoration, TextDecoration.underline);
      expect(mine.decorationColor, _onPrimary);
    });

    testWidgets('the text follows the largest text scale', (tester) async {
      await _pump(tester, kAssistantAuthorId, 'scaled words', textScale: 3.1);
      expect(_run(tester, 'scaled words').scaler.scale(10), closeTo(31, 0.01));
      await _pump(tester, kAssistantAuthorId, 'scaled words');
      expect(_run(tester, 'scaled words').scaler.scale(10), closeTo(10, 0.01));
    });

    testWidgets('the text size is the message size of the platform', (
      tester,
    ) async {
      await _pump(
        tester,
        kAssistantAuthorId,
        'sized words',
        platform: TargetPlatform.android,
      );
      expect(
        _run(tester, 'sized words').style.fontSize,
        kDefaultMessageFontSize,
      );
      await _pump(
        tester,
        kUserAuthorId,
        'sized words',
        platform: TargetPlatform.iOS,
      );
      expect(_run(tester, 'sized words').style.fontSize, kIosMessageFontSize);
      expect(kIosMessageFontSize, isNot(kDefaultMessageFontSize));
    });
  });
}
