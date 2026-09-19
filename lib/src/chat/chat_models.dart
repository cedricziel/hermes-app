/// Chat-side data model for the thread UI. These are UI-facing types only —
/// deliberately independent of the transport shape Hermes Agent's REST/SSE
/// session API will eventually use, so that API can be wired in later
/// (see README: "the foundation for the real chat/session UI, not that UI
/// itself") without reshaping every widget in `lib/src/chat/widgets/`.
library;

enum ChatRole { user, assistant }

enum MessageStatus { sent, thinking, streaming, error }

enum ToolCallStatus { running, completed, error }

/// A single tool invocation surfaced inline in an assistant message, e.g.
/// Hermes running a shell command or a web search on the user's behalf.
class ToolCall {
  const ToolCall({
    required this.name,
    required this.summary,
    this.status = ToolCallStatus.completed,
  });

  final String name;
  final String summary;
  final ToolCallStatus status;

  ToolCall withStatus(ToolCallStatus status) =>
      ToolCall(name: name, summary: summary, status: status);
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.toolCalls = const [],
  });

  final String id;
  final ChatRole role;
  String content;
  final DateTime createdAt;
  MessageStatus status;
  List<ToolCall> toolCalls;

  bool get isPending =>
      status == MessageStatus.thinking || status == MessageStatus.streaming;
}

class ChatThread {
  ChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.pinned = false,
    this.remote = false,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  String id;
  String title;
  DateTime updatedAt;
  bool pinned;

  /// Whether the Hermes dashboard holds this thread, as opposed to a local
  /// draft or mock data.
  bool remote;
  final List<ChatMessage> messages;

  String get preview =>
      messages.isEmpty ? 'No messages yet' : messages.last.content;
}
