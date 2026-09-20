import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, FileMessage, ImageMessage, Message, TextMessage;

import 'chat_message_kinds.dart';
import 'chat_models.dart';

/// Attachments come first, then tool calls, input requests, the text, and the
/// thinking indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-attachment-N`,
/// `id-tool-N`, `id-input-N`, `id-thinking`), so a streaming reply that
/// mutates content or status maps to ids the controller can match with
/// `updateMessage`.
List<Message> chatMessageToFlyer(ChatMessage m) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final thinking = m.status == MessageStatus.thinking;
  final showThinking = thinking && !m.awaitingInput;

  return [
    for (final (i, attachment) in m.attachments.indexed)
      _attachmentMessage(
        '${m.id}-attachment-$i',
        authorId,
        createdAt,
        attachment,
      ),
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

/// An image the app can draw, from this device or from the history, is an
/// [ImageMessage]; any other file, and an image it cannot draw, is a
/// [FileMessage] shown as a card with its name.
Message _attachmentMessage(
  String id,
  String authorId,
  DateTime createdAt,
  ChatAttachment attachment,
) {
  final metadata = {kMetaAttachment: attachment};
  if (attachment.kind == AttachmentKind.image &&
      (attachment.path != null || attachment.bytes != null)) {
    return ImageMessage(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      source: attachment.path ?? attachment.remotePath ?? attachment.name,
      size: attachment.size,
      metadata: metadata,
    );
  }
  return FileMessage(
    id: id,
    authorId: authorId,
    createdAt: createdAt,
    source: attachment.remotePath ?? attachment.path ?? attachment.name,
    name: attachment.name,
    size: attachment.size,
    metadata: metadata,
  );
}
