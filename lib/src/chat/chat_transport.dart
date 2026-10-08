/// How the chat UI sends a message and receives the streamed reply,
/// independent of the wire protocol. The Hermes dashboard implements it over
/// its `/api/ws` JSON-RPC socket (`prompt.submit` → `message.delta` ...).
library;

import 'dart:typed_data';

import '../models/model_provider_option.dart';
import 'chat_models.dart';
import 'slash_command.dart';

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

/// The model's reasoning: [text] is appended to what has streamed so far.
/// A [fallback] is only a preview Hermes sends after the model answered (its
/// `reasoning.available`, the start of the reply text), for providers that
/// stream nothing: it is shown only when no reasoning or text streamed.
final class ReasoningUpdated extends ChatEvent {
  const ReasoningUpdated(this.text, {this.fallback = false});

  final String text;
  final bool fallback;
}

/// A checkpoint Hermes reached before its answer is done: text it wrote
/// beside a tool call, or before continuing on. [text] is the final form of
/// that segment and replaces whatever streamed for it, which may be only a
/// prefix of it or hold markup Hermes strips.
final class ReplyCheckpoint extends ChatEvent {
  const ReplyCheckpoint(this.text, {this.alreadyStreamed = true});

  final String text;

  /// False when [text] was never streamed, so it must be added to the reply
  /// rather than taken as the final form of text already on screen.
  final bool alreadyStreamed;
}

/// The reply failed with [message] but the server has not sent its final
/// completion yet. Held until the turn settles, so a failure that a later
/// completion explains is not shown twice.
final class ReplyErrored extends ChatEvent {
  const ReplyErrored(this.message);

  final String message;
}

/// The session's state as the server reports it. [running] false is the
/// settle signal: the turn is over even if no completion arrived. A changed
/// [storedSessionId] re-keys the thread whatever [running] says, since
/// compressing the conversation can rotate the id mid-turn.
final class SessionInfo extends ChatEvent {
  const SessionInfo({this.running, this.storedSessionId});

  /// Null when the server did not say.
  final bool? running;
  final String? storedSessionId;
}

/// What the agent is doing while it writes, shown in place of the generic
/// "Thinking…" label. Empty [text] clears it.
final class ReplyStatus extends ChatEvent {
  const ReplyStatus(this.text);

  final String text;
}

/// The server withdrew input requests before they were answered, e.g. an
/// interrupt. An empty [requestIds] means every request of the reply.
final class InputRequestsCancelled extends ChatEvent {
  const InputRequestsCancelled(this.requestIds);

  final List<String> requestIds;
}

/// The server folded the prompt into the turn already running, so no reply of
/// its own will come. The placeholder for it is removed, not shown as failed.
final class PromptFolded extends ChatEvent {
  const PromptFolded();
}

/// A frame of a turn Hermes ran on its own ahead of the prompt just sent, as
/// after a resume that reported `auto_continue`. [ChatTransport.send] hands it
/// over as it arrives and the controller shows it in a reply of its own, in
/// front of the prompt's, which keeps waiting for its turn.
///
/// [event] is what the frame means: a delta, a tool call, an approval, the
/// turn's completion or the idle report that trails it.
final class UnsolicitedEvent extends ChatEvent {
  const UnsolicitedEvent(this.event);

  final ChatEvent event;
}

/// The reply text as the server now holds it. It replaces what streamed since
/// the last seal, because the streamed deltas were lost or are out of date.
final class ReplyRebuilt extends ChatEvent {
  const ReplyRebuilt(this.text);

  final String text;
}

/// The thread's history changed in a way the stream cannot carry, so the
/// controller should read it again over REST once no reply is pending.
final class ThreadNeedsRefetch extends ChatEvent {
  const ThreadNeedsRefetch();
}

/// The model began writing a call to [name]; its arguments are still coming.
final class ToolPreparing extends ChatEvent {
  const ToolPreparing(this.name);

  final String name;
}

final class ToolStarted extends ChatEvent {
  const ToolStarted({
    required this.name,
    this.summary = '',
    this.id = '',
    this.args,
  });

  /// Hermes' id for the call; empty when it sent none.
  final String id;
  final String name;
  final String summary;
  final Map<String, Object?>? args;
}

final class ToolFinished extends ChatEvent {
  const ToolFinished({
    required this.name,
    this.id = '',
    this.failed = false,
    this.interrupted = false,
    this.result = '',
    this.resultData,
    this.diff = '',
    this.duration,
  });

  /// The id of the call this finishes; empty when Hermes sent none, and the
  /// call is then told by [name].
  final String id;
  final String name;
  final bool failed;

  /// The run was killed before it finished, as by stopping the reply.
  final bool interrupted;

  final String result;

  /// The result as Hermes sent it, a decoded JSON value.
  final Object? resultData;

  /// A unified diff of the file the call changed, for edits.
  final String diff;

  /// How long the call ran, when Hermes timed it.
  final Duration? duration;
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

/// The agent waits on a masked vault prompt this app renders itself.
final class VaultRequested extends ChatEvent {
  const VaultRequested(this.request);

