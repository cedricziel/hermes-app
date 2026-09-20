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

  /// When set, [requestPermission] waits for it and answers what it completes
  /// with, instead of answering [permission] at once.
  Completer<NotificationPermission>? permissionGate;

  /// The thread whose notification started the app, if any.
  String? launchThread;

  /// The profile of the notification that started the app, if any.
  String? launchProfile;

  final shown = <AttentionNotification>[];
  var permissionRequests = 0;
  final _taps = StreamController<NotificationTarget>.broadcast();

  void tap(String threadId, {String? profile}) =>
      _taps.add(NotificationTarget(threadId: threadId, profile: profile));

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  @override
  Future<NotificationPermission> requestPermission() async {
    permissionRequests++;
    return permissionGate?.future ?? permission;
  }

  @override
  Future<void> show(AttentionNotification notification) async =>
      shown.add(notification);

  @override
  Future<NotificationTarget?> launchTarget() async => launchThread == null
      ? null
      : NotificationTarget(threadId: launchThread!, profile: launchProfile);

  @override
  Future<void> dispose() => _taps.close();
}
