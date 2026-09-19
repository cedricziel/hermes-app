import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';

void main() {
  final createdAt = DateTime(2026, 1, 2, 3, 4, 5);

  ChatMessage message({
    ChatRole role = ChatRole.assistant,
    String content = 'hello',
    MessageStatus status = MessageStatus.sent,
    List<ToolCall> toolCalls = const [],
    List<InputRequest> inputRequests = const [],
  }) => ChatMessage(
    id: 'm1',
    role: role,
    content: content,
    createdAt: createdAt,
    status: status,
    toolCalls: toolCalls,
    inputRequests: inputRequests,
  );

  group('chatMessageToFlyer', () {
    test('maps a plain message to a single TextMessage', () {
      final out = chatMessageToFlyer(message());

      expect(out, hasLength(1));
      final text = out.single as TextMessage;
      expect(text.id, 'm1');
      expect(text.text, 'hello');
      expect(text.authorId, kAssistantAuthorId);
      expect(text.createdAt, createdAt.toUtc());
      expect(text.createdAt!.isUtc, isTrue);
      expect(text.metadata, isNull);
    });

    test('uses the user author id for user messages', () {
      final out = chatMessageToFlyer(message(role: ChatRole.user));

      expect(out.single.authorId, kUserAuthorId);
    });

    test('emits one CustomMessage per tool call before the text', () {
      final out = chatMessageToFlyer(
        message(
          toolCalls: const [
            ToolCall(name: 'shell', summary: 'ls -la'),
            ToolCall(
              name: 'web_search',
              summary: 'flutter',
              status: ToolCallStatus.running,
            ),
          ],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0', 'm1-tool-1', 'm1']);
      expect(out[2], isA<TextMessage>());
      final first = out[0] as CustomMessage;
      final second = out[1] as CustomMessage;
      expect(first.authorId, kAssistantAuthorId);
      expect(first.createdAt, createdAt.toUtc());
      expect(first.metadata, {
        kMetaKind: kKindToolCall,
        kMetaToolName: 'shell',
        kMetaToolSummary: 'ls -la',
        kMetaToolStatus: 'completed',
      });
      expect(second.metadata![kMetaToolStatus], 'running');
    });

    test('emits tool calls without text when content is empty', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          toolCalls: const [ToolCall(name: 'shell', summary: 'ls')],
        ),
      );

      expect(out.single, isA<CustomMessage>());
      expect(out.single.id, 'm1-tool-0');
    });

    test('maps a thinking message to a thinking CustomMessage only', () {
      final out = chatMessageToFlyer(
        message(content: '', status: MessageStatus.thinking),
      );

      final thinking = out.single as CustomMessage;
      expect(thinking.id, 'm1-thinking');
      expect(thinking.authorId, kAssistantAuthorId);
      expect(thinking.metadata, {kMetaKind: kKindThinking});
    });

    test('thinking replaces any text content', () {
      final out = chatMessageToFlyer(
        message(content: 'partial', status: MessageStatus.thinking),
      );

      expect(out.single.id, 'm1-thinking');
    });

    test('places the thinking indicator after tool calls', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          toolCalls: const [ToolCall(name: 'shell', summary: 'ls')],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0', 'm1-thinking']);
    });

    test('emits a custom message per input request, after tool calls', () {
      const approval = ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: 'delete files',
        choices: ['once', 'deny'],
      );

      final out = chatMessageToFlyer(
        message(
          content: '',
          toolCalls: const [ToolCall(name: 'shell', summary: 'ls')],
          inputRequests: const [approval],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0', 'm1-input-0']);
      final card = out.last as CustomMessage;
      expect(card.metadata, {
        kMetaKind: kKindInputRequest,
        kMetaInputRequest: approval,
      });
    });

    test('hides the thinking indicator while a request is pending', () {
      const approval = ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: 'delete files',
        choices: ['once', 'deny'],
      );

      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          inputRequests: const [approval],
        ),
      );

      expect(out.map((m) => m.id), ['m1-input-0']);
    });

    test('shows the thinking indicator again once the request is answered', () {
      const approval = ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: 'delete files',
        choices: ['once', 'deny'],
      );

      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          inputRequests: [approval.answered('once')],
        ),
      );

      expect(out.map((m) => m.id), ['m1-input-0', 'm1-thinking']);
    });

    test('keeps streaming content as text', () {
      final out = chatMessageToFlyer(
        message(content: 'par', status: MessageStatus.streaming),
      );

      expect((out.single as TextMessage).text, 'par');
      expect(out.single.metadata, isNull);
    });

    test('flags error messages via metadata and keeps the text', () {
      final out = chatMessageToFlyer(
        message(content: 'boom', status: MessageStatus.error),
      );

      final text = out.single as TextMessage;
      expect(text.text, 'boom');
      expect(text.metadata, {'error': true});
    });

    test('emits nothing for an empty sent message without tool calls', () {
      expect(chatMessageToFlyer(message(content: '')), isEmpty);
    });

    test('ids are stable across mutation of the same message', () {
      final m = message(content: '', status: MessageStatus.thinking);
      final before = chatMessageToFlyer(m).map((f) => f.id).toList();

      m
        ..content = 'done'
        ..status = MessageStatus.sent;
      final after = chatMessageToFlyer(m).map((f) => f.id).toList();

      expect(before, ['m1-thinking']);
      expect(after, ['m1']);
    });
  });

  group('chatThreadToFlyer', () {
    test('flat-maps messages in order', () {
      final thread = ChatThread(
        id: 't1',
        title: 'Thread',
        updatedAt: createdAt,
        messages: [
          ChatMessage(
            id: 'a',
            role: ChatRole.user,
            content: 'hi',
            createdAt: createdAt,
          ),
          ChatMessage(
            id: 'b',
            role: ChatRole.assistant,
            content: 'yo',
            createdAt: createdAt,
            toolCalls: const [ToolCall(name: 'shell', summary: 'ls')],
          ),
        ],
      );

      expect(chatThreadToFlyer(thread).map((m) => m.id), [
        'a',
        'b-tool-0',
        'b',
      ]);
    });

    test('is empty for an empty thread', () {
      final thread = ChatThread(id: 't', title: 'T', updatedAt: createdAt);

      expect(chatThreadToFlyer(thread), isEmpty);
    });
  });
}
