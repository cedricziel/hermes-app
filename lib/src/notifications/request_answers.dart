/// Sends the answer the user gave with a request notification's button, from
/// whichever isolate received it.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../auth/auth_controller.dart';
import '../chat/chat_transport.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../telemetry/breadcrumbs.dart';
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

enum AnswerOutcome { ok, expired, failed, signedOut }

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

  static Future<void> _readyNow() async {}

  static AppEventLogger _noEvents() => noopAppEventLogger;

  /// Sends [answer]; with a [deadline], gives up on it in time to post the
  /// follow-up before then.
  Future<AnswerOutcome> send(
    NotificationAnswer answer, {
    String route = 'main',
    DateTime? deadline,
  }) async {
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

  /// Posts the follow-up that sends the user to [answer]'s chat.
  static Future<void> tellFailed(
    NotificationService? notifications,
    NotificationAnswer answer,
  ) async {
    try {
      await notifications?.show(
        AttentionNotification(
          threadId: answer.target.threadId,
          profile: answer.target.profile,
          title: answer.title,
          body: kAnswerFailedBody,
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
  });

  /// Answers on a fresh connection of whoever is signed in on [auth].
  factory RequestAnswers.forAuth(
    AuthController auth, {
    required NotificationService service,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) => RequestAnswers(
    RequestAnswerSender(
      transport: () =>
          gatewayTransportFor(auth, events: auth.connectionTelemetry.events),
      notifications: service,
      ready: () => authSettled(auth),
      events: () => auth.connectionTelemetry.events,
      breadcrumbs: breadcrumbs,
    ),
    service: service,
    signedOut: auth.signedOut,
  );

  final RequestAnswerSender _sender;
  final NotificationService? _service;

  /// Fires when the session ends: the question categories the Runner keeps
  /// hold the choices the agent offered, so they go too.
  final Stream<void>? _signedOut;
  final Future<void> Function() _forgetCategories;
  StreamSubscription<NotificationAnswer>? _answers;
  StreamSubscription<void>? _signOuts;
  ReceivePort? _port;

  void start() {
    _answers = _service?.answers.listen((answer) => _sender.send(answer));
    _signOuts = _signedOut?.listen((_) => _forgetCategories());
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
    final go = await confirm.first.timeout(_confirmWait, onTimeout: () => null);
    confirm.close();
    if (go != _go) return;
    final answer = answerFromAction(
      payload as String?,
      actionId as String?,
      input as String?,
    );
    final outcome = answer == null
        ? AnswerOutcome.failed
        : await _sender.send(
            answer,
            route: 'background',
            deadline: DateTime.fromMillisecondsSinceEpoch(deadline),
          );
    reply.send(outcome.name);
  }

  void dispose() {
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

const _confirmWait = Duration(seconds: 2);

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
/// and [reportGrace] after.
Future<AnswerOutcome> routeAnswer(
  NotificationResponse response, {
  required Future<AnswerOutcome> Function(
    NotificationAnswer answer,
    DateTime deadline,
  )
  alone,
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
    if (!reported) return AnswerOutcome.failed;
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
  }) : _createAuth = createAuth ?? AuthController.new,
       _transportFor = transportFor ?? gatewayTransportFor,
       _notifications =
           notifications ?? LocalNotificationService(background: true);

  final AuthController Function() _createAuth;
  final ChatTransport? Function(AuthController auth) _transportFor;
  final NotificationService _notifications;
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
      ).send(answer, route: 'background', deadline: deadline);
    } finally {
      auth.dispose();
    }
  }
}

const _backgroundTask = MethodChannel('hermes_app/background_task');

/// Tells the Runner an answer is done, so it ends the background task it
/// began when iOS handed the button over.
Future<void> _endBackgroundTask() async {
  try {
    await _backgroundTask.invokeMethod<void>('end');
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
  final deadline = DateTime.now().add(kAnswerBudget);
  final lone = _loneAnswerer ??= LoneAnswerer();
  try {
    await routeAnswer(response, alone: lone.answer, deadline: deadline);
  } finally {
    await _endBackgroundTask();
  }
}
