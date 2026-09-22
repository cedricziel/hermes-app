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
    case ReplyCheckpoint(:final text, :final alreadyStreamed):
      _seal(reply, alreadyStreamed ? reply.content : text);
      if (alreadyStreamed) reply.content = '';
    case ReasoningUpdated(:final text, :final replace):
      reply.reasoning = replace ? text : reply.reasoning + text;
    case ToolStarted(:final name, :final summary):
      _seal(reply, reply.content);
      reply.content = '';
      reply.toolCalls = [
        ...reply.toolCalls,
        ToolCall(
          name: name,
          summary: summary,
          status: ToolCallStatus.running,
          reasoning: reply.reasoning,
        ),
      ];
      reply.reasoning = '';
    case ToolFinished(:final name, :final failed, :final result):
      _settleTool(
        reply,
        name,
        failed ? ToolCallStatus.error : ToolCallStatus.completed,
        result,
      );
    case ApprovalRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
    case ClarifyRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
    case UnsupportedRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
    case InputRequestExpired(:final requestId):
      expireInputRequests(reply, requestId: requestId);
    case ReplyCompleted(:final text, :final failed, :final stopped):
      if (text.isNotEmpty) reply.content = text;
      if (failed) {
        _markFailed(reply, kReplyFailedMessage);
        return;
      }
      if (stopped && reply.content.isEmpty) {
        reply.content = kReplyStoppedMessage;
      }
      reply.status = MessageStatus.sent;
      _settleRunningTools(reply, ToolCallStatus.completed);
      expireInputRequests(reply);
    case ReplyStarted() || ThreadBound() || ThreadTitled():
      break;
  }
}

/// Ends [reply] after the stream broke, keeping whatever had streamed. [error]
/// is what broke it, when known: it decides the message shown.
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
void _seal(ChatMessage reply, String text) {
  if (text.isEmpty) return;
  reply.sealedProse = [
    ...reply.sealedProse,
    SealedProse(text, beforeToolCall: reply.toolCalls.length),
  ];
}

void _markFailed(ChatMessage reply, String fallbackContent) {
  if (reply.content.isEmpty) reply.content = fallbackContent;
  reply.status = MessageStatus.error;
  _settleRunningTools(reply, ToolCallStatus.error);
  expireInputRequests(reply);
}

void _settleTool(
  ChatMessage reply,
  String name,
  ToolCallStatus status,
  String result,
) {
  final i = reply.toolCalls.indexWhere(
    (c) => c.name == name && c.status == ToolCallStatus.running,
  );
  if (i < 0) return;
  reply.toolCalls = [...reply.toolCalls]
    ..[i] = reply.toolCalls[i].withStatus(status, result: result);
}

void _settleRunningTools(ChatMessage reply, ToolCallStatus status) {
  reply.toolCalls = [
    for (final call in reply.toolCalls)
      call.status == ToolCallStatus.running ? call.withStatus(status) : call,
  ];
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
