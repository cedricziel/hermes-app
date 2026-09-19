import 'dart:async';

import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';

/// A [NotificationService] the test drives by hand: every notification is
/// recorded, and a tap is simulated with [tap].
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.permission = NotificationPermission.granted,
    this.launchThread,
  });

  /// What [requestPermission] answers.
  NotificationPermission permission;

  /// The thread whose notification started the app, if any.
  String? launchThread;

  final shown = <AttentionNotification>[];
  var permissionRequests = 0;
  final _taps = StreamController<String>.broadcast();

  void tap(String threadId) => _taps.add(threadId);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<NotificationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> show(AttentionNotification notification) async =>
      shown.add(notification);

  @override
  Future<String?> launchThreadId() async => launchThread;

  @override
  Future<void> dispose() => _taps.close();
}
