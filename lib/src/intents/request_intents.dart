/// What the "Pending Requests" and "Answer Approval" App Intents ask of Dart:
/// the open requests across profiles, one approval with its command, and the
/// answer to it. They run through the headless runtime, so nothing here needs
/// the app to be open.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse, NotificationResponseType;
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../background/background_refresh.dart';
import '../background/entry_points.dart';
import '../background/headless_hermes.dart';
import '../chat/chat_models.dart' show ApprovalRequest;
import '../chat/gateway/gateway_rpc_client.dart';
import '../notifications/attention_policy.dart' show AttentionNotification;
import '../notifications/local_notification_service.dart'
    show notificationPayload;
import '../notifications/notification_service.dart';
import '../notifications/request_answers.dart';
import '../notifications/request_notifications.dart' as notifications;
import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';

/// The Runner's channel for these intents (`RequestIntentsBridge.swift`).
const kRequestIntentsChannel = 'hermes_app/request_intents';

/// The choices an approval can be answered with, as Hermes names them.
const kApprovalChoices = {'once', 'session', 'always', 'deny'};

/// The refusal Hermes answers `approval.pending` with while no provider is
/// configured, since it cannot build the agent that holds the approvals.
const kGatewayNoProvider = 5032;

/// What a call gets to work in when the caller names no budget. The caller
/// (the Runner) waits for this plus [kIntentOverhead] and a margin.
const kIntentReadBudget = Duration(seconds: 12);
const kIntentAnswerBudget = Duration(seconds: 15);

/// What a run adds to its budget in the worst case: the headless runtime's
/// wind-down (`HeadlessDeps.closeGrace`) and the telemetry flush.
const kIntentOverhead = Duration(seconds: 5);

/// How a request intent ended. [wire] is what crosses to Swift and what the
/// telemetry records.
enum RequestIntentOutcome {
  /// The list was read, or the approval was answered.
  answered('answered'),

  /// Nothing was waiting.
  none('none'),

  /// The request was no longer waiting.
  gone('gone'),
  cancelled('cancelled'),
  failed('failed'),
  signedOut('signed_out'),
  deviceLocked('device_locked'),
  unreachable('unreachable'),

  /// Hermes refuses to list approvals (no provider configured).
  cannotList('cannot_list'),

  /// App Lock is on: the request's content stays inside the app.
  appLocked('app_locked');

  const RequestIntentOutcome(this.wire);

  final String wire;
}

/// Serves the calls of the request intents. Every method returns a map of
/// plain values for the method channel; none of them throws.
///
/// Each call may carry `budgetMs`, what the caller grants the work; the
/// caller's own timeout is that plus [kIntentOverhead] and a margin, so the
/// two never race.
class RequestIntents {
  RequestIntents({
    this.headless,
    Future<bool> Function()? appLockOn,
    AppEventLogger Function()? events,
    this._snapshotStore,
    this.engine = 'background',
    this.snapshotWait = const Duration(seconds: 1),
  }) : _appLockOn = appLockOn ?? AppLockController.savedEnabled,
       _events = events ?? (() => backgroundTelemetry(const {}).events);

  /// What the headless runs are wired to; the device's own parts by default.
  final HeadlessDeps? headless;
  final Future<bool> Function() _appLockOn;
  final AppEventLogger Function() _events;
  SurfaceSnapshotStore? _snapshotStore;

  /// Which engine runs the intent, for the run's span.
  final String engine;

  /// How long the local snapshot update that follows a reply may take. It is
  /// a courtesy to the widgets; it never changes what the intent says.
  final Duration snapshotWait;

  SurfaceSnapshotStore get _store =>
      headless?.snapshotStore ??
      (_snapshotStore ??= SurfaceSnapshotStore(
        events: (name, [attributes = const {}]) => _events()(name, attributes),
      ));

