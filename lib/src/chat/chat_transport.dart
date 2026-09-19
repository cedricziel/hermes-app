/// How the chat UI sends a message and receives the streamed reply,
/// independent of the wire protocol. The Hermes dashboard implements it over
/// its `/api/ws` JSON-RPC socket (`prompt.submit` → `message.delta` ...).
library;

import 'chat_models.dart';

sealed class ChatEvent {
  const ChatEvent();
}

/// First event when [ChatTransport.send] starts a new thread: the id the
/// dashboard stored it under, the same id `GET /api/sessions` lists.
final class ThreadBound extends ChatEvent {
  const ThreadBound(this.threadId);

  final String threadId;
}

final class ReplyStarted extends ChatEvent {
  const ReplyStarted();
}

/// A chunk of reply text to append to what has streamed so far.
final class ReplyDelta extends ChatEvent {
  const ReplyDelta(this.text);

  final String text;
}

final class ToolStarted extends ChatEvent {
  const ToolStarted({required this.name, this.summary = ''});

  final String name;
  final String summary;
}

final class ToolFinished extends ChatEvent {
  const ToolFinished({required this.name, this.failed = false});

  final String name;
  final bool failed;
}

/// The dashboard named (or renamed) the thread.
final class ThreadTitled extends ChatEvent {
  const ThreadTitled(this.title);

  final String title;
}

/// The agent is waiting for the user's consent to run something.
final class ApprovalRequested extends ChatEvent {
  const ApprovalRequested(this.request);

  final ApprovalRequest request;
}

/// The agent is waiting for the user to answer one or more questions.
final class ClarifyRequested extends ChatEvent {
  const ClarifyRequested(this.request);

  final ClarifyRequest request;
}

/// The gateway gave up waiting on request [requestId].
final class InputRequestExpired extends ChatEvent {
  const InputRequestExpired(this.requestId);

  final String requestId;
}

/// Last event of a reply. [text] is the full final text; [failed] is true when
/// the turn ended in an error and [text] carries the message.
final class ReplyCompleted extends ChatEvent {
  const ReplyCompleted(this.text, {this.failed = false});

  final String text;
  final bool failed;
}

abstract interface class ChatTransport {
  /// Sends [text] to the thread [threadId], or starts a new thread when it is
  /// null, and streams the reply. The stream ends after [ReplyCompleted] or
  /// with an error if the connection or the request fails.
  Stream<ChatEvent> send({String? threadId, required String text});

  /// Answers an approval the agent is waiting on with one of its choices.
  /// Returns false when the request is no longer pending, and throws when the
  /// call itself fails.
  Future<bool> answerApproval(String requestId, String choice);

  /// Answers a clarify request, or one question of a batch when [questionId]
  /// is given. An empty [values] skips: without a [questionId] that cancels the
  /// whole request. Returns false when the request is no longer pending, and
  /// throws when the call itself fails.
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  });

  Future<void> close();
}
