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
  });

  /// A new transport for each answer; null while nobody is signed in.
  final ChatTransport? Function() transport;
  final NotificationService? notifications;

  /// Completes once the app has restored its session, or gave up on it.
  final Future<void> Function() ready;
  final AppEventLogger Function() events;
  final Breadcrumbs breadcrumbs;
  final Duration timeout;

  static Future<void> _readyNow() async {}

  static AppEventLogger _noEvents() => noopAppEventLogger;

  Future<AnswerOutcome> send(
    NotificationAnswer answer, {
    String route = 'main',
  }) async {
    final outcome = await _send(answer);
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

  Future<AnswerOutcome> _send(NotificationAnswer answer) async {
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
  RequestAnswers(this._sender, {this._service});

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
  );

  final RequestAnswerSender _sender;
  final NotificationService? _service;
  StreamSubscription<NotificationAnswer>? _answers;
  ReceivePort? _port;

  void start() {
    _answers = _service?.answers.listen((answer) => _sender.send(answer));
    final port = _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(kRequestAnswersPort);
    IsolateNameServer.registerPortWithName(port.sendPort, kRequestAnswersPort);
    port.listen(_onMessage);
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! List || message.length != 4) return;
    final [payload, actionId, input, reply] = message;
    if (reply is! SendPort) return;
    // Taken: from here on this isolate tells the user if it fails.
    reply.send(_taken);
    final answer = answerFromAction(
      payload as String?,
      actionId as String?,
      input as String?,
    );
    final outcome = answer == null
        ? AnswerOutcome.failed
        : await _sender.send(answer, route: 'background');
    reply.send(outcome.name);
  }

  void dispose() {
    _answers?.cancel();
    final port = _port;
    if (port != null) {
      IsolateNameServer.removePortNameMapping(kRequestAnswersPort);
      port.close();
    }
  }
}

/// What the running app answers first, once it has taken an action over.
const _taken = 'taken';

/// Hands the action to the running app when it registered its port and takes
/// it within [takeTimeout], and otherwise runs [alone]: a port left behind by
/// an isolate that is gone takes nothing. Once the app took it, the app
/// reports a failure itself, so waiting longer than [timeout] for how it went
/// only gives up on the background time.
Future<AnswerOutcome> routeAnswer(
  NotificationResponse response, {
  required Future<AnswerOutcome> Function(NotificationAnswer answer) alone,
  SendPort? Function() lookup = _lookupApp,
  Duration takeTimeout = const Duration(seconds: 3),
  Duration timeout = const Duration(seconds: 25),
}) async {
  final answer = answerFromResponse(response);
  if (answer == null) return AnswerOutcome.failed;
  final app = lookup();
  if (app == null) return alone(answer);
  final reply = ReceivePort();
  final replies = StreamIterator(reply);
  try {
    app.send([
      response.payload,
      response.actionId,
      response.input,
      reply.sendPort,
    ]);
    final taken = await replies.moveNext().timeout(
      takeTimeout,
      onTimeout: () => false,
    );
    if (!taken || replies.current != _taken) return await alone(answer);
    final reported = await replies.moveNext().timeout(
      timeout,
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

const _backgroundTask = MethodChannel('hermes_app/background_task');

/// Runs [work] inside a UIKit background task, so iOS does not suspend the
/// app halfway: the plugin completes the system's handler before Dart runs.
Future<T> _inBackgroundTask<T>(Future<T> Function() work) async {
  Object? task;
  try {
    task = await _backgroundTask.invokeMethod<Object>('begin');
  } on Object {
    task = null;
  }
  try {
    return await work();
  } finally {
    if (task != null) {
      try {
        await _backgroundTask.invokeMethod<void>('end', task);
      } on Object {
        // The system ends it when its time runs out.
      }
    }
  }
}

/// Signs in from the stored session, as the app does at start, and sends
/// [answer]. Only runs while the app's own isolate is not running, so the two
/// never refresh the token pair at once.
Future<AnswerOutcome> _answerAlone(NotificationAnswer answer) async {
  final auth = AuthController();
  final notifications = LocalNotificationService(background: true);
  try {
    await auth.bootstrap();
    return await RequestAnswerSender(
      transport: () => gatewayTransportFor(auth),
      notifications: notifications,
    ).send(answer, route: 'background');
  } finally {
    auth.dispose();
    await notifications.dispose();
  }
}

/// Where iOS delivers a button that does not open the app, in an isolate of
/// its own.
@pragma('vm:entry-point')
Future<void> answerRequestInBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _inBackgroundTask(() => routeAnswer(response, alone: _answerAlone));
}
