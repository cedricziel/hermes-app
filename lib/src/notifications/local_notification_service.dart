import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'attention_policy.dart';
import 'notification_service.dart';
import 'request_answers.dart';
import 'request_notifications.dart';

const _channelId = 'agent_activity';
const _channelName = 'Agent activity';

/// The payload a notification for [target] carries.
String encodeTarget(NotificationTarget target) => jsonEncode({
  if (target.isJob) 'j': target.jobId else 't': target.threadId,
  'p': ?target.profile,
});

/// The payload of [notification]: its chat or job, and for a request that
/// can be answered from the notification the chat's title and what
/// answering needs.
String notificationPayload(AttentionNotification notification) {
  final request = notification.request;
  return jsonEncode({
    if (notification.jobId case final job?)
      'j': job
    else
      't': notification.threadId,
    'p': ?notification.profile,
    if (request != null) 'n': notification.title,
    if (request != null) 'r': request.toJson(),
  });
}

/// What a tapped notification was posted for. A payload that is not our JSON
/// is a plain thread id, as an earlier build posted it.
NotificationTarget? targetFromResponse(NotificationResponse response) =>
    targetFromPayload(response.payload);

NotificationTarget? targetFromPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  final decoded = _decode(payload);
  if (decoded == null) return NotificationTarget(threadId: payload);
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
  return NotificationTarget(threadId: payload);
}

/// The answer the user gave with [actionId] (and, for Reply, the typed
/// [input]) on the request notification whose payload is [payload]. Null for
/// a tap, Other…, Open, or a notification that is not about a request.
NotificationAnswer? answerFromAction(
  String? payload,
  String? actionId,
  String? input,
) {
  if (payload == null || actionId == null || actionId.isEmpty) return null;
  final decoded = _decode(payload);
  final target = targetFromPayload(payload);
  final request = PendingRequest.fromJson(decoded?['r']);
  if (target == null || target.isJob || request == null) return null;
  final answer = answerFor(request, actionId, input);
  if (answer == null) return null;
  final title = decoded?['n'];
  return NotificationAnswer(
    target: target,
    title: title is String && title.isNotEmpty ? title : 'Hermes',
    request: request,
    answer: answer,
  );
}

NotificationAnswer? answerFromResponse(NotificationResponse response) =>
    answerFromAction(response.payload, response.actionId, response.input);

Map<Object?, Object?>? _decode(String payload) {
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// One id per chat, so a new notification replaces the earlier one. FNV-1a
/// rather than `hashCode`, which Dart does not keep stable between releases.
/// Masked to 31 bits: non-negative, and a signed 32-bit int as Android needs.
/// Without a [profile] the id is that of the bare [threadId].
int notificationIdFor(String threadId, {String? profile}) =>
    fnv1a(profile == null ? threadId : '$profile\u0000$threadId') & 0x7fffffff;

/// Registers request categories with the system, each with its hidden-preview
/// placeholder, which the plugin cannot set.
typedef CategoryRegistrar = Future<void> Function(
  List<RequestCategory> categories,
);

const _categoryChannel = MethodChannel('hermes_app/notification_categories');

/// Hands [categories] to the Runner, which merges them into the registered
/// set with their placeholders. Does nothing where no Runner answers.
///
/// Calls go one at a time: each one reads the registered set and writes it
/// back, so two at once could drop each other's categories.
Future<void> registerCategoriesNatively(List<RequestCategory> categories) =>
    _categoryCall('register', {
      'categories': [for (final category in categories) category.toChannel()],
    });

/// Drops the question categories the Runner keeps across launches, whose
/// buttons carry the choices the agent offered.
Future<void> forgetQuestionCategories() => _categoryCall('forget');

Future<void> _categoryCalls = Future.value();

Future<void> _categoryCall(String method, [Object? arguments]) {
  final call = _categoryCalls.then((_) async {
    try {
      await _categoryChannel.invokeMethod<void>(method, arguments);
    } on Object {
      // Without it the buttons still work; only the placeholder is missing.
    }
  });
  return _categoryCalls = call;
}

/// [NotificationService] on `flutter_local_notifications`. On platforms other
/// than macOS, iOS and Android it does nothing.
///
/// A background service, as the iOS background isolate makes, registers no
/// categories: that would drop the placeholders the main app set.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    CategoryRegistrar registerCategories = registerCategoriesNatively,
    this._background = false,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _register = registerCategories;

  final FlutterLocalNotificationsPlugin _plugin;
  final CategoryRegistrar _register;
  final bool _background;
  final _taps = StreamController<NotificationTarget>.broadcast();
  final _answers = StreamController<NotificationAnswer>.broadcast();
  Future<void>? _initialized;
  var _launchAnswered = false;

  static bool get _supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  static bool get _darwin => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  Future<void> _initialize() => _initialized ??= _start().then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {
      _initialized = null;
      Error.throwWithStackTrace(error, stack);
    },
  );

  Future<void> _start() async {
    final categories = _background
        ? const <RequestCategory>[]
        : staticRequestCategories();
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        for (final category in categories) category.toDarwin(),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse:
          _background || defaultTargetPlatform != TargetPlatform.iOS
          ? null
          : answerRequestInBackground,
    );
    if (_darwin && categories.isNotEmpty) await _register(categories);
  }

  void _onResponse(NotificationResponse response) {
    final answer = answerFromResponse(response);
    if (answer != null) {
      _answers.add(answer);
      return;
    }
    if (!_opensApp(response)) return;
    final target = targetFromResponse(response);
    if (target != null) _taps.add(target);
  }

  /// A tap on the notification, or a button that opens the app.
  static bool _opensApp(NotificationResponse response) {
    final action = response.actionId;
    return action == null || action.isEmpty || action == kOpenAction;
  }

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  @override
  Stream<NotificationAnswer> get answers => _answers.stream;

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
      // Android has no placeholder that hides the text on a locked screen.
      final category = _darwin ? notification.category : null;
      if (category != null && category.isDynamic) await _register([category]);
      final darwin = DarwinNotificationDetails(
        categoryIdentifier: category?.id,
      );
      await _plugin.show(
        id: notificationIdFor(
          notification.threadId,
          profile: notification.profile,
        ),
        title: notification.title,
        body: _darwin
            ? notification.body
            : notification.category?.placeholder ?? notification.body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Replies and requests from Hermes',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: darwin,
          macOS: darwin,
        ),
        payload: notificationPayload(notification),
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
      if (response == null) return null;
      if (!_opensApp(response)) {
        // macOS starts the app for a button too; it is answered once, not
        // opened, however many screens ask for the launch target.
        final answer = _launchAnswered ? null : answerFromResponse(response);
        _launchAnswered = true;
        if (answer != null) scheduleMicrotask(() => _answers.add(answer));
        return null;
      }
      return targetFromResponse(response);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _taps.close();
    await _answers.close();
  }
}
