/// What the "Pending Requests" and "Answer Approval" App Intents ask of Dart:
/// the open requests across profiles, one approval with its command, and the
/// answer to it. They run in a background engine through the headless
/// runtime, so nothing here needs the app to be open.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;

import '../app_lock/app_lock_controller.dart';
import '../background/background_refresh.dart';
import '../background/entry_points.dart';
import '../background/headless_hermes.dart';
import '../chat/chat_transport.dart';
import '../notifications/attention_policy.dart' show AttentionNotification;
import '../notifications/notification_service.dart';
import '../notifications/request_answers.dart';
import '../notifications/request_notifications.dart' as notifications;
import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';

/// The Runner's channel for these intents (`RequestIntentsBridge.swift`).
const kRequestIntentsChannel = 'hermes_app/request_intents';

/// The choices an approval can be answered with, as Hermes names them.
const kApprovalChoices = {'once', 'session', 'always', 'deny'};

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

  /// App Lock is on: the request's content stays inside the app.
  appLocked('app_locked');

  const RequestIntentOutcome(this.wire);

  final String wire;
}

/// Serves the three calls of the request intents. Every method returns a map
/// of plain values for the method channel; none of them throws.
class RequestIntents {
  RequestIntents({
    this.headless,
    Future<bool> Function()? appLockOn,
    AppEventLogger Function()? events,
    this.engine = 'background',
    this.pendingTimeout = const Duration(seconds: 15),
    this.answerTimeout = const Duration(seconds: 20),
    this.snapshotRefresh = const Duration(seconds: 6),
  }) : _appLockOn = appLockOn ?? AppLockController.savedEnabled,
       _events = events ?? (() => backgroundTelemetry(const {}).events);

  /// What the headless runs are wired to; the device's own parts by default.
  final HeadlessDeps? headless;
  final Future<bool> Function() _appLockOn;
  final AppEventLogger Function() _events;

  /// Which engine runs the intent, for the run's span.
  final String engine;
  final Duration pendingTimeout;
  final Duration answerTimeout;

  /// How long the snapshot refresh that follows a read or an answer may take.
  /// It is a courtesy to the widgets; the intent's answer never waits longer.
  final Duration snapshotRefresh;

