/// Chat-side data model for the thread UI. These are UI-facing types only —
/// deliberately independent of the transport shape of Hermes Agent's session
/// API, so that API can change without reshaping every widget in
/// `lib/src/chat/widgets/`.
library;

import 'dart:typed_data';

import '../models/model_provider_option.dart';
import '../bot_mode/bot_chat_context.dart';

enum ChatRole { user, assistant }

enum MessageStatus { sent, thinking, streaming, error }

/// Where a tool call stands. [cancelled] is a call the reply stopped before
/// it finished, or one the model began to write but never ran.
enum ToolCallStatus { running, completed, error, cancelled }

/// A single tool invocation surfaced inline in an assistant message, e.g.
/// Hermes running a shell command or a web search on the user's behalf.
class ToolCall {
  const ToolCall({
    required this.name,
    required this.summary,
    this.id = '',
    this.status = ToolCallStatus.completed,
    this.args,
    this.result = '',
    this.resultData,
    this.diff = '',
    this.reasoning = '',
    this.preparing = false,
    this.startedAt,
    this.duration,
  });

  /// Hermes' id for the call, which its result answers. Empty when the
  /// server sent none.
  final String id;

  final String name;

  /// A one-line preview of what the call works on, such as the command or
  /// the path.
  final String summary;

  final ToolCallStatus status;

  /// The arguments the model passed, when known.
  final Map<String, Object?>? args;

  /// What the model reasoned just before it made this call.
  final String reasoning;

  /// What the tool returned, as text; empty until it finishes or when the
  /// history did not keep it.
  final String result;

  /// [result] as the tool returned it, a decoded JSON object or list when it
  /// was one, for the cards that show a tool's result in its own shape.
  final Object? resultData;

  /// A unified diff of the file the call changed, for edits; may carry ANSI
  /// colour codes.
  final String diff;

  /// The model is still writing the call's arguments; it has not run yet.
  final bool preparing;

  /// When the call began running, for its elapsed time. Unknown for calls
  /// read from history.
  final DateTime? startedAt;

  /// How long the call ran, once it finished.
  final Duration? duration;

  ToolCall copyWith({
    String? id,
    String? summary,
    ToolCallStatus? status,
    Map<String, Object?>? args,
    String? result,
    Object? resultData,
    String? diff,
    String? reasoning,
    bool? preparing,
    DateTime? startedAt,
    Duration? duration,
  }) => ToolCall(
    id: id ?? this.id,
    name: name,
    summary: summary ?? this.summary,
    status: status ?? this.status,
    args: args ?? this.args,
    result: result ?? this.result,
    resultData: resultData ?? this.resultData,
    diff: diff ?? this.diff,
    reasoning: reasoning ?? this.reasoning,
    preparing: preparing ?? this.preparing,
    startedAt: startedAt ?? this.startedAt,
    duration: duration ?? this.duration,
  );

  ToolCall withStatus(ToolCallStatus status, {String? result}) =>
      copyWith(status: status, result: result);
}

/// Where a delegated subagent stands, mirroring the gateway's
/// `SubagentStatus`: [failed] covers `failed`, `error` and `timeout`; the
/// rest are terminal except [running] (and its spawn-accepted start).
enum SubagentStatus { running, completed, failed, interrupted }

/// One delegated subagent of a reply, as the gateway's `subagent.*` events
/// relay it. [parentId], [depth] and [index] rebuild the spawn tree: an
/// unknown or missing [parentId] makes a top-level spawn of the reply.
class Subagent {
  const Subagent({
    required this.id,
    required this.goal,
    this.parentId,
    this.depth = 0,
    this.index = 0,
    this.count = 1,
    this.status = SubagentStatus.running,
    this.toolCount,
    this.lastTool,
    this.lastToolPreview,
    this.summary,
    this.duration,
    this.model,
    this.childSessionId,
    this.startedAt,
  });

  /// The gateway's id for the child; stable across its events.
  final String id;

  /// What the child was asked to do — its card's headline.
  final String goal;

  /// The parent's id, when this child was itself delegated by a subagent.
  final String? parentId;

  /// Nesting depth (0 = a spawn of the reply) and where in the parent's
  /// batch this child sits, for a stable render order.
  final int depth;
  final int index;

