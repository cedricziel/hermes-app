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

/// Metadata keys. A `kKindToolGroup` message carries `calls` (a
/// `List<ToolCall>`): a run of one or more calls the agent made back to back,
/// with no reasoning between them. A `kKindInputRequest` message carries
/// `request` (the `InputRequest`). A `kKindReasoning` message carries `text`
/// (String) and `active` (bool, the reply is still being written). A
/// `kKindThinking` message carries `startedAt` (DateTime, when the reply
/// began) and `activity` (String, what it is doing right now).
const String kMetaKind = 'kind';
const String kMetaToolCalls = 'calls';
const String kMetaInputRequest = 'request';
const String kMetaThinkingStartedAt = 'startedAt';
const String kMetaThinkingActivity = 'activity';

/// Carried by the `ImageMessage` or `FileMessage` of an attachment: the
/// `ChatAttachment` it stands for.
const String kMetaAttachment = 'attachment';

const String kMetaReasoningText = 'text';
const String kMetaReasoningActive = 'active';

/// `metadata` keys on a reply's `TextMessage`: it failed, or it is still being
/// written and so has no actions yet.
const String kMetaError = 'error';
const String kMetaStreaming = 'streaming';