  /// The open requests of every profile (or of `profile`), oldest first.
  ///
  /// `{outcome, count, appLock, requests: [{profile, threadId, title, kind,
  /// requestId, createdAt}]}`. With App Lock on `requests` stays empty: titles
  /// are the app's. When the server cannot be asked, `outcome` says why, with
  /// `appLock`, and the caller answers from the snapshot it has stored.
  Future<Map<String, Object?>> pending(Map<String, Object?> args) async {
    final profile = _text(args['profile']);
    final lockOn = await _lockedNow();
    final outcome = await withHeadlessHermes<List<PendingRequest>>(
      _readPending,
      task: 'intent.pending',
      timeout: _budget(args, kIntentReadBudget),
      deps: headless,
    );
    switch (outcome) {
      case HeadlessDone(:final value):
        final seen = await _firstSeen();
        final rows = [
          for (final request in value)
            request.firstSeen(seen[request.requestId] ?? request.createdAt),
        ];
        await _storePending(rows);
        final listed = [
          for (final request in rows)
            if (profile == null || request.profile == profile) request,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return {
          'outcome': _listed(listed).wire,
          'count': listed.length,
          'appLock': lockOn,
          'requests': [
            if (!lockOn)
              for (final request in listed)
                {
                  'profile': request.profile,
                  'threadId': request.threadId,
                  'title': request.threadTitle,
                  'kind': request.kind.name,
                  'requestId': request.requestId,
                  'createdAt': request.createdAt.toUtc().toIso8601String(),
                },
          ],
        };
      case HeadlessSignedOut():
        return _unfinished(RequestIntentOutcome.signedOut, lockOn);
      case HeadlessLocked():
        return _unfinished(RequestIntentOutcome.deviceLocked, lockOn);
      case HeadlessUnreachable():
        return _unfinished(RequestIntentOutcome.unreachable, lockOn);
    }
  }

  Future<List<PendingRequest>> _readPending(HeadlessHermes hermes) async {
    final step = OpenRequestsStep();
    // Nothing is announced: the context says notifications are off, so the
    // step only reads. A failed read shows up as no result below.
    final context = BackgroundContext(
      hermes: hermes,
      notificationsOn: false,
      notifications: const _NoNotifications(),
      announced: AnnouncedRequests(),
      appLockOn: _appLockOn,
      inFront: () async => false,
    );
    try {
      await step.run(context);
    } on Object {
      // `found` reports it.
    }
    final found = await step.found;
    if (found == null) throw StateError('The open requests were not read');
    hermes
      ..annotate('engine', engine)
      ..annotate('result', _listed(found).wire)
      ..annotate('requests', found.length);
    return found;
  }

  static RequestIntentOutcome _listed(List<PendingRequest> rows) =>
      rows.isEmpty ? RequestIntentOutcome.none : RequestIntentOutcome.answered;

  /// When each stored request was first seen, by request id; none when the
  /// stored snapshot cannot be read in time.
  Future<Map<String, DateTime>> _firstSeen() async {
    try {
      final stored = await _store.read().timeout(snapshotWait);
      return {
        for (final request in stored?.pending ?? const <PendingRequest>[])
          request.requestId: request.createdAt,
      };
    } on Object {
      return const {};
    }
  }

  /// Stores [rows] as the snapshot's open requests, so the widgets, the badge
  /// and the entity picker agree with what was just said. Local storage only:
  /// the other sections are the app's and the background refresh's to read
  /// from the server. Without a stored, signed-in snapshot there is nothing to
  /// amend.
  Future<void> _storePending(List<PendingRequest> rows) =>
      _amendSnapshot((stored) => stored.withPending(rows, DateTime.now()));

  Future<void> _amendSnapshot(
    SurfaceSnapshot Function(SurfaceSnapshot stored) amend,
  ) async {
    try {
      await (() async {
        final stored = await _store.read();
        if (stored == null || !stored.signedIn) return;
        await _store.writeIfCurrent(amend(stored), appLockOn: _appLockOn);
      })().timeout(snapshotWait);
    } on Object {
      // The next refresh catches up.
    }
  }

  /// The command, description and offered choices of one open approval.
  ///
  /// `{outcome: 'found', command, description, choices}`, or `gone` when the
  /// session no longer waits on it. With App Lock on nothing is read: the
  /// command would show past the lock. `cannot_list` when Hermes refuses to
  /// list approvals, `failed` for any other refusal.
  Future<Map<String, Object?>> approvalDetail(Map<String, Object?> args) async {
    final threadId = _text(args['threadId']);
    final requestId = _text(args['requestId']);
    if (threadId == null || requestId == null) {
      return _outcome(RequestIntentOutcome.failed);
    }
    if (await _lockedNow()) return _outcome(RequestIntentOutcome.appLocked);
    final outcome = await withHeadlessHermes<Map<String, Object?>>(
      (hermes) async {
        hermes
          ..annotate('engine', engine)
          ..annotate('step', 'detail');
        Map<String, Object?> done(RequestIntentOutcome result) {
          hermes.annotate('result', result.wire);
          return _outcome(result);
        }

        final List<ApprovalRequest> approvals;
        try {
          approvals = await hermes.transport().pendingApprovals(
            threadId: threadId,
            profile: _text(args['profile']),
          );
        } on GatewayRpcException catch (error) {
          return done(
            error.code == kGatewayNoProvider
                ? RequestIntentOutcome.cannotList
                : RequestIntentOutcome.failed,
          );
        }
        for (final approval in approvals) {
          if (approval.requestId != requestId) continue;
          hermes.annotate('result', 'found');
          return {
            'outcome': 'found',
            'command': approval.command,
            'description': approval.description,
            'choices': approval.choices,
          };
        }
        return done(RequestIntentOutcome.gone);
      },
      task: 'intent.answer_approval',
      timeout: _budget(args, kIntentReadBudget),
      deps: headless,
    );
    return switch (outcome) {
      HeadlessDone(:final value) => value,
      HeadlessSignedOut() => _outcome(RequestIntentOutcome.signedOut),
      HeadlessLocked() => _outcome(RequestIntentOutcome.deviceLocked),
      HeadlessUnreachable() => _outcome(RequestIntentOutcome.unreachable),
    };
  }

  /// Answers the approval `requestId` of the chat `threadId` with `choice`,
  /// by the same path as a notification's button, and takes it off the
  /// snapshot's pending list. `{outcome}`. When the app's own isolate is
  /// alive it sends the answer, so the chat on screen follows.
  Future<Map<String, Object?>> answerApproval(Map<String, Object?> args) async {
    final choice = _text(args['choice']);
    final threadId = _text(args['threadId']);
    final requestId = _text(args['requestId']);
    final profile = _text(args['profile']);
    if (choice == null ||
        !kApprovalChoices.contains(choice) ||
        threadId == null ||
        requestId == null) {
      return _outcome(RequestIntentOutcome.failed);
    }
    // Before any run: with App Lock on nothing touches the server.
    final result = await _lockedNow()
        ? RequestIntentOutcome.appLocked
        : await _answer(
            threadId: threadId,
            requestId: requestId,
            profile: profile,
            choice: choice,
            budget: _budget(args, kIntentAnswerBudget),
          );
    _log('intent.answer_approval', {'outcome': result.wire, 'choice': choice});
    if (result == RequestIntentOutcome.answered ||
        result == RequestIntentOutcome.gone) {
      await _amendSnapshot(
        (stored) => stored.withPending([
          for (final request in stored.pending)
            if (request.requestId != requestId) request,
        ], DateTime.now()),
      );
    }
    return _outcome(result);
  }

  Future<RequestIntentOutcome> _answer({
    required String threadId,
    required String requestId,
    required String? profile,
    required String choice,
    required Duration budget,
  }) async {
    final due = DateTime.now().add(budget);
    final response = NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: _actionFor(choice),
      payload: notificationPayload(
        AttentionNotification(
          threadId: threadId,
          profile: profile,
          title: '',
          body: '',
          request: notifications.PendingRequest(
            requestId: requestId,
            kind: notifications.PendingRequestKind.approval,
          ),
        ),
      ),
    );
    RequestIntentOutcome? direct;
    final handed = await routeAnswer(
      response,
      // The app's isolate, when it runs, is polled for once: an engine the
      // intent started has no app beside it, and waiting would only add time.
      pollFor: Duration.zero,
      deadline: due,
      alone: (answer, deadline) async {
        direct = await _answerAlone(answer, deadline);
        return switch (direct) {
          RequestIntentOutcome.answered => AnswerOutcome.ok,
          RequestIntentOutcome.gone => AnswerOutcome.expired,
          RequestIntentOutcome.signedOut => AnswerOutcome.signedOut,
          RequestIntentOutcome.appLocked => AnswerOutcome.locked,
          _ => AnswerOutcome.failed,
        };
      },
      unanswered: (_) async {},
    );
    return direct ??
        switch (handed) {
          AnswerOutcome.ok => RequestIntentOutcome.answered,
          AnswerOutcome.expired => RequestIntentOutcome.gone,
          AnswerOutcome.signedOut => RequestIntentOutcome.signedOut,
          AnswerOutcome.locked => RequestIntentOutcome.appLocked,
          AnswerOutcome.failed => RequestIntentOutcome.failed,
        };
  }

