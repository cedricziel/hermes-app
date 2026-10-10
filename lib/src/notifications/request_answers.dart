/// Sends the answer the user gave with a request notification's button, from
/// whichever isolate received it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_transport.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../telemetry/breadcrumbs.dart';
import 'attention_notifier.dart';
import 'attention_policy.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';

/// The name the running app's answer port is registered under, so the iOS
/// background isolate can hand it an answer.
const kRequestAnswersPort = 'hermes_app.request_answers';

/// How long the answer to one button may take, from the moment iOS hands it
/// over, in either isolate: inside the 30 seconds or so of background time,
/// so that a failure can still be told.
const kAnswerBudget = Duration(seconds: 25);

/// How an answer went; `locked` when App Lock kept it from being sent.
enum AnswerOutcome { ok, expired, failed, signedOut, locked }

/// A fresh gateway transport on [auth]'s connection, or null while nobody is
/// signed in.
ChatTransport? gatewayTransportFor(
  AuthController auth, {
  AppEventLogger events = noopAppEventLogger,
}) {
  final api = auth.state == HermesConnectionState.ready ? auth.api : null;
  final baseUrl = auth.baseUrl;
  if (api == null || baseUrl == null) return null;
  return HermesGatewayTransport(
    connect: hermesGatewayConnect(
      baseUrl: baseUrl,
      authRequired: auth.status?.authRequired ?? true,
      api: api,
    ),
    events: events,
  );
}

/// Whether [auth] is still getting ready to serve, rather than signed out:
/// restoring its session, reaching the server, or mid sign-in.
bool authConnecting(AuthController auth) => switch (auth.state) {
  HermesConnectionState.initializing ||
  HermesConnectionState.connecting ||
  HermesConnectionState.signingIn ||
  HermesConnectionState.connectionError => true,
  _ => false,
};

/// Completes once [auth] is no longer restoring its session, reaching the
/// server or signing in, or after [timeout]. An action or a watch request
/// often wakes the app, which then needs a moment to restore its session.
Future<void> authSettled(
  AuthController auth, {
  Duration timeout = const Duration(seconds: 20),
}) {
  final settled = Completer<void>();
  void check() {
    if (!authConnecting(auth) && !settled.isCompleted) settled.complete();
  }

  auth.addListener(check);
  check();
  return settled.future
      .timeout(timeout, onTimeout: () {})
      .whenComplete(() => auth.removeListener(check));
}

/// Sends one answer on a transport of its own and, when it does not get
/// through, posts a notification that sends the user to the chat.
class RequestAnswerSender {
  RequestAnswerSender({
    required this.transport,
    this.notifications,
    this.ready = _readyNow,
    this.events = _noEvents,
    this.breadcrumbs = Breadcrumbs.none,
    this.timeout = const Duration(seconds: 20),
    this.followUpMargin = const Duration(seconds: 3),
    this.locked = _unlocked,
  });

  /// A new transport for each answer; null while nobody is signed in.
  final ChatTransport? Function() transport;
  final NotificationService? notifications;

  /// Completes once the app has restored its session, or gave up on it.
  final Future<void> Function() ready;
  final AppEventLogger Function() events;
  final Breadcrumbs breadcrumbs;
  final Duration timeout;

  /// How long before a deadline the answer is given up on, so the follow-up
  /// still gets posted in time.
  final Duration followUpMargin;

  /// Whether App Lock is on: nothing is answered past it.
  final Future<bool> Function() locked;

  static Future<bool> _unlocked() async => false;

  static Future<void> _readyNow() async {}

  static AppEventLogger _noEvents() => noopAppEventLogger;

