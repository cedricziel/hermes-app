import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<int> _render(WidgetTester tester, String text) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = InMemoryChatController(
    messages: [
      Message.text(
        id: 'a-1',
        authorId: kAssistantAuthorId,
        text: text,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  addTearDown(controller.dispose);
  final watch = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: Chat(
          currentUserId: kUserAuthorId,
          resolveUser: (id) async => User(id: id),
          chatController: controller,
          builders: buildChatBuilders(onPickPrompt: (_) {})
              .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return watch.elapsedMilliseconds;
}

String _empty(int n) => List.filled(n, '```\n```').join('\n\n');

/// Baseline of a reply of many small or empty fences through the real chat
/// path: every fence builds one code field (chrome, scroll view, copy button).
/// There is no cap today, so the count equals the number of fences; a change
/// that caps or batches them changes this test on purpose. The time is
/// printed, never asserted (about 0.8, 1.6 and 4.5 s for 100, 300 and 1 000
/// empty fences in the debug harness).
void main() {
  for (final n in [100, 300, 1000]) {
    testWidgets('$n empty fences build $n code fields', (tester) async {
      // The first block ever built pays for the grammar tables.
      await _render(tester, '```js\nconst a = 1;\n```');
      await tester.pumpWidget(const SizedBox());
      final ms = await _render(tester, _empty(n));
      // ignore: avoid_print
      print('FENCE-COST $n fences: ${ms}ms');
      expect(
        tester.widgetList(find.byType(CodeField)),
        hasLength(n),
        reason:
            'baseline without a fence cap; when the chat-speed cap lands, '
            'assert the cap here instead',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