  /// Sends the answer on a connection of the headless runtime. Nothing is
  /// posted for a failure: the intent says it.
  Future<RequestIntentOutcome> _answerAlone(
    NotificationAnswer answer,
    DateTime due,
  ) async {
    final left = due.difference(DateTime.now());
    final outcome = await withHeadlessHermes<RequestIntentOutcome>(
      (hermes) async {
        final sent = await RequestAnswerSender(
          transport: hermes.transport,
          events: () => hermes.repositories.telemetry.events,
          locked: _appLockOn,
          timeout: left.isNegative ? Duration.zero : left,
        ).send(answer, route: 'intent', deadline: due);
        final result = switch (sent) {
          AnswerOutcome.ok => RequestIntentOutcome.answered,
          AnswerOutcome.expired => RequestIntentOutcome.gone,
          AnswerOutcome.signedOut => RequestIntentOutcome.signedOut,
          AnswerOutcome.locked => RequestIntentOutcome.appLocked,
          AnswerOutcome.failed => RequestIntentOutcome.failed,
        };
        hermes
          ..annotate('engine', engine)
          ..annotate('step', 'answer')
          ..annotate('result', result.wire);
        return result;
      },
      task: 'intent.answer_approval',
      timeout: left.isNegative ? Duration.zero : left,
      deps: headless,
    );
    return switch (outcome) {
      HeadlessDone(:final value) => value,
      HeadlessSignedOut() => RequestIntentOutcome.signedOut,
      HeadlessLocked() => RequestIntentOutcome.deviceLocked,
      HeadlessUnreachable() => RequestIntentOutcome.unreachable,
    };
  }

