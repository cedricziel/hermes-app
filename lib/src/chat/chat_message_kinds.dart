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

/// Metadata keys. A `kKindToolCall` message carries `name` (String),
/// `summary` (String) and `status` (`ToolCallStatus.name`). A
/// `kKindInputRequest` message carries `request` (the `InputRequest`).
const String kMetaKind = 'kind';
const String kMetaToolName = 'name';
const String kMetaToolSummary = 'summary';
const String kMetaToolStatus = 'status';
const String kMetaInputRequest = 'request';
