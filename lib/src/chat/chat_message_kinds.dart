/// Contract shared by the mapper, the message builders and the chat screen:
/// how Hermes-specific message kinds are encoded as `flutter_chat_core`
/// [CustomMessage] metadata.
library;

/// Author ids used for every message in a thread.
const String kUserAuthorId = 'user';
const String kAssistantAuthorId = 'hermes';

/// `metadata['kind']` values on a `CustomMessage`.
const String kKindToolCall = 'tool_call';
const String kKindThinking = 'thinking';
const String kKindInputRequest = 'input_request';
const String kKindReasoning = 'reasoning';

/// Metadata keys. A `kKindToolCall` message carries `name` (String),
/// `summary` (String) and `status` (`ToolCallStatus.name`). A
/// `kKindInputRequest` message carries `request` (the `InputRequest`). A
/// `kKindReasoning` message carries `text` (String) and `active` (bool, the
/// reply is still being written).
const String kMetaKind = 'kind';
const String kMetaToolName = 'name';
const String kMetaToolSummary = 'summary';
const String kMetaToolStatus = 'status';
const String kMetaToolResult = 'result';
const String kMetaInputRequest = 'request';

/// Carried by the `ImageMessage` or `FileMessage` of an attachment: the
/// `ChatAttachment` it stands for.
const String kMetaAttachment = 'attachment';

const String kMetaReasoningText = 'text';
const String kMetaReasoningActive = 'active';

/// `metadata` keys on a reply's `TextMessage`: it failed, or it is still being
/// written and so has no actions yet.
const String kMetaError = 'error';
const String kMetaStreaming = 'streaming';
