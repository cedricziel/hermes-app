import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../api/hermes_api_client.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../chat/hermes_chat_repository.dart';
import '../handoff/handoff_activity.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../notifications/request_answers.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../voice/dictation_settings.dart';
import '../voice/on_device_speech.dart';
import 'watch_complication.dart';
import 'watch_context.dart';
import 'watch_send_journal.dart';
import 'watch_request_handler.dart';
import 'watch_request_actions.dart';

/// The Dart end of the watch relay. The iOS runner receives what the watch
/// sends over WatchConnectivity and forwards each request here as a `request`
/// call; the returned map goes back to the watch as the reply.
class WatchBridge {
  WatchBridge({
    required this._handler,
    this._channel = const MethodChannel(channelName),
    this._events = noopAppEventLogger,
    this._authState = _unknownAuthState,
    this._auth,
    this._appLock,
    this._requestActions,
    this._requestsEnabled = false,
    WatchContextStore? contextStore,
  }) : _contextStore = contextStore ?? WatchContextStore();

  static const channelName = 'app.hermes/watch';

  final WatchRequestHandler _handler;
  final MethodChannel _channel;
  final AppEventLogger _events;
  final String Function() _authState;
  final AuthController? _auth;
  final AppLockController? _appLock;
  final WatchRequestActions? _requestActions;
  final bool _requestsEnabled;
  Future<void> _requestPublication = Future.value();
  bool _requestPublicationSecured = false;
  int _requestPublicationPending = 0;
  int _requestAccessGeneration = 0;
  int _requestEpoch = 0;
  Object? _requestRequestedState;
  int get requestEpoch => _requestEpoch;
  bool get requestsAvailable => _requestPublicationSecured && _requestsWanted;
  bool get _requestsWanted =>
      _requestsEnabled &&
      _appLock?.loaded == true &&
      _appLock?.enabled == false &&
      _publicationSecured &&
      _contextStore.current != null &&
      _auth?.state == HermesConnectionState.ready &&
      _auth?.protectedRequestsAllowed == true;

  void _requestAccessChanged({bool force = false}) {
    if (!_requestsEnabled) return;
    final scope = _contextStore.current;
    final state = (
      _requestsWanted,
      scope?.id,
      scope?.revision,
      _auth?.ownerGeneration,
      _appLock?.loaded,
      _appLock?.enabled,
    );
    if (!force &&
        state == _requestRequestedState &&
        (_requestPublicationSecured || _requestPublicationPending > 0)) {
      return;
    }
    _requestRequestedState = state;
    final generation = ++_requestAccessGeneration;
    _requestPublicationSecured = false;
    if (!_requestsWanted) _requestActions?.clearDetails();
    _requestPublicationPending++;
    _requestPublication = _requestPublication.then((_) async {
      try {
        final wanted = _requestsWanted;
        final owner = _contextStore.current;
        final value = await _channel.invokeMethod<Object?>(
          'publishRequestAccess',
          {'allowed': wanted, if (owner != null) ...owner.fields},
        );
        if (value is! Map ||
            value['epoch'] is! int ||
            value['allowed'] != wanted ||
            (wanted &&
                (value['contextId'] != owner?.id ||
                    value['revision'] != owner?.revision)) ||
            (value['epoch'] as int) < _requestEpoch) {
          return;
        }
        _requestEpoch = value['epoch'] as int;
        _requestPublicationSecured =
            generation == _requestAccessGeneration && wanted == _requestsWanted;
      } on Object {
        _requestPublicationSecured = false;
      } finally {
        _requestPublicationPending--;
      }
    });
  }

  StreamSubscription<void>? _departure;
  Future<void> _publication = Future.value();
  final WatchContextStore _contextStore;
  int? _observedOwnerGeneration;
  int? _publishedOwnerGeneration;
  bool? _publishedUsable;
  bool? _desiredUsable;
  bool? _queuedUsable;
  int _pendingPublications = 0;
  bool _publicationFailed = false;
  bool _departurePending = false;
  String _departureReason = 'signed_out';

  bool get _publicationSecured =>
      !_publicationFailed &&
      !_departurePending &&
      _pendingPublications == 0 &&
      _desiredUsable == _publishedUsable &&
      _observedOwnerGeneration == _publishedOwnerGeneration;
  int _generation = 0;

