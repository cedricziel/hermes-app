import 'attention_policy.dart';

/// Posts local notifications and reports when the user taps one.
abstract interface class NotificationService {
  /// Asks the system for permission to post. Returns false when it was
  /// denied, or when this platform cannot post notifications.
  Future<bool> requestPermission();

  /// Posts [notification], replacing an earlier one for the same thread.
  /// Never throws: a notification that cannot be shown is dropped.
  Future<void> show(AttentionNotification notification);

  /// The thread ids of notifications the user tapped while the app ran.
  Stream<String> get taps;

  /// The thread of the notification whose tap started the app, if one did.
  Future<String?> launchThreadId();

  Future<void> dispose();
}