  /// Sends [answer]; with a [deadline], gives up on it in time to post the
  /// follow-up before then.
  Future<AnswerOutcome> send(
    NotificationAnswer answer, {
    String route = 'main',
    DateTime? deadline,
  }) async {
    if (await _lockedNow()) {
      await _tell(notifications, answer, kOpenToAnswerBody);
      return AnswerOutcome.locked;
    }
    // Past it nothing may go out any more: the follow-up says it did not.
    final cutoff = deadline?.subtract(followUpMargin);
    final left = cutoff?.difference(DateTime.now());
    final outcome = left == null
        ? await _send(answer, cutoff)
        : await _send(answer, cutoff).timeout(
            left.isNegative ? Duration.zero : left,
            onTimeout: () => AnswerOutcome.failed,
          );
    final kind = answer.request.kind.name;
    try {
      events()('notification.answer', {
        'kind': kind,
        'outcome': outcome.name,
        'route': route,
      });
      breadcrumbs('notification.answered', {
        'kind': kind,
        'outcome': outcome.name,
      });
    } on Object {
      // Telemetry must not keep the answer's outcome from the user.
    }
    if (outcome != AnswerOutcome.ok) await tellFailed(notifications, answer);
    return outcome;
  }

  Future<AnswerOutcome> _send(
    NotificationAnswer answer,
    DateTime? cutoff,
  ) async {
    try {
      await ready();
      final chat = transport();
      if (chat == null) return AnswerOutcome.signedOut;
      try {
        final accepted = await chat
            .answerOpenRequest(
              answer.request.requestId,
              answer.answer,
              threadId: answer.target.threadId,
              profile: answer.target.profile,
              raisedAsEvent: answer.request.raisedAsEvent,
              deadline: cutoff,
            )
            .timeout(timeout);
        return accepted ? AnswerOutcome.ok : AnswerOutcome.expired;
      } finally {
        unawaited(chat.close().catchError((Object _) {}));
      }
    } on Object {
      return AnswerOutcome.failed;
    }
  }

  Future<bool> _lockedNow() async {
    try {
      return await locked();
    } on Object {
      return true;
    }
  }

  /// Posts the follow-up that sends the user to [answer]'s chat.
  static Future<void> tellFailed(
    NotificationService? notifications,
    NotificationAnswer answer,
  ) => _tell(notifications, answer, kAnswerFailedBody);

  static Future<void> _tell(
    NotificationService? notifications,
    NotificationAnswer answer,
    String body,
  ) async {
    try {
      await notifications?.show(
        AttentionNotification(
          threadId: answer.target.threadId,
          profile: answer.target.profile,
          title: answer.title,
          body: body,
        ),
      );
    } on Object {
      // Dropped, like any notification that cannot be shown.
    }
  }
}

/// The running app's end of the answer path: sends what its own
/// notification service reports (macOS) and what the iOS background isolate
/// hands it through [kRequestAnswersPort].
class RequestAnswers {
  RequestAnswers(
    this._sender, {
    this._service,
    this._signedOut,
    this._forgetCategories = forgetQuestionCategories,
    this._appLock,
  });

