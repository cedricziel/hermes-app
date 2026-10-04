import 'chat_models.dart';
import 'chat_transport.dart';

const kReplyFailedMessage = 'Something went wrong. Try sending it again.';

const kReplyStoppedMessage = 'Stopped.';

const kProfileUnavailableMessage =
    'That profile is no longer available. Pick another one.';

/// Folds a transport event into the assistant message it belongs to. Thread
/// events concern the thread, not the reply, and are left to the caller.
void applyReplyEvent(ChatMessage reply, ChatEvent event) {
  switch (event) {
    case ReplyDelta(:final text):
      reply.content += text;
      reply.status = MessageStatus.streaming;
    case ReplyCheckpoint(:final text):
      if (text.isEmpty) return;
      final sealed = reply.sealedProse;
      if (reply.content.isEmpty &&
          sealed.isNotEmpty &&
          sealed.last.awaitingCheckpoint) {
        // The text was sealed when a tool call began; this is its final form.
        // It stays marked until the call starts, so the reasoning fallback
        // Hermes repeats it in is still kept out.
        reply.sealedProse = [...sealed]
          ..last = SealedProse(
            text,
            beforeToolCall: sealed.last.beforeToolCall,
            awaitingCheckpoint: true,
          );
        return;
      }
      _seal(reply, text);
      reply.content = '';
    case ReasoningUpdated(:final text, fallback: false):
      reply.reasoning += text;
    case ReasoningUpdated(:final text, fallback: true):
      if (reply.reasoning.isEmpty && !_wroteSinceLastToolCall(reply)) {
        reply.reasoning = text;
      }
    case ToolPreparing(:final name):
      _seal(reply, reply.content, awaitingCheckpoint: true);
      reply.content = '';
      reply.toolCalls = [
        ...reply.toolCalls,
        ToolCall(
          name: name,
          summary: '',
          status: ToolCallStatus.running,
          reasoning: reply.reasoning,
          preparing: true,
        ),
      ];
      reply.reasoning = '';
    case ToolStarted(:final id, :final name, :final summary, :final args):
      _closeCheckpoint(reply);
      _seal(reply, reply.content);
      reply.content = '';
      final prepared = reply.toolCalls.indexWhere(
        (c) => c.preparing && c.name == name,
      );
      if (prepared >= 0) {
        // Calls run in the order the model wrote them, so one written before
        // this that never started ran without reporting (Hermes runs some
        // agent-level tools that way).
        _settleUnreported(reply, before: prepared);
        final call = reply.toolCalls[prepared];
        reply.toolCalls = [...reply.toolCalls]
          ..[prepared] = call.copyWith(
            id: id,
            summary: summary,
            args: args,
            reasoning: call.reasoning + reply.reasoning,
            preparing: false,
            startedAt: DateTime.now(),
          );
      } else {
        _settleUnreported(reply, before: reply.toolCalls.length);
        reply.toolCalls = [
          ...reply.toolCalls,
          ToolCall(
            id: id,
            name: name,
            summary: summary,
            args: args,
            status: ToolCallStatus.running,
            reasoning: reply.reasoning,
            startedAt: DateTime.now(),
          ),
        ];
      }
      reply.reasoning = '';
    case ToolFinished():
      _closeCheckpoint(reply);
      _settleTool(reply, event);
    case ApprovalRequested(:final request):
      final call = _callAwaiting(reply, request);
      _addInputRequest(
        reply,
        call == null ? request : request.forToolCall(call),
      );
    case ClarifyRequested(:final request):
      _addInputRequest(reply, request);
    case VaultRequested(:final request):
      _addInputRequest(reply, request);
    case UnsupportedRequested(:final request):
      _addInputRequest(reply, request);
    case InputRequestExpired(:final requestId):
      expireInputRequests(reply, requestId: requestId);
    case ReplyCompleted(:final text, :final failed, :final stopped):
      if (failed) {
        _markFailed(reply, text.isEmpty ? kReplyFailedMessage : text);
        return;
      }
      if (text.isNotEmpty) reply.content = text;
      reply.stopped = stopped && reply.content.isNotEmpty;
      if (stopped && reply.content.isEmpty) {
        reply.content = kReplyStoppedMessage;
      }
      reply.status = MessageStatus.sent;
      _settleRunningTools(
        reply,
        stopped ? ToolCallStatus.cancelled : ToolCallStatus.completed,
      );
      expireInputRequests(reply);
    case ReplyStarted() || ThreadBound() || ThreadTitled():
      break;
  }
}

/// Ends [reply] after the stream broke, keeping whatever had streamed. [error]
/// is what broke it, when known: it decides the explanation shown.
void failReply(ChatMessage reply, [Object? error]) {
  _markFailed(reply, switch (error) {
    ProfileUnavailableException() => kProfileUnavailableMessage,
    AttachmentException(:final message) => message,
    _ => kReplyFailedMessage,
  });
}

/// Closes off [text] as its own segment, ahead of whatever tool calls have
/// started so far, so it renders where it was actually written instead of
/// always after every tool call the reply ever makes.
void _seal(ChatMessage reply, String text, {bool awaitingCheckpoint = false}) {
  if (text.isEmpty) return;
  reply.sealedProse = [
    ...reply.sealedProse,
    SealedProse(
      text,
      beforeToolCall: reply.toolCalls.length,
      awaitingCheckpoint: awaitingCheckpoint,
    ),
  ];
}

/// Once a tool runs, a checkpoint can no longer be for text sealed before it.
void _closeCheckpoint(ChatMessage reply) {
  final sealed = reply.sealedProse;
  if (sealed.isEmpty || !sealed.last.awaitingCheckpoint) return;
  reply.sealedProse = [...sealed]
    ..last = SealedProse(
      sealed.last.text,
      beforeToolCall: sealed.last.beforeToolCall,
    );
}