  /// The open requests of every profile (or of `profile`), oldest first.
  ///
  /// `{outcome, count, appLock, requests: [{profile, threadId, title, kind,
  /// requestId, createdAt}]}`. With App Lock on `requests` stays empty: titles
  /// are the app's. When the server cannot be asked, only `outcome` says why
  /// and the caller answers from the snapshot it has stored.
  Future<Map<String, Object?>> pending(Map<String, Object?> args) async {
    final profile = _text(args['profile']);
    final lockOn = await _lockedNow();
    final outcome = await withHeadlessHermes<List<PendingRequest>>(
      _readPending,
      task: 'intent.pending',
      timeout: pendingTimeout,
      deps: headless,
    );
    switch (outcome) {
      case HeadlessDone(:final value):
        final rows = [
          for (final request in value)
            if (profile == null || request.profile == profile) request,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return {
          'outcome': _listed(rows).wire,
          'count': rows.length,
          'appLock': lockOn,
          'requests': [
            if (!lockOn)
              for (final request in rows)
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
        return _outcome(RequestIntentOutcome.signedOut);
      case HeadlessLocked():
        return _outcome(RequestIntentOutcome.deviceLocked);
      case HeadlessUnreachable():
        return _outcome(RequestIntentOutcome.unreachable);
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
    final rows = await _refreshed(hermes, found);
    hermes
      ..annotate('engine', engine)
      ..annotate('result', _listed(rows).wire)
      ..annotate('requests', rows.length);
    return rows;
  }

  static RequestIntentOutcome _listed(List<PendingRequest> rows) =>
      rows.isEmpty ? RequestIntentOutcome.none : RequestIntentOutcome.answered;

  /// Stores [found] as the snapshot's requests, so the widgets and the badge
  /// agree with what the intent says, and returns the stored rows (which
  /// remember when each request was first seen). Without a stored snapshot
  /// (dropped, or the refresh too slow) [found] stands.
  Future<List<PendingRequest>> _refreshed(
    HeadlessHermes hermes,
    List<PendingRequest> found,
  ) async {
    try {
      final written = await hermes
          .refreshSnapshot(pending: found)
          .timeout(snapshotRefresh);
      return written?.pending ?? found;
    } on Object {
      return found;
    }
  }

  /// The command, description and offered choices of one open approval.
  ///
  /// `{outcome: 'found', command, description, choices}`, or `gone` when the
  /// session no longer waits on it. With App Lock on nothing is read: the
  /// command would show past the lock.
  Future<Map<String, Object?>> approvalDetail(Map<String, Object?> args) async {
    final threadId = _text(args['threadId']);
    final requestId = _text(args['requestId']);
    if (threadId == null || requestId == null) {
      return _outcome(RequestIntentOutcome.failed);
    }
    if (await _lockedNow()) return _outcome(RequestIntentOutcome.appLocked);
    final outcome = await withHeadlessHermes<Map<String, Object?>>(
      (hermes) async {
        final approvals = await hermes.transport().pendingApprovals(
          threadId: threadId,
          profile: _text(args['profile']),
        );
        hermes
          ..annotate('engine', engine)
          ..annotate('step', 'detail');
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
        hermes.annotate('result', RequestIntentOutcome.gone.wire);
        return _outcome(RequestIntentOutcome.gone);
      },
      task: 'intent.answer_approval',
      timeout: pendingTimeout,
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
  /// snapshot's pending list. `{outcome}`.
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
          );
    _log('intent.answer_approval', {'outcome': result.wire, 'choice': choice});
    return _outcome(result);
  }

  Future<RequestIntentOutcome> _answer({
    required String threadId,
    required String requestId,
    required String? profile,
    required String choice,
  }) async {
    final outcome = await withHeadlessHermes<RequestIntentOutcome>(
      (hermes) async {
        final sent =
            await RequestAnswerSender(
              transport: hermes.transport,
              events: () => hermes.repositories.telemetry.events,
              locked: _appLockOn,
              timeout: answerTimeout - const Duration(seconds: 3),
            ).send(
              NotificationAnswer(
                target: NotificationTarget(
                  threadId: threadId,
                  profile: profile,
                ),
                title: '',
                request: notifications.PendingRequest(
                  requestId: requestId,
                  kind: notifications.PendingRequestKind.approval,
                  // Found with approval.pending, which lists the approvals the
                  // session raised as events.
                  raisedAsEvent: true,
                ),
                answer: ApprovalChoiceAnswer(choice),
              ),
              route: 'intent',
            );
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
        if (sent == AnswerOutcome.ok || sent == AnswerOutcome.expired) {
          await _dropFromSnapshot(hermes, requestId);
        }
        return result;
      },
      task: 'intent.answer_approval',
      timeout: answerTimeout,
      deps: headless,
    );
    return switch (outcome) {
      HeadlessDone(:final value) => value,
      HeadlessSignedOut() => RequestIntentOutcome.signedOut,
      HeadlessLocked() => RequestIntentOutcome.deviceLocked,
      HeadlessUnreachable() => RequestIntentOutcome.unreachable,
    };
  }

  /// Saves the snapshot without [requestId], so the badge, the widgets and the
  /// next "Pending Requests" stop listing it. The answer is already given;
  /// whatever goes wrong here is left for the next refresh.
  Future<void> _dropFromSnapshot(
    HeadlessHermes hermes,
    String requestId,
  ) async {
    try {
      final stored =
          await (headless?.snapshotStore ??
                  SurfaceSnapshotStore(
                    events: hermes.repositories.telemetry.events,
                  ))
              .read();
      if (stored == null || !stored.signedIn) return;
      await hermes
          .refreshSnapshot(
            pending: [
              for (final request in stored.pending)
                if (request.requestId != requestId) request,
            ],
          )
          .timeout(snapshotRefresh);
    } on Object {
      // The next refresh drops it.
    }
  }

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

  static Map<String, Object?> _outcome(RequestIntentOutcome outcome) => {
    'outcome': outcome.wire,
  };

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