  /// Answers on a fresh connection of whoever is signed in on [auth].
  factory RequestAnswers.forAuth(
    AuthController auth, {
    required NotificationService service,
    AppLockController? appLock,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) => RequestAnswers(
    RequestAnswerSender(
      transport: () =>
          gatewayTransportFor(auth, events: auth.connectionTelemetry.events),
      notifications: service,
      ready: () => authSettled(auth),
      events: () => auth.connectionTelemetry.events,
      breadcrumbs: breadcrumbs,
      locked: () async => appLockHidesRequests(appLock),
    ),
    service: service,
    signedOut: auth.signedOut,
    appLock: appLock == null ? null : _AppLockOn(appLock),
  );

  final RequestAnswerSender _sender;
  final NotificationService? _service;

  /// Fires when the session ends: the question categories the Runner keeps
  /// hold the choices the agent offered, so they go too.
  final Stream<void>? _signedOut;
  final Future<void> Function() _forgetCategories;

  /// Whether App Lock is on; when it goes on, notifications whose buttons
  /// would answer past it are withdrawn.
  final ValueListenable<bool>? _appLock;
  var _wasLocked = false;
  StreamSubscription<NotificationAnswer>? _answers;
  StreamSubscription<void>? _signOuts;
  ReceivePort? _port;

  void start() {
    _answers = _service?.answers.listen((answer) => _sender.send(answer));
    _signOuts = _signedOut?.listen((_) => _forgetCategories());
    _wasLocked = _appLock?.value ?? false;
    _appLock?.addListener(_onAppLock);
    final port = _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(kRequestAnswersPort);
    IsolateNameServer.registerPortWithName(port.sendPort, kRequestAnswersPort);
    port.listen(_onMessage);
  }

  /// Offers to take an action over and sends it only once the background
  /// isolate confirms: it may have stopped waiting and answered alone.
  Future<void> _onMessage(Object? message) async {
    if (message is! List || message.length != 5) return;
    final [payload, actionId, input, deadline, reply] = message;
    if (reply is! SendPort || deadline is! int) return;
    final confirm = ReceivePort();
    reply.send([_offer, confirm.sendPort]);
    // Until the deadline: a confirmation still on its way must not be
    // missed, or neither isolate would send the answer or tell the user.
    final due = DateTime.fromMillisecondsSinceEpoch(deadline);
    final wait = due.difference(DateTime.now());
    final go = await confirm.first.timeout(
      wait.isNegative ? Duration.zero : wait,
      onTimeout: () => null,
    );
    confirm.close();
    if (go != _go) return;
    final answer = answerFromAction(
      payload as String?,
      actionId as String?,
      input as String?,
    );
    final outcome = answer == null
        ? AnswerOutcome.failed
        : await _sender.send(answer, route: 'background', deadline: due);
    reply.send(outcome.name);
  }

  void _onAppLock() {
    final locked = _appLock?.value ?? false;
    if (locked && !_wasLocked) unawaited(_service?.withdrawAnswerable());
    _wasLocked = locked;
  }

  void dispose() {
    _appLock?.removeListener(_onAppLock);
    _answers?.cancel();
    _signOuts?.cancel();
    final port = _port;
    if (port != null) {
      IsolateNameServer.removePortNameMapping(kRequestAnswersPort);
      port.close();
    }
  }
}

/// The running app's offer to take an action over, with the port to confirm
/// it on.
const _offer = 'offer';

/// The background isolate's confirmation: from here on the app sends the
/// answer and tells the user if it fails.
const _go = 'go';

/// Hands the action to the running app and otherwise runs [alone], by
/// [deadline] (now plus [kAnswerBudget] when not given).
///
/// The app's port is looked for over [pollFor], since an app started by the
/// same launch may register it a moment later. The hand-off takes two
/// steps: the app offers to take the action within [takeTimeout], and only
/// sends it once this isolate confirms. A port left by an isolate that is
/// gone offers nothing, and an offer that comes too late finds no one to
/// confirm it, so the answer never goes out twice. Once confirmed, the app
/// posts any follow-up itself; this waits for its outcome until the deadline
/// and [reportGrace] after, and calls [unanswered] when none came, so the
/// user hears of an answer that may not have gone out.
Future<AnswerOutcome> routeAnswer(
  NotificationResponse response, {
  required Future<AnswerOutcome> Function(
    NotificationAnswer answer,
    DateTime deadline,
  )
  alone,
  required Future<void> Function(NotificationAnswer answer) unanswered,
  SendPort? Function() lookup = _lookupApp,
  DateTime? deadline,
  Duration pollFor = const Duration(seconds: 3),
  Duration pollEvery = const Duration(milliseconds: 200),
  Duration takeTimeout = const Duration(seconds: 3),
  Duration reportGrace = const Duration(seconds: 2),
}) async {
  final answer = answerFromResponse(response);
  if (answer == null) return AnswerOutcome.failed;
  final due = deadline ?? DateTime.now().add(kAnswerBudget);
  var app = lookup();
  final searchEnds = DateTime.now().add(pollFor);
  while (app == null && DateTime.now().isBefore(searchEnds)) {
    await Future<void>.delayed(pollEvery);
    app = lookup();
  }
  if (app == null) return alone(answer, due);
  final reply = ReceivePort();
  final replies = StreamIterator(reply);
  try {
    app.send([
      response.payload,
      response.actionId,
      response.input,
      due.millisecondsSinceEpoch,
      reply.sendPort,
    ]);
    final offered = await replies.moveNext().timeout(
      takeTimeout,
      onTimeout: () => false,
    );
    final offer = offered ? replies.current : null;
    if (offer is! List || offer.first != _offer || offer.last is! SendPort) {
      // A late offer must find no one listening.
      reply.close();
      return await alone(answer, due);
    }
    (offer.last as SendPort).send(_go);
    final wait = due.difference(DateTime.now()) + reportGrace;
    final reported = await replies.moveNext().timeout(
      wait.isNegative ? Duration.zero : wait,
      onTimeout: () => false,
    );
    if (!reported) {
      await unanswered(answer);
      return AnswerOutcome.failed;
    }
    return AnswerOutcome.values.firstWhere(
      (outcome) => outcome.name == replies.current,
      orElse: () => AnswerOutcome.failed,
    );
  } finally {
    reply.close();
  }
}

SendPort? _lookupApp() =>
    IsolateNameServer.lookupPortByName(kRequestAnswersPort);

/// Answers in the iOS background isolate when the app's own isolate is not
/// running. Answers go one at a time, so two of them never refresh the token
/// pair at once.
class LoneAnswerer {
  LoneAnswerer({
    AuthController Function()? createAuth,
    ChatTransport? Function(AuthController auth)? transportFor,
    NotificationService? notifications,
    Future<bool> Function()? locked,
  }) : _createAuth = createAuth ?? AuthController.new,
       _locked = locked ?? AppLockController.savedEnabled,
       _transportFor = transportFor ?? gatewayTransportFor,
       _notifications =
           notifications ?? LocalNotificationService(background: true);

