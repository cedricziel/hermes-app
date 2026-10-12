import 'attention_policy.dart';
import 'notification_service.dart';

enum NotificationPostStatus { accepted, failed, denied, unsupported }

class NotificationPostResult {
  const NotificationPostResult(this.status, {this.errorType});

  final NotificationPostStatus status;
  final String? errorType;
}

/// Reports OS acceptance of a posting attempt, never user delivery.
abstract interface class NotificationPoster {
  Future<NotificationPostResult> post(AttentionNotification notification);
}

extension NotificationPosting on NotificationService {
  /// Legacy services without posting results cannot establish acceptance.
  Future<NotificationPostResult> post(
    AttentionNotification notification,
  ) async {
    if (this is! NotificationPoster) {
      return const NotificationPostResult(NotificationPostStatus.unsupported);
    }
    try {
      return await (this as NotificationPoster).post(notification);
    } on Object catch (error) {
      return NotificationPostResult(
        NotificationPostStatus.failed,
        errorType: error.runtimeType.toString(),
      );
    }
  }
}
