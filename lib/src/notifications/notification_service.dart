import '../chat/chat_transport.dart';
import 'attention_policy.dart';
import 'request_notifications.dart';

/// What the system said when asked for permission to post notifications.
enum NotificationPermission {
  granted,

  /// The system answered no.
  denied,

  /// This platform cannot post notifications, the plugin failed, or the system
  /// gave no answer.
  unavailable,
}

/// What a notification was posted for: a chat, or a scheduled task. A thread
/// id is only unique within a Hermes profile, and so is a job id, so the
/// profile travels with either; it is null for a notification that carries
/// none.
class NotificationTarget {
  const NotificationTarget({required this.threadId, this.profile})
    : jobId = null;

  /// A scheduled task. It has no chat, so [threadId] is empty.
  const NotificationTarget.job({required String this.jobId, this.profile})
    : threadId = '';

  final String threadId;
  final String? jobId;
  final String? profile;

  bool get isJob => jobId != null;
}

/// An answer the user gave with a request notification's button.
class NotificationAnswer {
  const NotificationAnswer({
    required this.target,
    required this.title,
    required this.request,
    required this.answer,
  });

  /// The chat the request was raised in.
  final NotificationTarget target;

  /// The chat's title, for a follow-up notification.
  final String title;
  final PendingRequest request;
  final OpenRequestAnswer answer;
}

/// Posts local notifications and reports when the user taps one.
abstract interface class NotificationService {
  /// Asks the system for permission to post. [NotificationPermission.denied]
  /// only when the system answered no; anything that stops the question from
  /// being answered is [NotificationPermission.unavailable].
  Future<NotificationPermission> requestPermission();

  /// Posts [notification], replacing an earlier one for the same thread.
  /// Never throws: a notification that cannot be shown is dropped.
  Future<void> show(AttentionNotification notification);

  /// The chats of notifications the user tapped while the app ran.
  Stream<NotificationTarget> get taps;

  /// Answers the user gave with a request notification's buttons that reach
  /// this isolate: on macOS all of them, including the one that started the
  /// app. On iOS they go to a background isolate instead.
  Stream<NotificationAnswer> get answers;

  /// Removes the delivered notifications whose buttons answer a request, as
  /// when App Lock goes on.
  Future<void> withdrawAnswerable();

  /// Whether the system lets the app post notifications now, without asking;
  /// null where it cannot tell.
  Future<bool?> allowed();

  /// The chat of the notification whose tap started the app, if one did.
  Future<NotificationTarget?> launchTarget();

  Future<void> dispose();
}