/// Ends the calls before [before] that the model wrote but that never
/// reported a start: they ran unreported, so they read as done.
void _settleUnreported(ChatMessage reply, {required int before}) {
  reply.toolCalls = [
    for (final (i, call) in reply.toolCalls.indexed)
      i < before && call.preparing
          ? call.copyWith(status: ToolCallStatus.completed, preparing: false)
          : call,
  ];
}

/// Whether reply text streamed since the last tool call started, still
/// being written or already sealed by a checkpoint.
bool _wroteSinceLastToolCall(ChatMessage reply) =>
    reply.content.isNotEmpty ||
    reply.sealedProse.any(
      // Text sealed as the model began a call it has not run yet still
      // counts: the call has not started.
      (p) => p.beforeToolCall == reply.toolCalls.length || p.awaitingCheckpoint,
    );

/// Adds [request] where the reply is now, after the tool calls started and
/// the text sealed so far, so what the reply does after it renders below its
/// card.
void _addInputRequest(ChatMessage reply, InputRequest request) {
  reply.inputRequests = [...reply.inputRequests, request];
  reply.inputRequestSlots = {
    request.requestId: (
      toolCalls: reply.toolCalls.length,
      sealed: reply.sealedProse.length,
    ),
    ...reply.inputRequestSlots,
  };
}

void _markFailed(ChatMessage reply, String error) {
  reply.error = error;
  reply.status = MessageStatus.error;
  _settleRunningTools(reply, ToolCallStatus.error);
  expireInputRequests(reply);
}

/// Finishes the running call [event] names: by id when Hermes sent one,
/// else the earliest running call of that name.
void _settleTool(ChatMessage reply, ToolFinished event) {
  bool running(ToolCall c) =>
      c.status == ToolCallStatus.running && !c.preparing;
  var i = event.id.isEmpty
      ? -1
      : reply.toolCalls.indexWhere((c) => running(c) && c.id == event.id);
  if (i < 0) {
    i = reply.toolCalls.indexWhere((c) => running(c) && c.name == event.name);
  }
  if (i < 0) return;
  final call = reply.toolCalls[i];
  reply.toolCalls = [...reply.toolCalls]
    ..[i] = call.copyWith(
      status: event.interrupted
          ? ToolCallStatus.cancelled
          : event.failed
          ? ToolCallStatus.error
          : ToolCallStatus.completed,
      result: event.result,
      resultData: event.resultData,
      diff: event.diff,
      duration: event.duration ?? _ranFor(call),
    );
}

/// Ends every call still running. One that never reported a start either
/// ran unreported, when the reply ended normally, or never ran, when it was
/// stopped or failed.
void _settleRunningTools(ChatMessage reply, ToolCallStatus status) {
  reply.toolCalls = [
    for (final call in reply.toolCalls)
      if (call.status != ToolCallStatus.running)
        call
      else if (call.preparing)
        call.copyWith(
          status: status == ToolCallStatus.completed
              ? ToolCallStatus.completed
              : ToolCallStatus.cancelled,
          preparing: false,
        )
      else
        call.copyWith(status: status, duration: _ranFor(call)),
  ];
}

Duration? _ranFor(ToolCall call) {
  final startedAt = call.startedAt;
  return startedAt == null ? null : DateTime.now().difference(startedAt);
}

/// The running call [request] holds up: the latest one of the tool it names,
/// or, when it names none, the only call running. Null when that cannot be
/// told.
int? _callAwaiting(ChatMessage reply, ApprovalRequest request) {
  final running = [
    for (final (i, c) in reply.toolCalls.indexed)
      if (c.status == ToolCallStatus.running && !c.preparing) (i, c),
  ];
  if (request.toolName.isNotEmpty) {
    final named = running.where((e) => e.$2.name == request.toolName);
    return named.isEmpty ? null : named.last.$1;
  }
  return running.length == 1 ? running.single.$1 : null;
}

void recordApproval(ChatMessage reply, String requestId, String choice) =>
    _editPending(
      reply,
      requestId,
      (r) => r is ApprovalRequest ? r.answered(choice) : r,
    );

void recordClarifyAnswers(
  ChatMessage reply,
  String requestId,
  Map<String, List<String>> answers,
) => _editPending(
  reply,
  requestId,
  (r) => r is ClarifyRequest ? r.answeredWith(answers) : r,
);

void recordSkipped(ChatMessage reply, String requestId) => _editPending(
  reply,
  requestId,
  (r) =>
      r is UnsupportedRequest ? r.withStatus(InputRequestStatus.answered) : r,
);

void recordVaultAnswered(
  ChatMessage reply,
  String requestId, {
  String? identifier,
  String? password,
  String? code,
}) => _editPending(
  reply,
  requestId,
  (r) => r is VaultRequest
      ? r.answered(identifier: identifier, password: password, code: code)
      : r,
);

/// Declines a vault prompt: no value goes out, and the card says so.
void recordVaultDeclined(ChatMessage reply, String requestId) => _editPending(
  reply,
  requestId,
  (r) => r is VaultRequest ? r.withStatus(InputRequestStatus.answered) : r,
);

/// Ends the pending requests of [reply], or only [requestId] when given.
void expireInputRequests(ChatMessage reply, {String? requestId}) =>
    _editPending(
      reply,
      requestId,
      (r) => r.withStatus(InputRequestStatus.expired),
    );

void _editPending(
  ChatMessage reply,
  String? requestId,
  InputRequest Function(InputRequest) edit,
) {
  reply.inputRequests = [
    for (final r in reply.inputRequests)
      r.status == InputRequestStatus.pending &&
              (requestId == null || r.requestId == requestId)
          ? edit(r)
          : r,
  ];
}
