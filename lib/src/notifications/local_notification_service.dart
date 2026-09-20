import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'attention_policy.dart';
import 'notification_service.dart';

const _channelId = 'agent_activity';
const _channelName = 'Agent activity';

/// The payload a notification for [target] carries.
String encodeTarget(NotificationTarget target) => jsonEncode({
  if (target.isJob) 'j': target.jobId else 't': target.threadId,
  'p': ?target.profile,
});

/// What a tapped notification was posted for. A payload that is not our JSON
/// is a plain thread id, as an earlier build posted it.
NotificationTarget? targetFromResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      final profile = decoded['p'] is String ? decoded['p'] as String : null;
      if (decoded['j'] is String) {
        return NotificationTarget.job(
          jobId: decoded['j'] as String,
          profile: profile,
        );
      }
      if (decoded['t'] is String) {
        return NotificationTarget(
          threadId: decoded['t'] as String,
          profile: profile,
        );
      }
    }
  } on FormatException {
    // Not JSON: fall through to a plain thread id.
  }
  return NotificationTarget(threadId: payload);
}

/// One id per chat, so a new notification replaces the earlier one. FNV-1a
/// rather than `hashCode`, which Dart does not keep stable between releases.
/// Masked to 31 bits: non-negative, and a signed 32-bit int as Android needs.
/// Without a [profile] the id is that of the bare [threadId].
int notificationIdFor(String threadId, {String? profile}) {
  var hash = 0x811c9dc5;
  final key = profile == null ? threadId : '$profile\u0000$threadId';
  for (final unit in key.codeUnits) {
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
  final _taps = StreamController<NotificationTarget>.broadcast();
  Future<void>? _initialized;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _initialize() => _initialized ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: _darwinSettings,
          macOS: _darwinSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          final target = targetFromResponse(response);
          if (target != null) _taps.add(target);
        },
      )
      .then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _initialized = null;
          Error.throwWithStackTrace(error, stack);
        },
      );

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  static Future<NotificationPermission> _askDarwin(
    Future<bool?> Function({bool alert, bool badge, bool sound}) request,
  ) async => _answer(await request(alert: true, badge: true, sound: true));

  static NotificationPermission _answer(bool? granted) => switch (granted) {
    true => NotificationPermission.granted,
    false => NotificationPermission.denied,
    null => NotificationPermission.unavailable,
  };

  @override
  Future<NotificationPermission> requestPermission() async {
    if (!_supported) return NotificationPermission.unavailable;
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
      return _answer(await android?.requestNotificationsPermission());
    } on Object {
      return NotificationPermission.unavailable;
    }
  }

  @override
  Future<void> show(AttentionNotification notification) async {
    if (!_supported) return;
    try {
      await _initialize();
      await _plugin.show(
        id: notificationIdFor(
          notification.threadId,
          profile: notification.profile,
        ),
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
        payload: encodeTarget(
          notification.jobId != null
              ? NotificationTarget.job(
                  jobId: notification.jobId!,
                  profile: notification.profile,
                )
              : NotificationTarget(
                  threadId: notification.threadId,
                  profile: notification.profile,
                ),
        ),
      );
    } on Object {
      return;
    }
  }

  @override
  Future<NotificationTarget?> launchTarget() async {
    if (!_supported) return null;
    try {
      await _initialize();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final response = details.notificationResponse;
      return response == null ? null : targetFromResponse(response);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() => _taps.close();
}
