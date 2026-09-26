import 'dart:typed_data';

import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, FileMessage, ImageMessage, TextMessage;
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
    List<ChatAttachment> attachments = const [],
    String reasoning = '',
    List<SealedProse> sealedProse = const [],
  }) => ChatMessage(
    id: 'm1',
    role: role,
    content: content,
    createdAt: createdAt,
    status: status,
    toolCalls: toolCalls,
    inputRequests: inputRequests,
    attachments: attachments,
    reasoning: reasoning,
    sealedProse: sealedProse,
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

    test('decodes HTML entities in a reply, but not inside code', () {
      final out = chatMessageToFlyer(
        message(
          content:
              'Subject "Briefing &lt;date&gt;" &amp; more\n'
              'Use `&lt;br&gt;` here\n'
              '```html\n&lt;p&gt;\n```',
          sealedProse: const [
            SealedProse('A &quot;b&quot;', beforeToolCall: 0),
          ],
        ),
      );

      expect(out.whereType<TextMessage>().map((m) => m.text), [
        'A "b"',
        'Subject "Briefing <date>" & more\n'
            'Use `&lt;br&gt;` here\n'
            '```html\n&lt;p&gt;\n```',
      ]);
    });

    test('leaves entities the user typed as they are', () {
      final out = chatMessageToFlyer(
        message(role: ChatRole.user, content: 'What is &lt;?'),
      );

      expect((out.single as TextMessage).text, 'What is &lt;?');
    });

    test('puts the reasoning that led to a call before it', () {
      final out = chatMessageToFlyer(
        message(
          toolCalls: const [
            ToolCall(name: 'shell', summary: 'ls', reasoning: 'Because.'),
          ],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0-reasoning', 'm1-tool-0', 'm1']);
      expect((out.first as CustomMessage).metadata, {
        kMetaKind: kKindReasoning,
        kMetaReasoningText: 'Because.',
        kMetaReasoningActive: false,
      });
    });

    test('marks reasoning active while the reply is pending', () {
      final out = chatMessageToFlyer(
        message(content: '', reasoning: 'Hmm', status: MessageStatus.thinking),
      );

      expect(
        (out.single as CustomMessage).metadata![kMetaReasoningActive],
        isTrue,
      );
    });

    test('shows no thinking dots once reasoning is showing', () {
      final out = chatMessageToFlyer(
        message(content: '', reasoning: 'Hmm', status: MessageStatus.thinking),
      );

      expect(out.map((m) => m.id), ['m1-reasoning']);
    });

    test('uses the user author id for user messages', () {
      final out = chatMessageToFlyer(message(role: ChatRole.user));

      expect(out.single.authorId, kUserAuthorId);
    });

    test('groups consecutive calls with no reasoning between them', () {
      const shell = ToolCall(name: 'shell', summary: 'ls -la');
      const search = ToolCall(
        name: 'web_search',
        summary: 'flutter',
        status: ToolCallStatus.running,
      );
      final out = chatMessageToFlyer(message(toolCalls: const [shell, search]));

      expect(out.map((m) => m.id), ['m1-tool-0', 'm1']);
      expect(out[1], isA<TextMessage>());
      final group = out[0] as CustomMessage;
      expect(group.authorId, kAssistantAuthorId);
      expect(group.createdAt, createdAt.toUtc());
      expect(group.metadata, {
        kMetaKind: kKindToolGroup,
        kMetaToolCalls: [shell, search],
      });
    });

    test('shows no thinking dots once a call has reasoning to show', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          toolCalls: const [
            ToolCall(
              name: 'shell',
              summary: 'ls',
              status: ToolCallStatus.running,
              reasoning: 'Look first.',
            ),
          ],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0-reasoning', 'm1-tool-0']);
    });

    test('keeps reasoning, calls and text in the order they happened', () {
      final out = chatMessageToFlyer(
        message(
          reasoning: 'Now I can answer.',
          toolCalls: const [
            ToolCall(name: 'shell', summary: 'ls', reasoning: 'Look first.'),
            ToolCall(name: 'read', summary: 'a', reasoning: 'Then read.'),
          ],
        ),
      );

      expect(out.map((m) => m.id), [
        'm1-tool-0-reasoning',
        'm1-tool-0',
        'm1-tool-1-reasoning',
        'm1-tool-1',
        'm1-reasoning',
        'm1',
      ]);
    });

    test('a call with no reasoning joins the run that started before it', () {
      const first = ToolCall(name: 'shell', summary: 'ls', reasoning: 'Look.');
      const second = ToolCall(name: 'read', summary: 'a');
      const third = ToolCall(
        name: 'write',
        summary: 'b',
        reasoning: 'Now change it.',
      );
      final out = chatMessageToFlyer(
        message(toolCalls: const [first, second, third]),
      );

      expect(out.map((m) => m.id), [
        'm1-tool-0-reasoning',
        'm1-tool-0',
        'm1-tool-2-reasoning',
        'm1-tool-2',
        'm1',
      ]);
      final firstGroup = out[1] as CustomMessage;
      expect(firstGroup.metadata![kMetaToolCalls], [first, second]);
      final secondGroup = out[3] as CustomMessage;
      expect(secondGroup.metadata![kMetaToolCalls], [third]);
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
      expect(thinking.metadata, {
        kMetaKind: kKindThinking,
        kMetaThinkingStartedAt: createdAt,
        kMetaThinkingActivity: 'Thinking…',
      });
    });

    test('names the running tool as the current activity', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          toolCalls: const [
            ToolCall(
              name: 'git_show',
              summary: '',
              status: ToolCallStatus.running,
            ),
          ],
        ),
      );

      final thinking = out.last as CustomMessage;
      expect(thinking.metadata![kMetaThinkingActivity], 'Running git_show…');
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
      expect(out.single.metadata, {kMetaStreaming: true});
    });

    test('flags error messages via metadata and keeps the text', () {
      final out = chatMessageToFlyer(
        message(content: 'boom', status: MessageStatus.error),
      );

      final text = out.single as TextMessage;
      expect(text.text, 'boom');
      expect(text.metadata, {'error': true});
    });

    test('shows a picked image as an image message before the text', () {
      const photo = ChatAttachment(
        name: 'photo.png',
        kind: AttachmentKind.image,
        path: '/tmp/photo.png',
        size: 2048,
      );

      final out = chatMessageToFlyer(
        message(
          role: ChatRole.user,
          content: 'what is this?',
          attachments: const [photo],
        ),
      );

      expect(out.map((m) => m.id), ['m1-attachment-0', 'm1']);
      final image = out.first as ImageMessage;
      expect(image.authorId, kUserAuthorId);
      expect(image.createdAt, createdAt.toUtc());
      expect(image.source, '/tmp/photo.png');
      expect(image.size, 2048);
      expect(image.metadata, {kMetaAttachment: photo});
    });

    test('shows a file as a file message with its name and size', () {
      const report = ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        path: '/tmp/report.pdf',
        size: 122880,
      );

      final out = chatMessageToFlyer(
        message(role: ChatRole.user, content: '', attachments: const [report]),
      );

      final file = out.single as FileMessage;
      expect(file.id, 'm1-attachment-0');
      expect(file.name, 'report.pdf');
      expect(file.size, 122880);
      expect(file.metadata, {kMetaAttachment: report});
    });

    test('shows an image the history embedded as an image message', () {
      final out = chatMessageToFlyer(
        message(
          role: ChatRole.user,
          content: '',
          attachments: [
            ChatAttachment(
              name: 'a.png',
              kind: AttachmentKind.image,
              remotePath: '/srv/a.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      );

      expect(out.single, isA<ImageMessage>());
    });

    test('shows an image on the server as an image message', () {
      const remote = ChatAttachment(
        name: 'a.png',
        kind: AttachmentKind.image,
        remotePath: '/srv/a.png',
      );
      final out = chatMessageToFlyer(
        message(role: ChatRole.user, content: '', attachments: const [remote]),
      );

      final image = out.single as ImageMessage;
      expect(image.source, '/srv/a.png');
      expect(image.metadata, {kMetaAttachment: remote});
    });

    test('shows an image with only a relative server path as a named card', () {
      final out = chatMessageToFlyer(
        message(
          role: ChatRole.user,
          content: '',
          attachments: const [
            ChatAttachment(
              name: 'a.png',
              kind: AttachmentKind.image,
              remotePath: 'attachments/a.png',
            ),
          ],
        ),
      );

      final card = out.single as FileMessage;
      expect(card.name, 'a.png');
      expect(card.source, 'attachments/a.png');
    });

    test('numbers several attachments in order', () {
      final out = chatMessageToFlyer(
        message(
          role: ChatRole.user,
          attachments: const [
            ChatAttachment(name: 'a.txt', kind: AttachmentKind.file),
            ChatAttachment(name: 'b.txt', kind: AttachmentKind.file),
          ],
        ),
      );

      expect(out.map((m) => m.id), [
        'm1-attachment-0',
        'm1-attachment-1',
        'm1',
      ]);
    });

    group('files the agent sends', () {
      test('follow the text, hide the tag and are numbered media', () {
        final out = chatMessageToFlyer(
          message(content: 'Here you go\nMEDIA:/srv/a.png\nMEDIA:/srv/r.pdf'),
        );

        expect(out.map((m) => m.id), ['m1', 'm1-media-0', 'm1-media-1']);
        expect((out[0] as TextMessage).text, 'Here you go');
        final image = out[1] as ImageMessage;
        expect(image.authorId, kAssistantAuthorId);
        expect(image.source, '/srv/a.png');
        final file = out[2] as FileMessage;
        expect(file.name, 'r.pdf');
        expect(file.source, '/srv/r.pdf');
        expect(
          (file.metadata![kMetaAttachment] as ChatAttachment).remotePath,
          '/srv/r.pdf',
        );
      });

      test('leave only the attachments for a message of tags', () {
        final out = chatMessageToFlyer(message(content: 'MEDIA:/srv/a.png'));

        expect(out.map((m) => m.id), ['m1-media-0']);
      });

      test('are held back while the tag is still arriving', () {
        final out = chatMessageToFlyer(
          message(content: 'see MEDIA:/sr', status: MessageStatus.streaming),
        );

        expect(out.map((m) => m.id), ['m1']);
        expect((out.single as TextMessage).text, 'see');
      });

      test('keep the ids of the text and earlier files as the reply grows', () {
        final m = message(
          content: 'see MEDIA:/srv/a.png and',
          status: MessageStatus.streaming,
        );
        final before = chatMessageToFlyer(m).map((f) => f.id).toList();
        m
          ..content = 'see MEDIA:/srv/a.png and MEDIA:/srv/b.png'
          ..status = MessageStatus.sent;
        final after = chatMessageToFlyer(m).map((f) => f.id).toList();

        expect(before, ['m1', 'm1-media-0']);
        expect(after, ['m1', 'm1-media-0', 'm1-media-1']);
      });

      test('are not read from what the user typed', () {
        final out = chatMessageToFlyer(
          message(role: ChatRole.user, content: 'MEDIA:/srv/a.png'),
        );

        expect(out.map((m) => m.id), ['m1']);
        expect((out.single as TextMessage).text, 'MEDIA:/srv/a.png');
      });
    });

    test('emits nothing for an empty sent message without tool calls', () {
      expect(chatMessageToFlyer(message(content: '')), isEmpty);
    });

    group('text sealed ahead of a tool call', () {
      test('renders before the tool call it preceded, not after it', () {
        final out = chatMessageToFlyer(
          message(
            content: '',
            sealedProse: const [SealedProse('Hey!', beforeToolCall: 0)],
            toolCalls: const [ToolCall(name: 'terminal', summary: 'ls')],
          ),
        );

        expect(out.map((m) => m.id), ['m1-sealed-0', 'm1-tool-0']);
        expect((out.first as TextMessage).text, 'Hey!');
      });

      test('a segment sealed after every tool call still comes before the '
          'text still being written', () {
        final out = chatMessageToFlyer(
          message(
            content: 'Still going',
            sealedProse: const [SealedProse('Checked.', beforeToolCall: 1)],
            toolCalls: const [ToolCall(name: 'terminal', summary: 'ls')],
          ),
        );

        expect(out.map((m) => m.id), ['m1-tool-0', 'm1-sealed-0', 'm1']);
      });

      test('several segments interleave with several tool runs in order', () {
        final out = chatMessageToFlyer(
          message(
            content: 'and done.',
            sealedProse: const [
              SealedProse('First,', beforeToolCall: 0),
              SealedProse('then,', beforeToolCall: 1),
            ],
            toolCalls: const [
              ToolCall(name: 'a', summary: 'x'),
              ToolCall(name: 'b', summary: 'y'),
            ],
          ),
        );

        expect(out.map((m) => m.id), [
          'm1-sealed-0',
          'm1-tool-0',
          'm1-sealed-1',
          'm1-tool-1',
          'm1',
        ]);
      });

      test('suppresses the thinking indicator once something is sealed', () {
        final out = chatMessageToFlyer(
          message(
            content: '',
            status: MessageStatus.thinking,
            sealedProse: const [SealedProse('Hey!', beforeToolCall: 0)],
          ),
        );

        expect(out.map((m) => m.id), ['m1-sealed-0']);
      });
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
