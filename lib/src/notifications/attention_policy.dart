import 'package:characters/characters.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import 'request_notifications.dart';
import 'notification_preview.dart';

const kPreviewLength = 120;
const kReplyReadyBody = 'Reply ready';
const kReplyFailedBody = 'Reply failed';
const kNewMessageBody = 'New message';
const kApprovalBody = 'Waiting for your approval';
const kQuestionBody = 'Has a question for you';
const kNeedsYouBody = 'Waiting for you in Hermes';
const kAnswerFailedBody = "Couldn't send your answer. Open Hermes to answer.";
const kOpenToAnswerBody = 'Open Hermes to answer.';

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
    this.needsInput = false,
    this.prompt,
    this.bodyIsPlainText = false,
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
       request = null,
       bodyIsPlainText = false,
       needsInput = false,
       prompt = null;

  /// Names the notification: the chat's id, or `job:<id>` for a task, so the
  /// two never replace each other.
  final String threadId;

  /// The scheduled task this is about, if it is about one.
  final String? jobId;

  /// The Hermes profile [threadId] or [jobId] belongs to, when it is known.
  final String? profile;
  final String title;
  final String body;

  /// Prevents reparsing rendered code and escaped punctuation in reply previews.
  final bool bodyIsPlainText;

  /// The buttons that answer the request this is about, if it can be
  /// answered from the notification.
  final RequestCategory? category;

  /// What answering it needs; set together with [category].
  final PendingRequest? request;

  /// The agent waits for something that has no [category]: a secret, or input
  /// the app cannot ask for.
  final bool needsInput;

  /// A question that never reached Hermes: tapping the notification opens a
  /// new chat with it in the composer, unsent. Only the payload holds it, the
  /// notification does not show it.
  final String? prompt;

  /// Whether the agent is blocked on the user, which is what may break
  /// through a Focus.
  bool get timeSensitive => category?.isRequest == true || needsInput;

  /// What the system stacks this notification with: the chat, or the
  /// scheduled task, within its profile. The profile is encoded so that no
  /// profile name can pass for part of an id.
  String get groupKey {
    final owner = Uri.encodeComponent(profile ?? '');
    final job = jobId;
    return job == null ? 'chat:$owner/$threadId' : 'job:$owner/$job';
  }
}

/// The start of [text] as plain Markdown text, for a notification body.
String replyPreview(String text) =>
    _cut(notificationPreview(text), kPreviewLength);

/// [text] cut at [length] user-perceived characters, with an ellipsis when
/// cut.
String _cut(String text, int length) {
  final characters = text.characters;
  if (characters.length <= length) return text;
  return '${characters.take(length).toString().trimRight()}…';
}

/// The notification [event] on [thread] deserves, or null. Nothing is said
/// while the app is focused on that very thread, or while notifications are
/// off. An approval shows its command and a question the question, with the
/// buttons that answer them; their category's placeholder hides the text
/// while the system hides previews, as on a locked screen. Anything else the
/// agent asks for stays generic. While [appLock] is on, replies and requests
/// stay generic and requests have no answer buttons.
AttentionNotification? attentionFor({
  required ChatEvent event,
  required ChatThread thread,
  required bool appFocused,
  required String? selectedThreadId,
  required bool enabled,
  String? profile,
  bool appLock = false,
}) {
  if (!enabled) return null;
  if (appFocused && selectedThreadId == thread.id) return null;
  final body = switch (event) {
    ReplyCompleted(stopped: true) => null,
    ReplyCompleted(:final text, :final failed) =>
      failed
          ? kReplyFailedBody
          : appLock || replyPreview(text).isEmpty
          ? kReplyReadyBody
          : replyPreview(text),
    ApprovalRequested() when appLock => kApprovalBody,
    ClarifyRequested() when appLock => kQuestionBody,
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
    bodyIsPlainText: event is ReplyCompleted,
    profile: profile,
    needsInput: event is VaultRequested || event is UnsupportedRequested,
    category: switch (event) {
      ReplyCompleted(failed: true) => replyFailedCategory,
      ReplyCompleted() => replyReadyCategory,
      _ =>
        request == null ? null : requestCategoryFor(request, appLock: appLock),
    },
    request: request == null || appLock
        ? null
        : pendingRequestFor(
            request,
            raisedAsEvent: switch (event) {
              ApprovalRequested(:final raisedAsEvent) ||
              ClarifyRequested(:final raisedAsEvent) => raisedAsEvent,
              _ => false,
            },
          ),
  );
}

/// The first of [texts] that is not blank, cut at [kRequestBodyLength], or
/// [fallback].
String _requestBody(List<String> texts, String fallback) => _cut(
  texts
      .map((text) => text.trim())
      .firstWhere((text) => text.isNotEmpty, orElse: () => fallback),
  kRequestBodyLength,
);