  final AuthController Function() _createAuth;
  final ChatTransport? Function(AuthController auth) _transportFor;
  final NotificationService _notifications;
  final Future<bool> Function() _locked;
  Future<void> _last = Future.value();

  Future<AnswerOutcome> answer(NotificationAnswer answer, DateTime deadline) {
    final run = _last.then((_) => _answer(answer, deadline));
    _last = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Each answer starts from the saved server and session as they are now:
  /// a controller kept from an earlier answer would miss a sign-out or a
  /// switch to another server meanwhile.
  Future<AnswerOutcome> _answer(
    NotificationAnswer answer,
    DateTime deadline,
  ) async {
    final auth = _createAuth();
    try {
      return await RequestAnswerSender(
        transport: () => _transportFor(auth),
        notifications: _notifications,
        ready: auth.bootstrap,
        locked: _locked,
      ).send(answer, route: 'background', deadline: deadline);
    } finally {
      auth.dispose();
    }
  }
}

const _backgroundTask = MethodChannel('hermes_app/background_task');

/// What the Runner adds to a button's payload as it hands it over: when it
/// arrived (milliseconds since the epoch) and the background task begun for
/// it.
({DateTime? receivedAt, int? task}) handoverOf(String? payload) {
  if (payload == null) return (receivedAt: null, task: null);
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return (receivedAt: null, task: null);
    final at = decoded['_at'];
    final task = decoded['_task'];
    return (
      receivedAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      task: task is int ? task : null,
    );
  } on FormatException {
    return (receivedAt: null, task: null);
  }
}

/// Tells the Runner the answer for [task] is done, so it ends that
/// background task.
Future<void> _endBackgroundTask(int? task) async {
  if (task == null) return;
  try {
    await _backgroundTask.invokeMethod<void>('end', task);
  } on Object {
    // The system ends it when its time runs out.
  }
}

LoneAnswerer? _loneAnswerer;

/// Where iOS delivers a button that does not open the app, in an isolate of
/// its own.
@pragma('vm:entry-point')
Future<void> answerRequestInBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final handover = handoverOf(response.payload);
  // From when iOS handed the button over: the background time started then.
  final deadline = (handover.receivedAt ?? DateTime.now()).add(kAnswerBudget);
  final lone = _loneAnswerer ??= LoneAnswerer();
  try {
    await routeAnswer(
      response,
      alone: lone.answer,
      unanswered: (answer) => RequestAnswerSender.tellFailed(
        LocalNotificationService(background: true),
        answer,
      ),
      deadline: deadline,
    );
  } finally {
    await _endBackgroundTask(handover.task);
  }
}

/// App Lock's on state as the hand-off watches it.
class _AppLockOn extends ChangeNotifier implements ValueListenable<bool> {
  _AppLockOn(this._lock) {
    _lock.addListener(notifyListeners);
  }

  final AppLockController _lock;

  @override
  bool get value => _lock.loaded && _lock.enabled;
}
