/// How the chat UI sends a message and receives the streamed reply,
/// independent of the wire protocol. The Hermes dashboard implements it over
/// its `/api/ws` JSON-RPC socket (`prompt.submit` → `message.delta` ...).
library;

import 'dart:typed_data';

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

/// The model's reasoning: [text] is appended to what has streamed so far, or
/// replaces it when [replace] is set.
final class ReasoningUpdated extends ChatEvent {
  const ReasoningUpdated(this.text, {this.replace = false});

  final String text;
  final bool replace;
}

final class ToolStarted extends ChatEvent {
  const ToolStarted({required this.name, this.summary = ''});

  final String name;
  final String summary;
}

final class ToolFinished extends ChatEvent {
  const ToolFinished({
    required this.name,
    this.failed = false,
    this.result = '',
  });

  final String name;
  final bool failed;
  final String result;
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

/// The agent is waiting on something this app cannot ask for, so the user has
/// to answer it elsewhere.
final class UnsupportedRequested extends ChatEvent {
  const UnsupportedRequested(this.request);

  final UnsupportedRequest request;
}

/// The gateway gave up waiting on request [requestId].
final class InputRequestExpired extends ChatEvent {
  const InputRequestExpired(this.requestId);

  final String requestId;
}

/// Last event of a reply. [text] is the full final text; [failed] is true when
/// the turn ended in an error and [text] carries the message.
final class ReplyCompleted extends ChatEvent {
  const ReplyCompleted(this.text, {this.failed = false, this.stopped = false});

  final String text;
  final bool failed;

  /// The user stopped the reply, so [text] may be short or empty.
  final bool stopped;
}

/// The profile a message was sent under no longer exists on the dashboard, so
/// no session could be created or resumed in it. Sending again fails the same
/// way until another profile is picked.
class ProfileUnavailableException implements Exception {
  const ProfileUnavailableException();

  @override
  String toString() => 'The selected profile is no longer available';
}

/// The most a single attachment may weigh: what Hermes accepts for an image,
/// applied to every file.
const kMaxAttachmentBytes = 25 * 1024 * 1024;

const kAttachmentsUnsupportedMessage =
    "This Hermes server can't receive attachments. "
    'Update Hermes to attach files.';

const kAttachmentUnreadable = 'the file could not be read.';

String attachmentTooLargeMessage(String name) =>
    "$name is larger than ${kMaxAttachmentBytes ~/ (1024 * 1024)} MB "
    "and can't be sent.";

String attachmentFailedMessage(String name, String reason) =>
    'Could not attach $name: $reason';

/// A file to send with a message. Its content is read only when the message
/// goes out.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.name,
    required this.kind,
    required this.read,
    this.mimeType,
  });

  final String name;
  final AttachmentKind kind;
  final String? mimeType;

  /// Reads the whole file.
  final Future<Uint8List> Function() read;
}

/// An attachment could not be sent, so the message was not either. [message]
/// is fit to show the user.
class AttachmentException implements Exception {
  const AttachmentException(this.message);

  final String message;

  @override
  String toString() => 'AttachmentException: $message';
}

abstract interface class ChatTransport {
  /// Sends [text] to the thread [threadId], or starts a new thread when it is
  /// null, and streams the reply. The stream ends after [ReplyCompleted] or
  /// with an error if the connection or the request fails, a
  /// [ProfileUnavailableException] when [profile] no longer exists.
  ///
  /// [profile] is the Hermes profile the thread lives in. A thread id is only
  /// unique within a profile, so it must be the one the thread was listed
  /// under; null leaves it to the dashboard's own profile.
  ///
  /// Each of [attachments] is made available to the agent before [text] goes
  /// out. When one cannot be, nothing is sent and the stream ends with an
  /// [AttachmentException].
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
  });

  /// The turns Hermes starts on its own in [threadId] after the reply of the
  /// latest [send] ended: a goal continuation, a queued prompt, finished
  /// background work. Each one runs from [ReplyStarted] to [ReplyCompleted],
  /// and a [ThreadTitled] may arrive between two. Empty when there is no such
  /// reply to follow. Ends with the connection, and with an error when that
  /// closes mid-turn; cancel it to stop listening.
  Stream<ChatEvent> followUps(String threadId);

  /// Makes sure the connection still works, for when the app comes back from
  /// sleep: iOS and Android drop sockets then, often without saying so. A
  /// connection that does not answer is closed, which ends any reply on it
  /// with an error, and the next [send] opens a new one. Does nothing when no
  /// connection is open.
  Future<void> checkConnection();

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

  /// Stops the reply being written to the thread [threadId]. The reply then
  /// ends as [ReplyCompleted] with `stopped` set. Returns false when nothing is
  /// running there, and throws when the call itself fails.
  Future<bool> stopReply(String threadId);

  /// Skips a request the app cannot answer, a secret or a sudo password, by
  /// answering it with an empty value: Hermes carries on without it. Returns
  /// false when the request is no longer pending, and throws when the call
  /// itself fails.
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind);

  Future<void> close();
}
