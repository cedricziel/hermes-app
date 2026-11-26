import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, FileMessage, ImageMessage, Message, TextMessage;

import 'checkpoints/transcript_outcome.dart';
import 'chat_message_kinds.dart';
import 'chat_models.dart';
import 'markdown_entities.dart';
import 'media/extract_media.dart';
import 'sources/turn_sources.dart';
import '../voice/voice_transcript.dart';

/// Attachments come first, then input requests, text and tool runs
/// interleaved in the order they actually happened — an input request after
/// the call that asked it ([ChatMessage.inputRequestSlots]), a
/// [ChatMessage.sealedProse] entry before the tool run it names, each run
/// after the reasoning that led to its first call — then the reasoning that
/// followed the last call, the text still being written, the files the agent
/// sent (read from `MEDIA:` tags in the text), and the thinking indicator.
///
/// Ids derive only from [ChatMessage.id] (`id`, `id-attachment-N`,
/// `id-sealed-N`, `id-sealed-N-media-I`, `id-tool-N-reasoning`, `id-tool-N`,
/// `id-media-N`, `id-input-N`), where `N` is the index in
/// [ChatMessage.sealedProse] or the index in [ChatMessage.toolCalls] of a
/// run's first call, so a streaming reply that mutates content, status or
/// appends another sealed entry or call maps to ids the controller can
/// match with `updateMessage`.
///
/// A finished reply carries the sources of [sourceCalls], the calls of its
/// whole turn (those of [m] when left out): a turn read from history is
/// several messages, and only the one that ends it shows the row.
List<Message> chatMessageToFlyer(
  ChatMessage m, {
  Iterable<ToolCall> voiceCalls = const [],
  Iterable<ToolCall>? sourceCalls,
}) {
  final authorId = m.role == ChatRole.user ? kUserAuthorId : kAssistantAuthorId;
  final createdAt = m.createdAt.toUtc();
  final ttsCalls = [...voiceCalls, ...m.toolCalls];
  Message attachmentMessage(String id, ChatAttachment attachment) =>
      _attachmentMessage(
        id,
        authorId,
        createdAt,
        attachment,
        transcript: m.role == ChatRole.assistant
            ? voiceTranscript(attachment, ttsCalls)
            : null,
      );
  final thinking = m.status == MessageStatus.thinking;
  // The waiting row stays while the reply runs, so it neither jumps nor
  // closes under the user; once the reply ends a row with no reasoning is
  // dropped, as the stored history never has one.
  final keepEmptyReasoning = m.thinkingStarted && m.isPending;
  final showThinking =
      thinking &&
      // The note says what is going on; a spinner beside it would not be true.
      !m.reconnecting &&
      !m.awaitingInput &&
      m.sealedProse.isEmpty &&
      m.reasoning.isEmpty &&
      !m.toolCalls.any((call) => call.reasoning.isNotEmpty) &&
      // A running call's own card shows what is happening and for how long.
      !m.toolCalls.any((call) => call.status == ToolCallStatus.running) &&
      // A running subagent's cards do the same.
      !m.subagents.any((s) => s.status == SubagentStatus.running);
  final media = m.role == ChatRole.assistant
      ? extractMedia(
          decodeMarkdownEntities(m.displayText ?? m.content),
          complete: !m.isPending,
        )
      : ExtractedMedia(m.displayText ?? m.content, const []);
  InputRequestSlot slotOf(InputRequest request) =>
      m.inputRequestSlots[request.requestId] ??
      (toolCalls: m.toolCalls.length, sealed: m.sealedProse.length);
  // An approval that holds up one of the calls shows inside that call's
  // card rather than on its own.
  final approvals = <int, ApprovalRequest>{
    for (final request in m.inputRequests)
      if (request case ApprovalRequest(:final int toolCallIndex)
          when toolCallIndex < m.toolCalls.length)
        toolCallIndex: request,
  };
  final standalone = [
    for (final (i, request) in m.inputRequests.indexed)
      if (!approvals.containsValue(request)) (i, request),
  ];
  final runs = _toolRuns(m.toolCalls, {
    for (final prose in m.sealedProse) prose.beforeToolCall,
    for (final (_, request) in standalone) slotOf(request).toolCalls,
  });

  // While the reply runs, the Bot screen's preview belongs to the run that
  // holds its latest `computer_use` call.
  final screenCall = m.role == ChatRole.assistant && m.isPending
      ? m.toolCalls.lastIndexWhere((call) => call.name == kComputerUseTool)
      : -1;

  Iterable<Message> sealedProse(int place) sync* {
    final text = m.sealedProse[place].text;
    final media = m.role == ChatRole.assistant
        ? extractMedia(decodeMarkdownEntities(text))
        : ExtractedMedia(text, const []);
    if (media.text.isNotEmpty) {
      yield TextMessage(
        id: '${m.id}-sealed-$place',
        authorId: authorId,
        createdAt: createdAt,
        text: normalizeMarkdown(media.text),
      );
    }
    for (final (i, attachment) in media.attachments.indexed) {
      yield attachmentMessage('${m.id}-sealed-$place-media-$i', attachment);
    }
  }

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
        for (final (i, request) in standalone)
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
        if (place >= 0) ...sealedProse(place),
      ],
    ];
  }

  final messages = <Message>[
    for (final (i, attachment) in m.attachments.indexed)
      attachmentMessage('${m.id}-attachment-$i', attachment),
    for (final run in runs) ...[
      ...before(run.start),
      if (run.calls.first.reasoning.isNotEmpty ||
          (run.start == 0 && keepEmptyReasoning))
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
        metadata: {
          kMetaKind: kKindToolGroup,
          kMetaToolCalls: run.calls,
          if (_approvalsOf(run, approvals) case final held when held.isNotEmpty)
            kMetaToolApprovals: held,
          if (screenCall >= run.start &&
              screenCall < run.start + run.calls.length)
            kMetaScreenPreview: ScreenPreviewRun(m.id, m.createdAt),
        },
      ),
    ],
    ...before(m.toolCalls.length),
    if (m.subagents.isNotEmpty)
      CustomMessage(
        id: '${m.id}-subagents',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindSubagents, kMetaSubagents: m.subagents},
      ),
    if (m.reasoning.isNotEmpty ||
        (keepEmptyReasoning &&
            m.toolCalls.isEmpty &&
            !thinking &&
            !m.awaitingInput))
      _reasoningMessage(
        // The next call inherits this reasoning and its row identity, so an
        // expanded disclosure stays open when the tool begins.
        '${m.id}-tool-${m.toolCalls.length}-reasoning',
        authorId,
        createdAt,
        m.reasoning,
        active: m.isPending && m.reasoningActive,
      ),
    if (!thinking && (media.text.isNotEmpty || m.status == MessageStatus.error))
      TextMessage(
        id: m.id,
        authorId: authorId,
        createdAt: createdAt,
        text: m.role == ChatRole.user
            ? media.text
            : insertTableBlankLines(media.text),
        metadata: _withRegenerated(m, switch (m.status) {
          MessageStatus.error when m.loss != null && m.error == null => {
            kMetaLoss: m.loss!.name,
          },
          MessageStatus.error when m.error != null => {kMetaError: m.error},
          MessageStatus.error => {
            kMetaFailure: switch (m.failure ?? ReplyFailure.generic) {
              ReplyFailure.generic when m.serverMayRun => kFailureMayStillRun,
              final failure => failure.name,
            },
          },
          MessageStatus.streaming => {kMetaStreaming: true},
          _ when m.stopped => {kMetaStopped: true},
          _ => null,
        }),
      ),
    for (final (i, attachment) in media.attachments.indexed)
      attachmentMessage('${m.id}-media-$i', attachment),
    if (m.reconnecting && m.isPending)
      CustomMessage(
        id: '${m.id}-reconnecting',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {
          kMetaKind: kKindReconnecting,
          kMetaReconnectEpisode: m.reconnectEpisodes,
          kMetaReconnectIdle: m.reconnectIdle,
        },
      ),
    if (showThinking)
      CustomMessage(
        id: '${m.id}-tool-${m.toolCalls.length}-reasoning',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {
          kMetaKind: kKindThinking,
          kMetaThinkingStartedAt: m.createdAt,
          kMetaThinkingActivity: m.activity ?? 'Thinking…',
          if (m.activityKind != null) kMetaThinkingActivityKind: m.activityKind,
        },
      ),
  ];
  // A row appearing under half a sentence would move the text, so only a
  // finished reply shows its sources.
  final turnCalls = sourceCalls ?? m.toolCalls;
  if (m.role == ChatRole.assistant && !m.isPending && turnCalls.isNotEmpty) {
    final at = messages.indexWhere((e) => e is TextMessage && e.id == m.id);
    final sources = at < 0
        ? const <TurnSource>[]
        : collectTurnSources(turnCalls);
    if (sources.isNotEmpty) {
      messages[at] = messages[at].copyWith(
        metadata: {...?messages[at].metadata, kMetaSources: sources},
      );
    }
  }
  if (m.canonicalRow case final row? when messages.isNotEmpty) {
    final last = messages.last;
    messages[messages.length - 1] = last.copyWith(
      metadata: {...?last.metadata, kMetaCanonicalRow: row},
    );
  }
  return messages;
}