  /// How many children [parentId]'s batch asked for in total.
  final int count;

  final SubagentStatus status;

  final int? toolCount;

  /// The last tool the child started, and the preview of what it is (or was)
  /// working on — its card's live activity line.
  final String? lastTool;
  final String? lastToolPreview;

  /// What the child delivered, once it finished.
  final String? summary;

  final Duration? duration;

  final String? model;

  final String? childSessionId;

  /// When the child started running, for its elapsed time while it runs.
  final DateTime? startedAt;

  Subagent copyWith({
    String? parentId,
    String? goal,
    int? depth,
    int? index,
    int? count,
    SubagentStatus? status,
    int? toolCount,
    String? lastTool,
    String? lastToolPreview,
    String? summary,
    Duration? duration,
    String? model,
    String? childSessionId,
    DateTime? startedAt,
  }) => Subagent(
    id: id,
    goal: goal?.isEmpty != true ? (goal ?? this.goal) : this.goal,
    parentId: parentId ?? this.parentId,
    depth: depth ?? this.depth,
    index: index ?? this.index,
    count: count == null || count == 0 ? this.count : count,
    status: status ?? this.status,
    toolCount: toolCount ?? this.toolCount,
    lastTool: lastTool ?? this.lastTool,
    lastToolPreview: lastToolPreview ?? this.lastToolPreview,
    summary: summary ?? this.summary,
    duration: duration ?? this.duration,
    model: model ?? this.model,
    childSessionId: childSessionId ?? this.childSessionId,
    startedAt: startedAt ?? this.startedAt,
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
    this.toolName = '',
    this.toolCallIndex,
  });

  final String command;
  final String description;

  /// The tool that asked, when Hermes names it.
  final String toolName;

  /// The index, in its reply's [ChatMessage.toolCalls], of the running call
  /// this approval holds up, so the card can show it inside that call. Null
  /// when it could not be told which call asked.
  final int? toolCallIndex;

  ApprovalRequest forToolCall(int index) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: status,
    choice: choice,
    toolName: toolName,
    toolCallIndex: index,
  );

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
    toolName: toolName,
    toolCallIndex: toolCallIndex,
  );

  @override
  ApprovalRequest withStatus(InputRequestStatus status) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: status,
    choice: choice,
    toolName: toolName,
    toolCallIndex: toolCallIndex,
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

/// Which masked vault prompt Hermes raised.
enum VaultKind { saveLogin, unlock, code }

/// The agent asks the user, through a masked prompt this app renders itself,
/// for a credential the conversation must never see: a login to save for a
/// site, an external password manager's master password, or a one-time code.
final class VaultRequest extends InputRequest {
  const VaultRequest({
    required super.requestId,
    required this.kind,
    this.origin = '',
    this.site = '',
    this.backend = '',
    this.displayName = '',
    this.hint = '',
    super.status,
    this.identifier = '',
    this.provided = false,
  });

  final VaultKind kind;

  /// The page the login is saved for; empty for the other kinds.
  final String origin;

  /// The site the prompt names the user by: the host of [origin] for a
  /// save-login, the code's site for a one-time code.
  final String site;

  /// The password manager to unlock, and its display name; empty for the
  /// other kinds.
  final String backend;
  final String displayName;
  final String hint;

  /// The identifier the user gave, once answered — a username or email, not
  /// itself a secret. The password and the one-time code live only in the
  /// answer frame; the card keeps whether one was sent.
  final String identifier;

  /// Whether the user submitted a value, as opposed to declining. [withStatus]
  /// keeps it, so a declined card stays declined when it expires late.
  final bool provided;

  VaultRequest answered({String? identifier, bool? provided}) => VaultRequest(
    requestId: requestId,
    kind: kind,
    origin: origin,
    site: site,
    backend: backend,
    displayName: displayName,
    hint: hint,
    status: InputRequestStatus.answered,
    identifier: identifier ?? this.identifier,
    provided: provided ?? true,
  );

