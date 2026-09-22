import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, FileMessage, ImageMessage, Message, TextMessage;

import 'chat_message_kinds.dart';
import 'chat_models.dart';
import 'media/extract_media.dart';

/// Attachments come first, then the tool calls grouped into runs, each after
/// the reasoning that led to the run's first call, the reasoning that
/// followed the last call, input requests, the text, the files the agent
/// sent (read from `MEDIA:` tags in the text), and the thinking indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-attachment-N`,
/// `id-tool-N-reasoning`, `id-tool-N`, `id-reasoning`, `id-media-N`,
/// `id-input-N`, `id-thinking`), where `N` is the index in
/// [ChatMessage.toolCalls] of a run's first call, so a streaming reply that
/// mutates content, status or appends another call to a run maps to ids the
/// controller can match with `updateMessage`.
List<Message> chatMessageToFlyer(ChatMessage m) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final thinking = m.status == MessageStatus.thinking;
  final showThinking =
      thinking &&
      !m.awaitingInput &&
      m.reasoning.isEmpty &&
      !m.toolCalls.any((call) => call.reasoning.isNotEmpty);
  final media = m.role == ChatRole.assistant
      ? extractMedia(m.content, complete: !m.isPending)
      : ExtractedMedia(m.content, const []);

  return [
    for (final (i, attachment) in m.attachments.indexed)
      _attachmentMessage(
        '${m.id}-attachment-$i',
        authorId,
        createdAt,
        attachment,
      ),
    for (final run in _toolRuns(m.toolCalls)) ...[
      if (run.calls.first.reasoning.isNotEmpty)
        _reasoningMessage(
          '${m.id}-tool-${run.start}-reasoning',
          authorId,
          createdAt,
          run.calls.first.reasoning,
          active: false,
        ),
      CustomMessage(
        id: '${m.id}-tool-${run.start}',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindToolGroup, kMetaToolCalls: run.calls},
      ),
    ],
    if (m.reasoning.isNotEmpty)
      _reasoningMessage(
        '${m.id}-reasoning',
        authorId,
        createdAt,
        m.reasoning,
        active: m.isPending,
      ),
    for (final (i, request) in m.inputRequests.indexed)
      CustomMessage(
        id: '${m.id}-input-$i',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindInputRequest, kMetaInputRequest: request},
      ),
    if (!thinking && media.text.isNotEmpty)
      TextMessage(
        id: m.id,
        authorId: authorId,
        createdAt: createdAt,
        text: media.text,
        metadata: switch (m.status) {
          MessageStatus.error => {kMetaError: true},
          MessageStatus.streaming => {kMetaStreaming: true},
          _ => null,
        },
      ),
    for (final (i, attachment) in media.attachments.indexed)
      _attachmentMessage('${m.id}-media-$i', authorId, createdAt, attachment),
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

/// Splits [calls] into runs: a new run starts at the first call and wherever
/// a call carries its own reasoning (the model paused to think before it, so
/// it reads as its own turn rather than a continuation of the last run).
List<({int start, List<ToolCall> calls})> _toolRuns(List<ToolCall> calls) {
  final runs = <({int start, List<ToolCall> calls})>[];
  for (final (i, call) in calls.indexed) {
    if (runs.isEmpty || call.reasoning.isNotEmpty) {
      runs.add((start: i, calls: [call]));
    } else {
      runs.last.calls.add(call);
    }
  }
  return runs;
}

Message _reasoningMessage(
  String id,
  String authorId,
  DateTime createdAt,
  String text, {
  required bool active,
}) => CustomMessage(
  id: id,
  authorId: authorId,
  createdAt: createdAt,
  metadata: {
    kMetaKind: kKindReasoning,
    kMetaReasoningText: text,
    kMetaReasoningActive: active,
  },
);

/// An image the app can draw, from this device, the history or the server, is
/// an [ImageMessage]; any other file, and an image it cannot draw, is a
/// [FileMessage] shown as a card with its name.
Message _attachmentMessage(
  String id,
  String authorId,
  DateTime createdAt,
  ChatAttachment attachment,
) {
  final metadata = {kMetaAttachment: attachment};
  if (attachment.kind == AttachmentKind.image &&
      (attachment.path != null ||
          attachment.bytes != null ||
          attachment.fetchPath != null)) {
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