/// [meta] with the regenerated mark of [m], if it has one and did not fail: a
/// failed reply replaced nothing the person can read.
Map<String, dynamic>? _withRegenerated(
  ChatMessage m,
  Map<String, dynamic>? meta,
) => m.regenerated && m.status != MessageStatus.error
    ? {...?meta, kMetaRegenerated: true}
    : meta;

List<Message> chatThreadToFlyer(ChatThread t) =>
    chatMessagesToFlyer(t.messages);

/// [messages] with an outcome line for each of [outcomes] (oldest first),
/// each placed by [outcomeLineIndex].
List<Message> withOutcomeLines(
  List<Message> messages,
  List<TranscriptOutcome> outcomes,
) {
  final result = [...messages];
  for (final (i, outcome) in outcomes.indexed) {
    result.insert(
      outcomeLineIndex(result, outcome.at),
      outcomeLineMessage(i, outcome),
    );
  }
  return result;
}

/// The [kKindOutcomeLine] row for the [index]th outcome of a chat. Its id
/// holds `-local-` and the settle time, so it never matches a message.
Message outcomeLineMessage(int index, TranscriptOutcome outcome) =>
    CustomMessage(
      id: 'outcome-local-${outcome.at.microsecondsSinceEpoch}-$index',
      authorId: kOutcomeAuthorId,
      createdAt: outcome.at.toUtc(),
      metadata: {kMetaKind: kKindOutcomeLine, kMetaOutcome: outcome},
    );