  @override
  VaultRequest withStatus(InputRequestStatus status) => VaultRequest(
    requestId: requestId,
    kind: kind,
    origin: origin,
    site: site,
    backend: backend,
    displayName: displayName,
    hint: hint,
    status: status,
    identifier: identifier,
    provided: provided,
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
    this.submittedText,
    this.displayText,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.toolCalls = const [],
    this.inputRequests = const [],
    this.inputRequestSlots = const {},
    this.attachments = const [],
    this.reasoning = '',
    this.sealedProse = const [],
    this.subagents = const [],
    this.error,
  });

  final String id;
  final ChatRole role;

  /// The text still being written: everything since the last [sealedProse]
  /// entry, or the whole reply when it never wrote text before a tool call.
  String content;

  /// The prompt sent to Hermes when [content] is a display-only command label.
  final String? submittedText;

  /// Backend-provided transcript display text, separate from the original content.
  final String? displayText;

  /// What the model reasoned after its last tool call, before answering, when
  /// the gateway shares it. Earlier reasoning belongs to [toolCalls].
  String reasoning;
  final DateTime createdAt;
  MessageStatus status;

  /// The user stopped this reply after some of it had streamed, so it is not
  /// the whole answer. Known only to this app, not to reloaded history.
  bool stopped = false;
  List<ToolCall> toolCalls;
  List<InputRequest> inputRequests;

  /// The delegated subagents of this reply, in the order they spawned. The
  /// gateway relays their lifecycle as `subagent.*` events on the reply's
  /// session; read-from-history replies do not carry them yet.
  List<Subagent> subagents;

  /// Where each of [inputRequests] arrived, by request id, so its card
  /// renders after the call that asked and before whatever followed. A
  /// request missing here renders after everything but the text.
  Map<String, InputRequestSlot> inputRequestSlots;

  /// Text the model wrote and then moved on from — before starting a tool
  /// call, or checkpointed by the gateway — in the order it arrived. Empty
  /// for a reply that never interleaved text with tool calls; [content]
  /// alone already reads correctly then.
  List<SealedProse> sealedProse;

  /// What the sender attached, shown above the text.
  final List<ChatAttachment> attachments;

  /// Why the reply failed, shown under whatever text it kept.
  String? error;

  /// What the agent is doing now, shown in the thinking row. Null keeps the
  /// generic label.
  String? activity;

  /// The turn ended without its completion, so [content] is what streamed,
  /// taken as final. A completion that arrives later still applies.
  bool settledWithoutCompletion = false;

  /// An error event arrived for this reply and no completion has come yet.
  bool errorEventSeen = false;

  /// The message of a held error event. It is shown only if the turn settles
  /// without a completion that would carry its own error.
  String? pendingError;

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
  const SealedProse(
    this.text, {
    required this.beforeToolCall,
    this.awaitingCheckpoint = false,
  });

  final String text;
  final int beforeToolCall;

  /// Sealed from what streamed, when the model began writing a tool call;
  /// Hermes' checkpoint for the same text is still to come and replaces it.
  final bool awaitingCheckpoint;
}

/// How many tool calls had started and how many [ChatMessage.sealedProse]
/// entries were sealed when an input request arrived.
typedef InputRequestSlot = ({int toolCalls, int sealed});

class ChatThread {
  ChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.pinned = false,
    this.folderPath,
    this.remote = false,
    this.modelChoice,
    this.botContext,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  BotChatContext? botContext;
  bool get isCanonicalBotChat => botContext != null;

  String id;
  String title;
  DateTime updatedAt;
  bool pinned;
  final String? folderPath;

  /// Whether the Hermes dashboard holds this thread, as opposed to a local
  /// draft or mock data.
  bool remote;
  final List<ChatMessage> messages;

  /// The model picked for this thread; null runs the profile's default.
  ModelChoice? modelChoice;

  String get preview =>
      messages.isEmpty ? 'No messages yet' : messages.last.content;

  /// Whether a reply is still thinking or streaming. A reply that waits for
  /// the user's answer counts, since its turn has not ended.
  bool get isReplying => messages.any((m) => m.isPending);
}

/// A stretch of a search hit's text, [match] when the search found it.
typedef SnippetPart = ({String text, bool match});

/// A chat the session search found, with the text that matched.
class ThreadSearchHit {
  const ThreadSearchHit({
    required this.id,
    required this.title,
    required this.snippet,
    required this.updatedAt,
    this.profile,
  });

  final String id;
  final String title;
  final List<SnippetPart> snippet;
  final DateTime updatedAt;

  /// The profile the chat belongs to, when the search said.
  final String? profile;
}
