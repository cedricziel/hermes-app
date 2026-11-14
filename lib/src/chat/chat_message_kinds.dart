/// Contract shared by the mapper, the message builders and the chat screen:
/// how Hermes-specific message kinds are encoded as `flutter_chat_core`
/// [CustomMessage] metadata.
library;

/// Author ids used for every message in a thread.
const String kUserAuthorId = 'user';
const String kAssistantAuthorId = 'hermes';

/// `metadata['kind']` values on a `CustomMessage`.
const String kKindToolGroup = 'tool_group';
const String kKindThinking = 'thinking';
const String kKindInputRequest = 'input_request';
const String kKindReasoning = 'reasoning';
const String kKindSubagents = 'subagents';
const String kKindReviewSummary = 'review_summary';

/// A line between messages after a compress or a restore settled ("Conversation
/// compressed · 42 → 9 messages"). It exists only in this app, beside the
/// chat's messages and never among them, so it is no prompt, no reply and
/// nothing Copy Transcript, search, export or any surface reads. It carries
/// `outcome` (a `TranscriptOutcome`: counts and flags, never text).
const String kKindOutcomeLine = 'outcome_line';
const String kMetaOutcome = 'outcome';

/// The author of an outcome line: neither the user nor Hermes, so the line is
/// never grouped with a message.
const String kOutcomeAuthorId = 'app';

/// Metadata keys. A `kKindToolGroup` message carries `calls` (a
/// `List<ToolCall>`): a run of one or more calls the agent made back to back,
/// with no reasoning between them, and `approvals` (a
/// `Map<int, ApprovalRequest>`): the approvals that hold up a call of the
/// run, by the call's position in it. A `kKindInputRequest` message carries
/// `request` (the `InputRequest`). A `kKindReasoning` message carries `text`
/// (String) and `active` (bool, reasoning is arriving), plus an optional
/// `startedAt` while active. A
/// `kKindThinking` message carries `startedAt` (DateTime, when the reply
/// began) and `activity` (String, what it is doing right now).
const String kMetaKind = 'kind';
const String kMetaToolCalls = 'calls';
const String kMetaToolApprovals = 'approvals';

/// Carried by the `kKindToolGroup` message of the run that holds the latest
/// `computer_use` call of a reply that is still running: its
/// [ScreenPreviewRun]. The transcript draws the Bot screen's still preview
/// there.
const String kMetaScreenPreview = 'screenPreview';

/// The reply a Bot screen preview belongs to.
class ScreenPreviewRun {
  const ScreenPreviewRun(this.replyId, this.startedAt);

  final String replyId;

  /// When the reply began; of two replies pending at once, the newer one shows
  /// the preview.
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      other is ScreenPreviewRun &&
      other.replyId == replyId &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(replyId, startedAt);
}

const String kMetaInputRequest = 'request';
const String kMetaThinkingStartedAt = 'startedAt';
const String kMetaThinkingActivity = 'activity';

/// Carried by the `ImageMessage` or `FileMessage` of an attachment: the
/// `ChatAttachment` it stands for.
const String kMetaAttachment = 'attachment';
const String kMetaVoiceTranscript = 'voiceTranscript';

const String kMetaReasoningText = 'text';
const String kMetaReasoningActive = 'active';

/// Carried by a `kKindSubagents` message: the reply's [Subagent]s, a
/// `List<Subagent>`.
const String kMetaSubagents = 'subagents';

/// Carried by a `kKindReviewSummary` message: what the background review
/// saved after the reply, a `List<String>`.
const String kMetaReviewItems = 'items';

/// `metadata` keys on a reply's `TextMessage`: why it failed, or that it is
/// still being written and so has no actions yet.
const String kMetaError = 'error';
const String kMetaStreaming = 'streaming';
const String kMetaStopped = 'stopped';

const String kMetaCanonicalRow = 'canonical_reaction_row';
