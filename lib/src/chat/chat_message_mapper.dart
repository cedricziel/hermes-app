import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, Message, TextMessage;

import 'chat_message_kinds.dart';
import 'chat_models.dart';

/// Tool calls come first, then the text, then the thinking indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-tool-N`, `id-thinking`),
/// so a streaming reply that mutates content or status maps to ids the
/// controller can match with `updateMessage`.
List<Message> chatMessageToFlyer(ChatMessage m) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final thinking = m.status == MessageStatus.thinking;

  return [
    for (final (i, call) in m.toolCalls.indexed)
      CustomMessage(
        id: '${m.id}-tool-$i',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {
          kMetaKind: kKindToolCall,
          kMetaToolName: call.name,
          kMetaToolSummary: call.summary,
          kMetaToolStatus: call.status.name,
        },
      ),
    if (!thinking && m.content.isNotEmpty)
      TextMessage(
        id: m.id,
        authorId: authorId,
        createdAt: createdAt,
        text: m.content,
        metadata: m.status == MessageStatus.error ? {'error': true} : null,
      ),
    if (thinking)
      CustomMessage(
        id: '${m.id}-thinking',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindThinking},
      ),
  ];
}

List<Message> chatThreadToFlyer(ChatThread t) => [
  for (final m in t.messages) ...chatMessageToFlyer(m),
];
