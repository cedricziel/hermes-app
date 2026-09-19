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

/// One id per thread, so a new notification replaces the earlier one. FNV-1a
/// rather than `hashCode`, which Dart does not keep stable between releases.
/// Masked to 31 bits: non-negative, and a signed 32-bit int as Android needs.
int notificationIdFor(String threadId) {
  var hash = 0x811c9dc5;
  for (final unit in threadId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

const _darwinSettings = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

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
      iOS: _darwinSettings,
      macOS: _darwinSettings,
    ),
    onDidReceiveNotificationResponse: (response) {
      final threadId = threadIdFromResponse(response);
      if (threadId != null) _taps.add(threadId);
    },
  );

  @override
  Stream<String> get taps => _taps.stream;

  static Future<bool> _askDarwin(
    Future<bool?> Function({bool alert, bool badge, bool sound}) request,
  ) async => await request(alert: true, badge: true, sound: true) ?? false;

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _initialize();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) return await _askDarwin(ios.requestPermissions);
      if (mac != null) return await _askDarwin(mac.requestPermissions);
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
