import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, Message, TextMessage;

import 'chat_message_kinds.dart';
import 'chat_models.dart';

/// Tool calls come first, then input requests, the text, and the thinking
/// indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-tool-N`, `id-input-N`,
/// `id-thinking`), so a streaming reply that mutates content or status maps
/// to ids the controller can match with `updateMessage`.
List<Message> chatMessageToFlyer(ChatMessage m) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final thinking = m.status == MessageStatus.thinking;
  final showThinking = thinking && !m.awaitingInput;

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
    for (final (i, request) in m.inputRequests.indexed)
      CustomMessage(
        id: '${m.id}-input-$i',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindInputRequest, kMetaInputRequest: request},
      ),
    if (!thinking && m.content.isNotEmpty)
      TextMessage(
        id: m.id,
        authorId: authorId,
        createdAt: createdAt,
        text: m.content,
        metadata: m.status == MessageStatus.error ? {'error': true} : null,
      ),
    if (showThinking)
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
