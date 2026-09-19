import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'attention_policy.dart';
import 'notification_service.dart';

const _channelId = 'agent_activity';
const _channelName = 'Agent activity';

/// The thread a tapped notification was posted for.
String? threadIdFromResponse(NotificationResponse response) {
  final payload = response.payload;
  return payload == null || payload.isEmpty ? null : payload;
}

/// One id per thread, so a new notification replaces the earlier one.
int notificationIdFor(String threadId) => threadId.hashCode & 0x7fffffff;

/// [NotificationService] on `flutter_local_notifications`. On platforms other
/// than macOS, iOS and Android it does nothing.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _initialized;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _initialize() => _initialized ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: (response) {
      final threadId = threadIdFromResponse(response);
      if (threadId != null) _taps.add(threadId);
    },
  );

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _initialize();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (mac != null) {
        return await mac.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> show(AttentionNotification notification) async {
    if (!_supported) return;
    try {
      await _initialize();
      await _plugin.show(
        id: notificationIdFor(notification.threadId),
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Replies and requests from Hermes',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: notification.threadId,
      );
    } on Object {
      return;
    }
  }

  @override
  Future<String?> launchThreadId() async {
    if (!_supported) return null;
    try {
      await _initialize();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final response = details.notificationResponse;
      return response == null ? null : threadIdFromResponse(response);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() => _taps.close();
}
