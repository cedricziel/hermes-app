import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, FileMessage, ImageMessage, Message, TextMessage;

import 'chat_message_kinds.dart';
import 'chat_models.dart';
import 'chat_reply.dart' show kReplyFailedMessage;
import 'markdown_entities.dart';
import 'media/extract_media.dart';

/// Attachments come first, then input requests, text and tool runs
/// interleaved in the order they actually happened — an input request after
/// the call that asked it ([ChatMessage.inputRequestSlots]), a
/// [ChatMessage.sealedProse] entry before the tool run it names, each run
/// after the reasoning that led to its first call — then the reasoning that
/// followed the last call, the text still being written, the files the agent
/// sent (read from `MEDIA:` tags in the text), and the thinking indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-attachment-N`,
/// `id-sealed-N`, `id-tool-N-reasoning`, `id-tool-N`, `id-reasoning`,
/// `id-media-N`, `id-input-N`, `id-thinking`), where `N` is the index in
/// [ChatMessage.sealedProse] or the index in [ChatMessage.toolCalls] of a
/// run's first call, so a streaming reply that mutates content, status or
/// appends another sealed entry or call maps to ids the controller can
/// match with `updateMessage`.
List<Message> chatMessageToFlyer(ChatMessage m) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final thinking = m.status == MessageStatus.thinking;
  final showThinking =
      thinking &&
      !m.awaitingInput &&
      m.sealedProse.isEmpty &&
      m.reasoning.isEmpty &&
      !m.toolCalls.any((call) => call.reasoning.isNotEmpty);
  final media = m.role == ChatRole.assistant
      ? extractMedia(decodeMarkdownEntities(m.content), complete: !m.isPending)
      : ExtractedMedia(m.content, const []);
  InputRequestSlot slotOf(InputRequest request) =>
      m.inputRequestSlots[request.requestId] ??
      (toolCalls: m.toolCalls.length, sealed: m.sealedProse.length);
  final runs = _toolRuns(m.toolCalls, {
    for (final prose in m.sealedProse) prose.beforeToolCall,
    for (final request in m.inputRequests) slotOf(request).toolCalls,
  });

  // The text sealed and the requests that arrived before tool call
  // [toolCallIndex] started, in the order they arrived: a request goes before
  // the first entry sealed after it.
  Iterable<Message> before(int toolCallIndex) {
    final sealed = [
      for (final (i, prose) in m.sealedProse.indexed)
        if (prose.beforeToolCall == toolCallIndex) i,
    ];
    int placeOf(InputRequestSlot slot) =>
        sealed.firstWhere((i) => i >= slot.sealed, orElse: () => -1);
    return [
      for (final place in [...sealed, -1]) ...[
        for (final (i, request) in m.inputRequests.indexed)
          if (slotOf(request) case final slot
              when slot.toolCalls == toolCallIndex && placeOf(slot) == place)
            CustomMessage(
              id: '${m.id}-input-$i',
              authorId: authorId,
              createdAt: createdAt,
              metadata: {
                kMetaKind: kKindInputRequest,
                kMetaInputRequest: request,
              },
            ),
        if (place >= 0)
          TextMessage(
            id: '${m.id}-sealed-$place',
            authorId: authorId,
            createdAt: createdAt,
            text: decodeMarkdownEntities(m.sealedProse[place].text),
          ),
      ],
    ];
  }

  return [
    for (final (i, attachment) in m.attachments.indexed)
      _attachmentMessage(
        '${m.id}-attachment-$i',
        authorId,
        createdAt,
        attachment,
      ),
    for (final run in runs) ...[
      ...before(run.start),
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
    ...before(m.toolCalls.length),
    if (m.reasoning.isNotEmpty)
      _reasoningMessage(
        '${m.id}-reasoning',
        authorId,
        createdAt,
        m.reasoning,
        active: m.isPending,
      ),
    if (!thinking && (media.text.isNotEmpty || m.status == MessageStatus.error))
      TextMessage(
        id: m.id,
        authorId: authorId,
        createdAt: createdAt,
        text: media.text,
        metadata: switch (m.status) {
          MessageStatus.error => {kMetaError: m.error ?? kReplyFailedMessage},
          MessageStatus.streaming => {kMetaStreaming: true},
          _ when m.stopped => {kMetaStopped: true},
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
        metadata: {
          kMetaKind: kKindThinking,
          kMetaThinkingStartedAt: m.createdAt,
          kMetaThinkingActivity: _currentActivity(m.toolCalls),
        },
      ),
  ];
}

/// What the reply is doing right now, for the status line shown while it has
/// nothing else to show yet: the tool still running, or else "Thinking…".
String _currentActivity(List<ToolCall> toolCalls) {
  final running = toolCalls.where((c) => c.status == ToolCallStatus.running);
  return running.isEmpty ? 'Thinking…' : 'Running ${running.last.name}…';
}

List<Message> chatThreadToFlyer(ChatThread t) => [
  for (final m in t.messages) ...chatMessageToFlyer(m),
];

/// Splits [calls] into runs: a new run starts at the first call, wherever a
/// call carries its own reasoning (the model paused to think before it, so
/// it reads as its own turn rather than a continuation of the last run), and
/// wherever [sealedAt] names a call the model wrote text or asked the user
/// something right before, so that has its own gap to sit in.
List<({int start, List<ToolCall> calls})> _toolRuns(
  List<ToolCall> calls,
  Set<int> sealedAt,
) {
  final runs = <({int start, List<ToolCall> calls})>[];
  for (final (i, call) in calls.indexed) {
    if (runs.isEmpty || call.reasoning.isNotEmpty || sealedAt.contains(i)) {
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