  final VaultRequest request;
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

/// A `subagent.*` frame the gateway relayed on the reply's session: one
/// delegated child upserted by its [subagent] id. The gateway sends
/// `subagent.spawn_requested` / `subagent.start` when a child begins,
/// `subagent.progress` / `subagent.tool` / `subagent.thinking` while it
/// works, and `subagent.complete` when it ends.
final class SubagentUpdated extends ChatEvent {
  const SubagentUpdated(this.subagent);

  final Subagent subagent;
}

/// Last event of a reply. [text] is the full final text; [failed] is true when
/// the turn ended in an error and [text] carries the message.
final class ReplyCompleted extends ChatEvent {
  const ReplyCompleted(
    this.text, {
    this.failed = false,
    this.stopped = false,
    this.previewed = false,
    this.reused = false,
    this.transformed = false,
    this.partial = false,
    this.error,
  });

  final String text;
  final bool failed;

  /// The user stopped the reply, so [text] may be short or empty.
  final bool stopped;

  /// [text] is what the server already previewed to the user, so it is not
  /// new text to show again.
  final bool previewed;

  /// [text] is what streamed, sent again as the final answer.
  final bool reused;

  /// [text] is the final form of what streamed, which may differ from it.
  final bool transformed;

  /// The reply failed after some of its text was written; [text] keeps it.
  final bool partial;

  /// Why the reply failed, when it did.
  final String? error;
}

/// Whether [event] shows that a turn is under way, as opposed to a report
/// about the session. The transport takes it for "the turn has begun", and the
/// controller opens a reply for a turn it did not submit.
bool beginsTurn(ChatEvent event) => switch (event) {
  ReplyStarted() ||
  ReplyDelta() ||
  ReasoningUpdated() ||
  ToolPreparing() ||
  ToolStarted() ||
  ToolFinished() ||
  ReplyErrored() => true,
  _ => false,
};

/// Whether [event] opens a turn nobody asked for, as on the follow-ups. A
/// failure or a finished tool call alone is a stray tail of a turn that already
/// ended, so they do not open one; [beginsTurn] counts them for a prompt the
/// app sent itself.
bool opensTurn(ChatEvent event) =>
    beginsTurn(event) && event is! ReplyErrored && event is! ToolFinished;

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
  /// Commands available in the current session or new-chat profile.
  Future<List<SlashCommand>> slashCommands({String? threadId, String? profile});

  /// Executes a slash command immediately, even while a reply is active.
  /// [threadId] is the stored id; a null id creates a Hermes session first.
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  });

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
  ///
  /// [model] runs the thread on that model and effort from this message on;
  /// null leaves the thread on whatever it runs.
  ///
  /// [queued] asks Hermes to queue this message behind a turn still running
  /// in the thread, rather than let it redirect that turn.
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  });

  /// The turns Hermes starts on its own in [threadId] after the reply of the
  /// latest [send] ended: a goal continuation, a queued prompt, finished
  /// background work. Each one runs from [ReplyStarted] to [ReplyCompleted],
  /// and a [ThreadTitled] may arrive between two. Empty when there is no such
  /// reply to follow. A reply still running when the connection drops is
  /// picked up again rather than failed, when the server still has it
  /// running; only a reply the server has since lost ends with an error.
  /// Cancel the stream to stop listening.
  Stream<ChatEvent> followUps(String threadId, {String? profile});

  /// Which sessions are mid-turn right now, by stored session id: `working`
  /// while a turn runs, `waiting` while it waits for the user's answer. A
  /// turn started outside this client (the TUI, another device) shows up
  /// here without this client ever having streamed it. A transport that
  /// cannot ask returns an empty map.
  Future<Map<String, String>> activeStatuses();

  /// Makes sure the connection still works, for when the app comes back from
  /// sleep: iOS and Android drop sockets then, often without saying so. A
  /// connection that does not answer is closed; a reply that was running on
  /// it is picked up again on a fresh connection rather than failed, and the
  /// next [send] opens a new one regardless. Does nothing when no connection
  /// is open.
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

  /// Answers a masked vault prompt: the login to save for [origin], the
  /// master password of [backend], or the one-time code. An empty everything
  /// skips the request: Hermes carries on as if the user declined. Returns
  /// false when the request is no longer pending, and throws when the call
  /// itself fails.
  Future<bool> answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  });

  /// Stops the reply being written to the thread [threadId]. The reply then
  /// ends as [ReplyCompleted] with `stopped` set. Returns false when nothing is
  /// running there, and throws when the call itself fails.
  Future<bool> stopReply(String threadId, {String? profile});

  /// Drops the last prompt of the idle thread [threadId] and everything after
  /// it, so the prompt can be sent again or edited; [retry] says it will be
  /// sent again. Returns how many messages went, or null when the server
  /// cannot undo. Throws when the call itself fails, as while a reply runs.
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  });

  /// Skips a request the app cannot answer, a secret or a sudo password, by
  /// answering it with an empty value: Hermes carries on without it. Returns
  /// false when the request is no longer pending, and throws when the call
  /// itself fails.
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind);

  Future<void> close();
}
