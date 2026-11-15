import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

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

/// A reply of many small or empty fences through the real chat path. Each
/// fence past `kCodeFieldMaxCount` is a plain block; before the cap every one
/// was a code field (chrome, scroll view, copy button): 1 000 empty fences
/// took ~4.5 s to build and lay out here, about 1.3 s with it.
void main() {
  for (final n in [100, 300, 1000]) {
    testWidgets('$n empty fences', (tester) async {
      // The first block ever built pays for the grammar tables.
      await _render(tester, '```js\nconst a = 1;\n```');
      await tester.pumpWidget(const SizedBox());
      final ms = await _render(tester, _empty(n));
      // ignore: avoid_print
      print('FENCE-COST $n fences: ${ms}ms');
      expect(
        tester.widgetList(find.byType(CodeField)),
        hasLength(kCodeFieldMaxCount),
      );
      expect(
        tester.widgetList(find.byType(PlainCodeBlock)),
        hasLength(n - kCodeFieldMaxCount),
      );
      // 100 and 300 fences measure 0.5 to 0.9 s; 1 000 uncapped measure 4.5 s.
      expect(ms, lessThan(n == 1000 ? 2500 : 1500));
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
