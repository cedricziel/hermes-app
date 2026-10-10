import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../api/hermes_api_client.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../chat/hermes_chat_repository.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../notifications/request_answers.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../voice/dictation_settings.dart';
import '../voice/on_device_speech.dart';
import 'watch_request_handler.dart';

/// The Dart end of the watch relay. The iOS runner receives what the watch
/// sends over WatchConnectivity and forwards each request here as a `request`
/// call; the returned map goes back to the watch as the reply.
class WatchBridge {
  WatchBridge({
    required this._handler,
    this._channel = const MethodChannel(channelName),
    this._events = noopAppEventLogger,
    this._authState = _unknownAuthState,
  });

  static const channelName = 'app.hermes/watch';

  final WatchRequestHandler _handler;
  final MethodChannel _channel;
  final AppEventLogger _events;
  final String Function() _authState;

  /// A bridge that serves the watch from whoever is signed in right now, or
  /// null off iOS, where there is no watch to relay for.
  ///
  /// A turn sent from the watch is announced through [notifications], under
  /// the user's [settings]. A voice message is transcribed by [speech] while
  /// [dictation] picks the device's recognizer. While [appLock] is on, a
  /// request is announced without its text or buttons.
  static WatchBridge? forAuth(
    AuthController auth, {
    NotificationService? notifications,
    NotificationSettings? settings,
    AppLockController? appLock,
    required OnDeviceSpeech speech,
    required DictationSettings dictation,
    AppEventLogger events = noopAppEventLogger,
  }) {
    if (!Platform.isIOS) return null;
    return WatchBridge(
      events: events,
      authState: () => auth.state.name,
      handler: handlerFor(
        auth,
        announce: announcer(notifications, settings),
        appLock: () => appLockHidesRequests(appLock),
        transcribeOnDevice: onDeviceTranscriber(speech, dictation),
        events: events,
      ),
    );
  }

  /// Transcribes a voice message with the phone's recognizer in its language
  /// while the user's dictation engine is the device. Answers null, so the
  /// server transcribes it, for the Hermes engine; the handler does the same
  /// when recognition fails, such as for a language without a model.
  static Future<String?> Function(Uint8List) onDeviceTranscriber(
    OnDeviceSpeech speech,
    DictationSettings dictation,
  ) => (audio) async {
    // A watch request can wake the app before the saved engine was read.
    if (!dictation.loaded) await dictation.load();
    if (dictation.engine != DictationEngine.device) return null;
    return speech.transcribeFile(audio, locale: OnDeviceSpeech.deviceLocale());
  };

  /// Posts what the relay announces, while notifications are on, and answers
  /// whether it was posted. A watch request can wake the app before the saved
  /// setting was read, so it is read first. It never asks for permission:
  /// the prompt would appear on a phone the user is not holding, so it stays
  /// with the chat on the phone, and a denied permission posts nothing. A
  /// notification that cannot be shown is dropped.
  static Future<bool> Function(AttentionNotification) announcer(
    NotificationService? service,
    NotificationSettings? settings,
  ) => (notification) async {
    if (service == null) return false;
    try {
      if (settings != null) {
        if (!settings.loaded) await settings.load();
        if (!settings.enabled || settings.permissionDenied) return false;
      }
      await service.show(notification);
      return true;
    } on Object {
      return false;
    }
  };

  static WatchRequestHandler handlerFor(
    AuthController auth, {
    Future<bool> Function(AttentionNotification) announce = _ignore,
    bool Function() appLock = _off,
    Future<String?> Function(Uint8List)? transcribeOnDevice,
    AppEventLogger events = noopAppEventLogger,
    Duration readyTimeout = const Duration(seconds: 20),
  }) {
    // The client exists from the first connect, before anyone has signed in.
    HermesApiClient? readyApi() =>
        auth.state == HermesConnectionState.ready ? auth.api : null;

    return WatchRequestHandler(
      announce: announce,
      appLock: appLock,
      transcribeOnDevice: transcribeOnDevice,
      connecting: () => authConnecting(auth),
      ready: () => authSettled(auth, timeout: readyTimeout),
      repository: () {
        final api = readyApi();
        return api == null ? null : HermesChatRepository(api.raw);
      },
      transport: () => gatewayTransportFor(auth, events: events),
      activeProfile: () async {
        final api = readyApi();
        if (api == null) return null;
        try {
          return (await HermesProfilesRepository(api.raw).loadActive()).active;
        } on Object {
          return null;
        }
      },
    );
  }

  static Future<bool> _ignore(AttentionNotification _) async => false;

  static bool _off() => false;

  static String _unknownAuthState() => 'unknown';

  void _record(String name, Map<String, Object> attributes) {
    try {
      _events(name, attributes);
    } on Object {
      // Telemetry failure must not prevent a watch reply.
    }
  }

  static String _operation(Object? op) => switch (op) {
    'threads' || 'messages' || 'send' || 'transcribe' => op as String,
    _ => 'unknown',
  };

  static final _failureReason = RegExp(
    r'^(not_activated|not_reachable|delivery:-?\d{1,6})$',
  );

  /// The requests the watch could not get to the phone since it last could,
  /// which it hands over with the next one that arrives: what it asked for,
  /// why it failed and how long ago. Never anything the user wrote.
  void _recordDeliveryFailures(Object? diagnostics) {
    if (diagnostics is! List) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final entry in diagnostics) {
      if (entry is! Map) continue;
      final reason = entry['reason'];
      final at = entry['at'];
      _record('watch.delivery.failed', {
        'watch.operation': _operation(entry['op']),
        'watch.failure': reason is String && _failureReason.hasMatch(reason)
            ? reason
            : 'unknown',
        if (at is num) 'watch.failure_age_s': now - at.toInt(),
      });
    }
  }

  void start() => _channel.setMethodCallHandler(_onCall);

  void dispose() => _channel.setMethodCallHandler(null);

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'request') throw MissingPluginException();
    final arguments = call.arguments;
    final request = arguments is Map ? arguments : const {};
    _recordDeliveryFailures(request['diagnostics']);
    final operation = _operation(request['op']);
    final timer = Stopwatch()..start();
    _record('watch.request.started', {
      'watch.operation': operation,
      'auth.state': _authState(),
    });
    final reply = await _handler.handle(request);
    // Only telemetry reads it; the watch gets the text alone.
    final engine = reply['engine'];
    timer.stop();
    final result = reply['ok'] == true
        ? 'ok'
        : switch (reply['error']) {
            'signed_out' => 'signed_out',
            'unavailable' => 'unavailable',
            'bad_request' => 'bad_request',
            _ => 'failed',
          };
    _record('watch.request.completed', {
      'watch.operation': operation,
      'auth.state': _authState(),
      'watch.result': result,
      'watch.duration_ms': timer.elapsedMilliseconds,
      if (engine is String) 'watch.transcribe_engine': engine,
    });
    return {...reply}..remove('engine');
  }
}