  static String _actionFor(String choice) => switch (choice) {
    'once' => notifications.kAllowOnceAction,
    'session' => notifications.kAllowSessionAction,
    'always' => notifications.kAllowAlwaysAction,
    _ => notifications.kDenyAction,
  };

  /// Records an outcome that only the intent's Swift side can see, such as
  /// the user cancelling the confirmation. Only the fixed words are taken.
  Map<String, Object?> record(Map<String, Object?> args) {
    final outcome = _text(args['outcome']);
    final choice = _text(args['choice']);
    if (outcome == RequestIntentOutcome.cancelled.wire &&
        choice != null &&
        kApprovalChoices.contains(choice)) {
      _log('intent.answer_approval', {
        'outcome': RequestIntentOutcome.cancelled.wire,
        'choice': choice,
      });
    }
    return const {};
  }

  Future<bool> _lockedNow() async {
    try {
      return await _appLockOn();
    } on Object {
      return true;
    }
  }

  void _log(String name, Map<String, Object> attributes) {
    try {
      _events()(name, attributes);
    } on Object {
      // Telemetry must not fail an intent.
    }
  }

  static Duration _budget(Map<String, Object?> args, Duration fallback) {
    final ms = args['budgetMs'];
    return ms is num && ms > 0 ? Duration(milliseconds: ms.toInt()) : fallback;
  }

  static Map<String, Object?> _outcome(RequestIntentOutcome outcome) => {
    'outcome': outcome.wire,
  };

  /// A reply for a run that never got to its body.
  static Map<String, Object?> _unfinished(
    RequestIntentOutcome outcome,
    bool lockOn,
  ) => {'outcome': outcome.wire, 'appLock': lockOn};

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

/// The step that lists the open requests needs a notification service even
/// though, with notifications off, it never uses it.
class _NoNotifications implements NotificationService {
  const _NoNotifications();

  @override
  Stream<NotificationAnswer> get answers => const Stream.empty();

  @override
  Stream<NotificationTarget> get taps => const Stream.empty();

  @override
  Future<bool?> allowed() async => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  Future<NotificationPermission> requestPermission() async =>
      NotificationPermission.unavailable;

  @override
  Future<void> show(AttentionNotification notification) async {}

  @override
  Future<void> withdrawAnswerable() async {}
}

/// Serves [RequestIntents] on [kRequestIntentsChannel] in a background engine.
class RequestIntentsChannel {
  RequestIntentsChannel(
    this._intents, {
    MethodChannel? channel,
    Future<void> Function()? flush,
  }) : _channel = channel ?? const MethodChannel(kRequestIntentsChannel),
       _flush = flush ?? flushBackgroundTelemetry;

  final RequestIntents _intents;
  final MethodChannel _channel;
  final Future<void> Function() _flush;

  /// Starts answering the Runner's calls, then tells it the engine is ready.
  Future<void> serve() async {
    _channel.setMethodCallHandler(handle);
    await _channel.invokeMethod<void>('ready');
  }

  /// Runs one call and sends its telemetry before iOS may suspend the app.
  Future<Object?> handle(MethodCall call) async {
    final args = switch (call.arguments) {
      final Map<Object?, Object?> map => map.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final Object? result;
    switch (call.method) {
      case 'pending':
        result = await _intents.pending(args);
      case 'approvalDetail':
        result = await _intents.approvalDetail(args);
      case 'answerApproval':
        result = await _intents.answerApproval(args);
      case 'record':
        result = _intents.record(args);
      default:
        throw MissingPluginException('No ${call.method} in $_channel');
    }
    try {
      await _flush().timeout(const Duration(seconds: 2));
    } on Object {
      // Telemetry must not hold back the answer.
    }
    return result;
  }
}