  void _sessionChanged() {
    _requestAccessChanged();
    final auth = _auth;
    if (auth == null) return;
    final usable =
        auth.state == HermesConnectionState.ready &&
        auth.protectedRequestsAllowed;
    final departed =
        _observedOwnerGeneration != null &&
        _observedOwnerGeneration != auth.ownerGeneration;
    if (!usable && authConnecting(auth) && !auth.sessionExpired && !departed) {
      return;
    }
    _observedOwnerGeneration = auth.ownerGeneration;
    if (_desiredUsable != usable || departed) {
      _desiredUsable = usable;
      if (!usable || departed) {
        _generation++;
        _departurePending = true;
        _departureReason = auth.sessionExpired ? 'expired' : 'signed_out';
        _handler.invalidateSession();
        _handler.complication?.invalidateOwner();
        final retirement = _contextStore.resolve(
          owner: null,
          ungatedServer: null,
          revision: _contextStore.revision,
          departed: true,
        );
        _publication = _publication
            .then((_) async {
              await _handler.settleJournalDeparture();
              await retirement;
            })
            .catchError((Object _) {
              _publicationFailed = true;
            });
      }
    }
    if (_publicationSecured || _queuedUsable == usable) return;
    final reason = auth.sessionExpired ? 'expired' : 'signed_out';
    _queuedUsable = usable;
    _pendingPublications++;
    _publication = _publication.then((_) async {
      try {
        if (usable && _departurePending) {
          if (!await _publishSession(false, _departureReason)) return;
        }
        await _publishSession(usable, reason);
      } finally {
        _pendingPublications--;
        if (_pendingPublications == 0) _queuedUsable = null;
        _requestAccessChanged();
      }
    });
  }

