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

enum InputRequestStatus { pending, answered, expired }

/// Something the agent asked the user mid-turn and is waiting on.
sealed class InputRequest {
  const InputRequest({
    required this.requestId,
    this.status = InputRequestStatus.pending,
  });

  final String requestId;
  final InputRequestStatus status;

  InputRequest withStatus(InputRequestStatus status);
}

/// The agent wants to run something that needs the user's consent.
final class ApprovalRequest extends InputRequest {
  const ApprovalRequest({
    required super.requestId,
    required this.command,
    required this.description,
    required this.choices,
    super.status,
    this.choice,
  });

  final String command;
  final String description;

  /// What the agent lets the user pick: some of `once`, `session`, `always`,
  /// and `deny`.
  final List<String> choices;

  /// What the user picked, once answered.
  final String? choice;

  ApprovalRequest answered(String choice) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: InputRequestStatus.answered,
    choice: choice,
  );

  @override
  ApprovalRequest withStatus(InputRequestStatus status) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: status,
    choice: choice,
  );
}

class ClarifyQuestion {
  const ClarifyQuestion({
    required this.qid,
    required this.question,
    this.choices = const [],
    this.multiSelect = false,
  });

  /// Empty for the single-question form, which has no ids.
  final String qid;
  final String question;

  /// Empty means the question is open-ended.
  final List<String> choices;
  final bool multiSelect;
}

/// The agent asks one question, or a batch of them, and waits for answers.
final class ClarifyRequest extends InputRequest {
  const ClarifyRequest({
    required super.requestId,
    required this.questions,
    this.batch = false,
    super.status,
    this.answers = const {},
  });

  final List<ClarifyQuestion> questions;

  /// Whether the gateway wants one answer per `qid` instead of a single one.
  final bool batch;

  /// The values given per `qid`, once answered. Empty when the user skipped.
  final Map<String, List<String>> answers;

  ClarifyRequest answeredWith(Map<String, List<String>> answers) =>
      ClarifyRequest(
        requestId: requestId,
        questions: questions,
        batch: batch,
        status: InputRequestStatus.answered,
        answers: answers,
      );

  @override
  ClarifyRequest withStatus(InputRequestStatus status) => ClarifyRequest(
    requestId: requestId,
    questions: questions,
    batch: batch,
    status: status,
    answers: answers,
  );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.toolCalls = const [],
    this.inputRequests = const [],
  });

  final String id;
  final ChatRole role;
  String content;
  final DateTime createdAt;
  MessageStatus status;
  List<ToolCall> toolCalls;
  List<InputRequest> inputRequests;

  bool get isPending =>
      status == MessageStatus.thinking || status == MessageStatus.streaming;

  bool get awaitingInput =>
      inputRequests.any((r) => r.status == InputRequestStatus.pending);
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
