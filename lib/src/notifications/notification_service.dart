import 'attention_policy.dart';

/// What the system said when asked for permission to post notifications.
enum NotificationPermission {
  granted,

  /// The system answered no.
  denied,

  /// This platform cannot post notifications, the plugin failed, or the system
  /// gave no answer.
  unavailable,
}

/// The chat a notification was posted for. A thread id is only unique within
/// a Hermes profile, so the profile travels with it; it is null for a
/// notification that carries none.
class NotificationTarget {
  const NotificationTarget({required this.threadId, this.profile});

  final String threadId;
  final String? profile;
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

  /// The chat of the notification whose tap started the app, if one did.
  Future<NotificationTarget?> launchTarget();

  Future<void> dispose();
}