  Future<bool> _publishSession(bool usable, String reason) async {
    try {
      await _handler.settleJournalDeparture();
      final auth = _auth;
      final ownerGeneration = auth?.ownerGeneration;
      if (usable &&
          (auth == null ||
              auth.state != HermesConnectionState.ready ||
              !auth.protectedRequestsAllowed)) {
        return false;
      }
      final context = usable
          ? await _contextStore.resolve(
              owner: auth?.verifiedOwner,
              ungatedServer: auth?.status?.authRequired == false
                  ? auth?.baseUrl
                  : null,
              revision: _contextStore.revision,
            )
          : null;
      if (usable && context == null) {
        throw StateError('Verified context unavailable');
      }
      final response = await _channel.invokeMethod<Object?>(
        'publishSessionState',
        {
          'usable': usable,
          'revision': _contextStore.revision,
          'protocolVersion': 2,
          if (context != null) 'contextId': context.id,
        },
      );
      if (response is! Map ||
          response['revision'] is! int ||
          response['usable'] != usable ||
          (response['revision'] as int) < _contextStore.revision ||
          (usable && response['contextId'] != context?.id)) {
        throw StateError('Invalid session publication acknowledgement');
      }
      await _contextStore.synchronizeRevision(response['revision'] as int);
      _publishedOwnerGeneration = ownerGeneration;
      _publishedUsable = usable;
      _publicationFailed = false;
      if (!usable) {
        _departurePending = false;
        _record('watch.session.invalidated', {
          'reason': reason,
          'result': true,
        });
      }
      return true;
    } on Object {
      _publicationFailed = true;
      if (!usable) {
        _departurePending = true;
        _record('watch.session.invalidated', {
          'reason': reason,
          'result': false,
        });
      }
      return false;
    }
  }

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
    WatchComplicationStatus? complication,
    AppEventLogger events = noopAppEventLogger,
    bool durableSendState = false,
    bool requestsEnabled = false,
  }) {
    if (!Platform.isIOS) {
      return null;
    }
    final contextStore = WatchContextStore();
    complication?.context = () => contextStore.current;
    late WatchBridge bridge;
    final actions = requestsEnabled
        ? WatchRequestActions(
            context: () => contextStore.current,
            allowed: () => bridge.requestsAvailable,
            epoch: () => bridge.requestEpoch,
            transport: () => gatewayTransportFor(auth, events: events),
          )
        : null;
    bridge = WatchBridge(
      contextStore: contextStore,
      events: events,
      auth: auth,
      appLock: appLock,
      requestActions: actions,
      requestsEnabled: requestsEnabled,
      authState: () => auth.state.name,
      handler: handlerFor(
        auth,
        contextStore: contextStore,
        durableSendState: durableSendState,
        requestActions: actions,
        requestsAllowed: () => bridge.requestsAvailable,
        requestEpoch: actions == null ? null : () => bridge.requestEpoch,
        announce: announcer(notifications, settings),
        appLock: () => appLockHidesRequests(appLock),
        transcribeOnDevice: onDeviceTranscriber(speech, dictation),
        complication: complication,
        events: events,
      ),
    );
    return bridge;
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
  /// with the chat on the phone, and a permission the system now denies posts
  /// nothing. A
  /// notification that cannot be shown is dropped.
  static Future<bool> Function(AttentionNotification) announcer(
    NotificationService? service,
    NotificationSettings? settings,
  ) => (notification) async {
    if (service == null) return false;
    try {
      if (settings != null) {
        if (!settings.loaded) await settings.load();
        if (!settings.enabled) return false;
      }
      // Asked each time: the user may have changed it in system settings
      // since the app last recorded an answer.
      if (await service.allowed() == false) return false;
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
    WatchComplicationStatus? complication,
    AppEventLogger events = noopAppEventLogger,
    Duration readyTimeout = const Duration(seconds: 20),
    WatchContextStore? contextStore,
    bool durableSendState = false,
    WatchRequestActions? requestActions,
    bool Function()? requestsAllowed,
    int Function()? requestEpoch,
  }) {
    // The client exists from the first connect, before anyone has signed in.
    HermesApiClient? readyApi() =>
        auth.state == HermesConnectionState.ready &&
            auth.protectedRequestsAllowed
        ? auth.api
        : null;

    final contexts = contextStore ?? WatchContextStore();
    return WatchRequestHandler(
      journal: durableSendState ? WatchSendJournal(events: events) : null,
      onRequestEvent: requestActions?.observe,
      onRequestsInvalidated: requestActions?.clear,
      onRequestStreamClosed: requestActions == null
          ? null
          : (_, _, _, owner) => requestActions.closeOwner(owner),
      requestsAllowed: requestsAllowed ?? _off,
      requestEligible: requestActions?.eligible,
      requestAction: requestActions?.handle,
      requestEpoch: requestEpoch,
      context: () => contexts.current,
      prepareContext: () async {
        await contexts.resolve(
          owner: auth.verifiedOwner,
          ungatedServer: auth.status?.authRequired == false
              ? auth.baseUrl
              : null,
          revision: contexts.revision,
        );
      },
      announce: announce,
      appLock: appLock,
      transcribeOnDevice: transcribeOnDevice,
      complication: complication,
      connecting: () => authConnecting(auth),
      ready: () => authSettled(auth, timeout: readyTimeout),
      repository: () {
        final api = readyApi();
        return api == null ? null : HermesChatRepository(api.raw);
      },
      transport: () => gatewayTransportFor(auth, events: events),
      serverUrl: () {
        final url = auth.baseUrl;
        return url == null ? null : HandoffActivity.server(url);
      },
      activeProfile: () async {
        final api = readyApi();
        if (api == null) {
          return null;
        }
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
    'session' ||
    'threads' ||
    'messages' ||
    'send' ||
    'forgetSend' ||
    'request_details' ||
    'request_answer' ||
    'transcribe' => op as String,
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

  void start() {
    _channel.setMethodCallHandler(_onCall);
    _auth?.addListener(_sessionChanged);
    _appLock?.addListener(_requestAccessChanged);
    _departure = _auth?.signedOut.listen((_) => _sessionChanged());
    _sessionChanged();
  }

  void dispose() {
    _auth?.removeListener(_sessionChanged);
    _appLock?.removeListener(_requestAccessChanged);
    _requestActions?.clear();
    unawaited(_departure?.cancel());
    _channel.setMethodCallHandler(null);
  }

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
    _sessionChanged();
    await _publication;
    _requestAccessChanged(
      force:
          request['op'] == 'session' && request['requestAccessRefresh'] == true,
    );
    await _requestPublication;
    final generation = _generation;
    var reply = _auth != null && _desiredUsable == true && !_publicationSecured
        ? <String, Object?>{'ok': false, 'error': 'unavailable'}
        : await _handler.handle(request);
    _sessionChanged();
    await _publication;
    if (generation != _generation) reply = {'ok': false, 'error': 'signed_out'};
    if ((operation == 'request_details' || operation == 'request_answer') &&
        !requestsAvailable) {
      reply = {'ok': false, 'error': 'locked'};
    }
    if (_auth != null && reply['ok'] == true && !_publicationSecured) {
      reply = {'ok': false, 'error': 'unavailable'};
    }
    // Only telemetry reads it; the watch gets the text alone.
    if (reply['error'] == 'context_changed') {
      _record('watch.context.rejected', {
        'operation': operation,
        'reason': 'scope_mismatch',
      });
    }
    final engine = reply['engine'];
    timer.stop();
    final result = reply['ok'] == true
        ? 'ok'
        : switch (reply['error']) {
            'signed_out' => 'signed_out',
            'unavailable' => 'unavailable',
            'bad_request' => 'bad_request',
            'context_changed' => 'context_changed',
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
