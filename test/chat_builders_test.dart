import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_models.dart' show ToolCallStatus;
import 'package:hermes_app/src/chat/mock_chat_data.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Message _custom(Map<String, dynamic> metadata) => Message.custom(
  id: 'm-${metadata.hashCode}',
  authorId: kAssistantAuthorId,
  metadata: metadata,
);

Message _text(String authorId, String text) => Message.text(
  id: '$authorId-text',
  authorId: authorId,
  text: text,
  createdAt: DateTime.utc(2026, 1, 1, 14, 30),
);

Future<void> _pumpChat(
  WidgetTester tester, {
  List<Message> messages = const [],
  void Function(String prompt)? onPickPrompt,
  String? greetingName,
}) async {
  final controller = InMemoryChatController(messages: messages);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: Chat(
          currentUserId: kUserAuthorId,
          resolveUser: (id) async => User(id: id),
          chatController: controller,
          // The default composer needs a material_ui Material ancestor; the
          // real screen supplies its own composer.
          builders: buildChatBuilders(
            onPickPrompt: onPickPrompt ?? (_) {},
            greetingName: greetingName,
          ).copyWith(composerBuilder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  // The thinking indicator animates forever, so settle by pumping a bounded
  // amount of time instead of pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('customMessageBuilder', () {
    testWidgets('tool_call renders a ToolCallCard from metadata', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        messages: [
          _custom({
            kMetaKind: kKindToolCall,
            kMetaToolName: 'shell.exec',
            kMetaToolSummary: 'ls -la /var/log',
            kMetaToolStatus: ToolCallStatus.completed.name,
          }),
        ],
      );

      final card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
      expect(card.call.name, 'shell.exec');
      expect(card.call.summary, 'ls -la /var/log');
      expect(card.call.status, ToolCallStatus.completed);
      expect(find.text('shell.exec'), findsOneWidget);
      expect(find.byType(ThinkingIndicator), findsNothing);
    });

    testWidgets('tool_call status is decoded from its enum name', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        messages: [
          _custom({
            kMetaKind: kKindToolCall,
            kMetaToolName: 'web.search',
            kMetaToolSummary: 'flutter chat ui',
            kMetaToolStatus: ToolCallStatus.error.name,
          }),
        ],
      );

      final card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
      expect(card.call.status, ToolCallStatus.error);
    });

    testWidgets('thinking renders the ThinkingIndicator', (tester) async {
      await _pumpChat(
        tester,
        messages: [
          _custom({kMetaKind: kKindThinking}),
        ],
      );

      expect(find.byType(ThinkingIndicator), findsOneWidget);
      expect(find.byType(ToolCallCard), findsNothing);
    });

    testWidgets('unknown kind renders nothing and does not throw', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        messages: [
          _custom({kMetaKind: 'mystery'}),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ToolCallCard), findsNothing);
      expect(find.byType(ThinkingIndicator), findsNothing);
    });

    testWidgets('missing metadata renders nothing and does not throw', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        messages: [
          const Message.custom(id: 'bare', authorId: kAssistantAuthorId),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ToolCallCard), findsNothing);
    });
  });

  group('textMessageBuilder', () {
    testWidgets('assistant markdown is rendered, not shown raw', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        messages: [
          _text(
            kAssistantAuthorId,
            'Here is **bold** and `inline`\n\n```sh\necho hello\n```',
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('```', findRichText: true), findsNothing);
      expect(find.textContaining('bold', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('echo hello', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('user text is shown without a timestamp', (tester) async {
      await _pumpChat(tester, messages: [_text(kUserAuthorId, 'hi hermes')]);

      expect(find.textContaining('hi hermes', findRichText: true), findsOne);
      // Default FlyerChatTextMessage would render "HH:mm" next to the text.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
    });
  });

  group('emptyChatListBuilder', () {
    testWidgets('shows the welcome view with the greeting name', (
      tester,
    ) async {
      await _pumpChat(tester, greetingName: 'Ada');

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.text('Where should we begin, Ada?'), findsOneWidget);
    });

    testWidgets('picking a starter prompt calls onPickPrompt', (tester) async {
      final picked = <String>[];
      await _pumpChat(tester, onPickPrompt: picked.add);

      await tester.tap(find.text(kStarterPrompts.first));
      expect(picked, [kStarterPrompts.first]);
    });

    testWidgets('is not shown once there are messages', (tester) async {
      await _pumpChat(tester, messages: [_text(kUserAuthorId, 'hello')]);

      expect(find.byType(WelcomeView), findsNothing);
    });
  });
}
