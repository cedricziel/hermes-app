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

/// Posts local notifications and reports when the user taps one.
abstract interface class NotificationService {
  /// Asks the system for permission to post. [NotificationPermission.denied]
  /// only when the system answered no; anything that stops the question from
  /// being answered is [NotificationPermission.unavailable].
  Future<NotificationPermission> requestPermission();

  /// Posts [notification], replacing an earlier one for the same thread.
  /// Never throws: a notification that cannot be shown is dropped.
  Future<void> show(AttentionNotification notification);

  /// The thread ids of notifications the user tapped while the app ran.
  Stream<String> get taps;

  /// The thread of the notification whose tap started the app, if one did.
  Future<String?> launchThreadId();

  Future<void> dispose();
}
