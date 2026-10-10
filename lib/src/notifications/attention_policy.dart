import 'package:characters/characters.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import 'request_notifications.dart';

const kPreviewLength = 120;
const kReplyReadyBody = 'Reply ready';
const kReplyFailedBody = 'Reply failed';
const kApprovalBody = 'Waiting for your approval';
const kQuestionBody = 'Has a question for you';
const kNeedsYouBody = 'Waiting for you in Hermes';
const kAnswerFailedBody = "Couldn't send your answer. Open Hermes to answer.";

/// The most characters of a command or a question a request notification
/// shows.
const kRequestBodyLength = 1000;

/// What to tell the user about, and for which thread or scheduled task.
class AttentionNotification {
  const AttentionNotification({
    required this.threadId,
    required this.title,
    required this.body,
    this.profile,
    this.category,
    this.request,
  }) : jobId = null;

  /// A scheduled task's run. It replaces an earlier notification for the same
  /// job, like a chat's does.
  const AttentionNotification.job({
    required String this.jobId,
    required this.title,
    required this.body,
    this.profile,
  }) : threadId = 'job:$jobId',
       category = null,
       request = null;

  /// Names the notification: the chat's id, or `job:<id>` for a task, so the
  /// two never replace each other.
  final String threadId;

  /// The scheduled task this is about, if it is about one.
  final String? jobId;

  /// The Hermes profile [threadId] or [jobId] belongs to, when it is known.
  final String? profile;
  final String title;
  final String body;

  /// The buttons that answer the request this is about, if it can be
  /// answered from the notification.
  final RequestCategory? category;

  /// What answering it needs; set together with [category].
  final PendingRequest? request;
}

/// The start of [text] on one line, for a notification body.
String replyPreview(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final characters = flat.characters;
  if (characters.length <= kPreviewLength) return flat;
  return '${characters.take(kPreviewLength).toString().trimRight()}…';
}

/// The notification [event] on [thread] deserves, or null. Nothing is said
/// while the app is focused on that very thread, or while notifications are
/// off. An approval shows its command and a question the question, with the
/// buttons that answer them; their category's placeholder hides the text
/// while the system hides previews, as on a locked screen. Anything else the
/// agent asks for stays generic.
AttentionNotification? attentionFor({
  required ChatEvent event,
  required ChatThread thread,
  required bool appFocused,
  required String? selectedThreadId,
  required bool enabled,
  String? profile,
}) {
  if (!enabled) return null;
  if (appFocused && selectedThreadId == thread.id) return null;
  final body = switch (event) {
    ReplyCompleted(stopped: true) => null,
    ReplyCompleted(:final text, :final failed) =>
      failed
          ? kReplyFailedBody
          : (replyPreview(text).isEmpty ? kReplyReadyBody : replyPreview(text)),
    ApprovalRequested(:final request) => _requestBody([
      request.command,
      request.description,
    ], kApprovalBody),
    ClarifyRequested(request: ClarifyRequest(:final questions)) =>
      questions.length == 1
          ? _requestBody([questions.single.question], kQuestionBody)
          : kQuestionBody,
    VaultRequested() => kNeedsYouBody,
    UnsupportedRequested() => kNeedsYouBody,
    _ => null,
  };
  if (body == null) return null;
  final InputRequest? request = switch (event) {
    ApprovalRequested(:final request) => request,
    ClarifyRequested(:final request) => request,
    _ => null,
  };
  return AttentionNotification(
    threadId: thread.id,
    title: thread.title,
    body: body,
    profile: profile,
    category: request == null ? null : requestCategoryFor(request),
    request: request == null ? null : pendingRequestFor(request),
  );
}

/// The first of [texts] that is not blank, cut at [kRequestBodyLength], or
/// [fallback].
String _requestBody(List<String> texts, String fallback) {
  final text = texts
      .map((text) => text.trim())
      .firstWhere((text) => text.isNotEmpty, orElse: () => fallback);
  final characters = text.characters;
  if (characters.length <= kRequestBodyLength) return text;
  return '${characters.take(kRequestBodyLength).toString().trimRight()}…';
}