/// Where a line that settled [at] goes among [messages]: after the last one
/// from no later than [at], or at the end when every message is later (a
/// server clock ahead of this device's).
int outcomeLineIndex(List<Message> messages, DateTime at) {
  final last = messages.lastIndexWhere(
    (m) => !(m.createdAt?.isAfter(at) ?? false),
  );
  return last < 0 ? messages.length : last + 1;
}

/// Whether the turn goes on in [next] after [message]: a stored turn is
/// several assistant rows, and each row that only made tool calls (no text of
/// its own) hands over to the next. A reply with text ends its turn, so one
/// that follows it with no prompt between (another client's) starts its own.
bool continuesTurn(ChatMessage message, ChatMessage? next) =>
    next != null &&
    next.role == ChatRole.assistant &&
    message.role == ChatRole.assistant &&
    message.content.isEmpty &&
    message.toolCalls.isNotEmpty;

/// Words the user folded into a running turn: not a new prompt.
bool _isSteer(ChatMessage message) =>
    message.role == ChatRole.user && message.displayKind == kSteerDisplayKind;

/// The calls of the turn that the message at [at] of [messages] ends, which is
/// what its sources row is read from; empty when the turn goes on after it.
/// A steer row between two messages of a turn does not end it.
List<ToolCall> _turnCallsEndingAt(List<ChatMessage> messages, int at) {
  var next = at + 1;
  while (next < messages.length && _isSteer(messages[next])) {
    next++;
  }
  if (next < messages.length && continuesTurn(messages[at], messages[next])) {
    return const [];
  }
  var start = at;
  while (true) {
    var before = start - 1;
    while (before >= 0 && _isSteer(messages[before])) {
      before--;
    }
    if (before < 0 || !continuesTurn(messages[before], messages[start])) break;
    start = before;
  }
  return [for (var i = start; i <= at; i++) ...messages[i].toolCalls];
}

/// The end (exclusive) of the turn the message at [at] of [messages] belongs
/// to, from [at] on: what an older history page loaded before [at + 1] is
/// mapped together with.
int turnEndAfter(List<ChatMessage> messages, int at) {
  // A steer row at [at] hands over from the message before it.
  var last = at;
  while (last > 0 && _isSteer(messages[last])) {
    last--;
  }
  var end = at + 1;
  for (var i = at + 1; i < messages.length; i++) {
    if (_isSteer(messages[i])) continue;
    if (!continuesTurn(messages[last], messages[i])) break;
    last = i;
    end = i + 1;
  }
  return end;
}

/// The calls of the turn that [message] ends in [messages], or null when
/// [message] is not among them (a reply not yet added), which leaves it to
/// its own calls.
List<ToolCall>? turnCallsEndedBy(
  List<ChatMessage> messages,
  ChatMessage message,
) {
  final at = messages.lastIndexOf(message);
  return at < 0 ? null : _turnCallsEndingAt(messages, at);
}

/// Stored tool calls and their final reply are separate assistant rows.
/// Carry TTS results only within the same turn when restoring history, and
/// give the sources of the whole turn to the message that ends it.
List<Message> chatMessagesToFlyer(Iterable<ChatMessage> messages) {
  final all = messages.toList();
  final result = <Message>[];
  final calls = <ToolCall>[];
  for (final (i, message) in all.indexed) {
    if (message.role == ChatRole.user) calls.clear();
    result.addAll(
      chatMessageToFlyer(
        message,
        voiceCalls: calls,
        sourceCalls: _turnCallsEndingAt(all, i),
      ),
    );
    calls.addAll(message.toolCalls);
  }
  return result;
}

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

/// The approvals of [approvals] (by index in the reply's calls) that hold up
/// a call of [run], by the call's position in the run.
Map<int, ApprovalRequest> _approvalsOf(
  ({int start, List<ToolCall> calls}) run,
  Map<int, ApprovalRequest> approvals,
) => {for (final (i, _) in run.calls.indexed) i: ?approvals[run.start + i]};

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
    if (active) kMetaThinkingStartedAt: createdAt,
  },
);

/// An image the app can draw, from this device, the history or the server, is
/// an [ImageMessage]; any other file, and an image it cannot draw, is a
/// [FileMessage] shown as a card with its name.
Message _attachmentMessage(
  String id,
  String authorId,
  DateTime createdAt,
  ChatAttachment attachment, {
  String? transcript,
}) {
  final metadata = <String, dynamic>{
    kMetaAttachment: attachment,
    kMetaVoiceTranscript: ?transcript,
  };
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
