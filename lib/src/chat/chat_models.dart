/// Chat-side data model for the thread UI. These are UI-facing types only —
/// deliberately independent of the transport shape of Hermes Agent's session
/// API, so that API can change without reshaping every widget in
/// `lib/src/chat/widgets/`.
library;

import 'dart:typed_data';

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
    this.result = '',
    this.reasoning = '',
  });

  final String name;
  final String summary;
  final ToolCallStatus status;

  /// What the model reasoned just before it made this call.
  final String reasoning;

  /// What the tool returned, as text; empty until it finishes or when the
  /// history did not keep it.
  final String result;

  ToolCall withStatus(ToolCallStatus status, {String? result}) => ToolCall(
    name: name,
    summary: summary,
    status: status,
    result: result ?? this.result,
    reasoning: reasoning,
  );
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

enum UnsupportedKind { secret, sudo }

/// The agent asked for something this app cannot ask the user for yet, such
/// as a secret value or a sudo password, and waits for it elsewhere. Nothing
/// the gateway attached to the request is kept.
final class UnsupportedRequest extends InputRequest {
  const UnsupportedRequest({
    required super.requestId,
    required this.kind,
    super.status,
  });

  final UnsupportedKind kind;

  @override
  UnsupportedRequest withStatus(InputRequestStatus status) =>
      UnsupportedRequest(requestId: requestId, kind: kind, status: status);
}

enum AttachmentKind { image, file }

/// A file that travelled with a message: one the user attached, or one read
/// back from the stored thread.
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.kind,
    this.path,
    this.remotePath,
    this.size,
    this.bytes,
  });

  final String name;
  final AttachmentKind kind;

  /// Where the file the user picked lives on this device, for the thumbnail.
  /// Null for an attachment read back from the server.
  final String? path;

  /// The path the server stored it under, as the thread history names it.
  /// Null for an attachment that was just sent from here.
  final String? remotePath;

  /// Null when unknown, as for a file read back from history.
  final int? size;

  /// The content, when the history embedded it (an inline data URL).
  final Uint8List? bytes;

  /// The server path the app can ask Hermes for the file under: the
  /// [remotePath] when it is absolute. A path relative to the session's
  /// workspace, such as `attachments/x.pdf`, cannot be fetched.
  String? get fetchPath {
    final path = remotePath;
    return path != null && isAbsoluteServerPath(path) ? path : null;
  }
}

final _absoluteServerPath = RegExp(r'^(?:/|[A-Za-z]:[\\/])');

/// Whether [path] is absolute on a POSIX or Windows server.
bool isAbsoluteServerPath(String path) => _absoluteServerPath.hasMatch(path);

final _pathSeparator = RegExp(r'[/\\]');

/// The last part of a POSIX or Windows [path], or [path] itself when it has
/// none.
String fileNameOf(String path) => path
    .split(_pathSeparator)
    .lastWhere((part) => part.isNotEmpty, orElse: () => path);

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.toolCalls = const [],
    this.inputRequests = const [],
    this.attachments = const [],
    this.reasoning = '',
    this.sealedProse = const [],
  });

  final String id;
  final ChatRole role;

  /// The text still being written: everything since the last [sealedProse]
  /// entry, or the whole reply when it never wrote text before a tool call.
  String content;

  /// What the model reasoned after its last tool call, before answering, when
  /// the gateway shares it. Earlier reasoning belongs to [toolCalls].
  String reasoning;
  final DateTime createdAt;
  MessageStatus status;
  List<ToolCall> toolCalls;
  List<InputRequest> inputRequests;

  /// Text the model wrote and then moved on from — before starting a tool
  /// call, or checkpointed by the gateway — in the order it arrived. Empty
  /// for a reply that never interleaved text with tool calls; [content]
  /// alone already reads correctly then.
  List<SealedProse> sealedProse;

  /// What the sender attached, shown above the text.
  final List<ChatAttachment> attachments;

  bool get isPending =>
      status == MessageStatus.thinking || status == MessageStatus.streaming;

  bool get awaitingInput =>
      inputRequests.any((r) => r.status == InputRequestStatus.pending);
}

/// A run of text the model wrote before [beforeToolCall] tool calls had
/// started (the index into [ChatMessage.toolCalls] at the moment it was
/// sealed), so it renders in between the right two tool runs instead of
/// always after every one of them.
class SealedProse {
  const SealedProse(this.text, {required this.beforeToolCall});

  final String text;
  final int beforeToolCall;
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

  /// Whether a reply is still thinking or streaming. A reply that waits for
  /// the user's answer counts, since its turn has not ended.
  bool get isReplying => messages.any((m) => m.isPending);
}
