/// What one periodic background run does: look for open requests, tell the
/// user of new ones, and refresh what the system surfaces show.
///
/// A run is a list of independent [BackgroundStep]s. One that fails or runs
/// too long is counted and does not stop the others.
library;

import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_lock/app_lock_controller.dart';
import '../chat/chat_models.dart';
import '../chat/gateway/gateway_rpc_client.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../notifications/attention_policy.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_posting.dart';
import '../notifications/notification_settings.dart';
import '../notifications/request_notifications.dart'
    show pendingRequestFor, requestCategoryFor;
import '../surfaces/chat_hints.dart' show kUnnamedChatLabel;
import '../surfaces/surface_snapshot.dart';
import 'app_presence.dart';
import 'background_alerts.dart';
import 'background_check_status.dart';
import 'background_scheduler.dart';
import 'background_spotlight.dart';
import 'background_surfaces.dart';
import 'headless_hermes.dart';

/// The whole run, which iOS allows about 30 seconds.
const kBackgroundRefreshBudget = Duration(seconds: 25);

/// The longest one step may take before it counts as failed.
const kBackgroundStepBudget = Duration(seconds: 20);

/// The most request ids kept to tell a new request from an announced one.
const kMaxAnnouncedRequests = 200;

const _announcedKey = 'hermes.background.announced.v1';

/// What a step reports of its work; counts only.
class StepCounts {
  const StepCounts({
    this.newRequests = 0,
    this.repliesFinished = 0,
    this.schedulesRan = 0,
    this.messagesFound = 0,
  });

  /// Open requests announced for the first time.
  final int newRequests;

  /// Replies that finished while the app was away, announced.
  final int repliesFinished;

  /// Scheduled runs announced.
  final int schedulesRan;

  /// Messages from Hermes announced.
  final int messagesFound;
}

/// Everything a step may use. The gateway socket is shared by all steps.
class BackgroundContext {
  BackgroundContext({
    required this.hermes,
    required this.notificationsOn,
    required this.notifications,
    required this.announced,
    required this._appLockOn,
    this._inFront = appInFront,
    this._request,
    this.stepTimeout = kBackgroundStepBudget,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _started = (now ?? DateTime.now)();

  final HeadlessHermes hermes;

  /// Whether the user wants notifications at all.
  final bool notificationsOn;
  final NotificationService notifications;
  final AnnouncedRequests announced;
  final Future<bool> Function() _appLockOn;
  final Future<bool> Function() _inFront;
  final GatewayRequest? _request;

  /// How long each step may take, from the start of the run.
  final Duration stepTimeout;
  final DateTime Function() _now;
  final DateTime _started;

  HermesGatewayTransport? _transport;
  Future<bool>? _lockOn;
  Future<bool>? _inFrontNow;

  HermesGatewayTransport get transport => _transport ??= hermes.transport();

  /// Whether App Lock is on, read once: unreadable counts as on.
  Future<bool> appLockOn() => _lockOn ??= _appLockOn();

  /// Whether the app is in front, asked once. WorkManager runs a task while
  /// the app is open, which announces requests itself; an app that is only
  /// alive in the background does not.
  Future<bool> isAppInFront() => _inFrontNow ??= _inFront();

  /// Whether the app is in front now, asked again each time: for a step that
  /// must not act on an answer from before a long read.
  Future<bool> appInFrontNow() => _inFront();

  /// What is left of a step's time, less [reserve] for the work it still has
  /// to do after waiting; never below zero. All steps start with the run, and
  /// the run's own deadline, counted from before it connected, may come first.
  Duration remainingStepBudget({
    Duration reserve = const Duration(seconds: 2),
  }) {
    final step = stepTimeout - _now().difference(_started);
    final run = hermes.untilDeadline;
    final left = (run < step ? run : step) - reserve;
    return left.isNegative ? Duration.zero : left;
  }

  /// Sends a gateway request on the run's shared socket.
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) => (_request ?? _viaTransport)(transport, method, params);

  static Future<Map<String, Object?>> _viaTransport(
    HermesGatewayTransport transport,
    String method,
    Map<String, Object?> params,
  ) => transport.request(method, params);

  /// For telemetry events; the run's server attributes are on it.
  AppEventLogger get events => hermes.repositories.telemetry.events;
}

/// How a gateway request is sent; tests stand in for the socket's failures.
typedef GatewayRequest = Future<Map<String, Object?>> Function(
  HermesGatewayTransport transport,
  String method,
  Map<String, Object?> params,
);

/// One independent piece of a run.
abstract class BackgroundStep {
  const BackgroundStep();

  /// Never given text, titles or ids to record: only counts come back.
  Future<StepCounts> run(BackgroundContext context);
}

/// What earlier runs told the user about, the newest
/// [kMaxAnnouncedRequests] entries: request ids, and a key for each wait
/// (`g:` for one announced without a request id, `a:` for one announced with
/// its approvals). Only background runs write it: a request the app already
/// showed in front may be announced once more, and that notification
/// replaces the chat's earlier one.
class AnnouncedRequests {
  AnnouncedRequests({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  final _remembered = <String>{};

  Future<Set<String>> read() async => {...await _read(), ..._remembered};

  /// Remembers [ids] after persistence succeeds; storage failures propagate.
  Future<void> add(Iterable<String> ids) async {
    final added = ids.toSet();
    if (added.isEmpty) return;
    await persist(added);
    _remembered
      ..removeAll(added)
      ..addAll(added);
    while (_remembered.length > kMaxAnnouncedRequests) {
      _remembered.remove(_remembered.first);
    }
  }

  @visibleForTesting
  Future<void> persist(Set<String> added) async {
    final kept = [
      for (final id in await _read())
        if (!added.contains(id)) id,
      ...added,
    ];
    await _prefs.setStringList(
      _announcedKey,
      kept.length > kMaxAnnouncedRequests
          ? kept.sublist(kept.length - kMaxAnnouncedRequests)
          : kept,
    );
  }

  Future<List<String>> _read() async {
    try {
      return await _prefs.getStringList(_announcedKey) ?? const [];
    } on Object {
      return const [];
    }
  }
}

/// A session that waits for the user, with what it waits for.
class _Waiting {
  const _Waiting({
    required this.profile,
    required this.key,
    required this.title,
    required this.kind,
    required this.requestId,
    required this.waitKey,
    this.approval,
  });

  /// Null on a server without profiles.
  final String? profile;
  final String key;
  final String title;
  final PendingKind kind;
  final String requestId;

  /// One wait of one session: the same whatever Hermes could tell of it.
  final String waitKey;
  final ApprovalRequest? approval;
}

class _ProfileRead {
  const _ProfileRead.ok(this.waiting) : ok = true;
  const _ProfileRead.failed() : ok = false, waiting = const [];

  final bool ok;
  final List<_Waiting> waiting;
}

/// Lists each profile's live sessions, reads the approvals of those that
/// wait, and announces every request not announced before.
class OpenRequestsStep extends BackgroundStep {
  OpenRequestsStep({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _found = Completer<List<PendingRequest>?>();

  /// The open requests of every profile; null when they could not all be
  /// read, or the step did not get to say.
  Future<List<PendingRequest>?> get found => _found.future;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    try {
      final profiles = await context.hermes.profiles();
      final reads = await Future.wait([
        for (final profile in profiles) _read(context, profile),
      ]);
      final waiting = [for (final read in reads) ...read.waiting];
      final announced = await _announce(context, waiting);
      if (reads.any((read) => !read.ok)) {
        throw const _PartialRead();
      }
      final seenAt = _now();
      _found.complete([
        for (final w in waiting)
          PendingRequest(
            profile: w.profile ?? kDefaultProfile,
            threadId: w.key,
            threadTitle: w.title,
            kind: w.kind,
            requestId: w.requestId,
            createdAt: seenAt,
          ),
      ]);
      return StepCounts(newRequests: announced);
    } finally {
      if (!_found.isCompleted) _found.complete(null);
    }
  }

  /// One profile's waiting sessions. A profile the server refuses to list is
  /// a failed read, which keeps the stored requests as they were.
  Future<_ProfileRead> _read(BackgroundContext context, String? profile) async {
    try {
      final listed = await context.request('session.active_list', {
        'profile': ?profile,
      });
      final rows = listed['sessions'];
      final sessions = await Future.wait([
        if (rows is List)
          for (final row in rows)
            if (row is Map && row['status'] == 'waiting')
              _waitingIn(context, profile, row.cast<String, Object?>()),
      ]);
      return _ProfileRead.ok([for (final session in sessions) ...session]);
    } on Object {
      // One profile's timeout or refusal must not silence the others.
      return const _ProfileRead.failed();
    }
  }

  Future<List<_Waiting>> _waitingIn(
    BackgroundContext context,
    String? profile,
    Map<String, Object?> session,
  ) async {
    final id = session['id'];
    final key = session['session_key'];
    if (id is! String || key is! String || key.isEmpty) return const [];
    final rawTitle = session['title'];
    final title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : kUnnamedChatLabel;
    // Hermes lists approvals only; a clarify, secret or sudo request has no
    // id of its own, so a wait is told by its session and turn.
    final waitKey = '${profile ?? ''}/$key/${_turn(session)}';
    final approvals = await _approvals(context, profile, id);
    if (approvals.isEmpty) {
      return [
        _Waiting(
          profile: profile,
          key: key,
          title: title,
          kind: PendingKind.input,
          requestId: 'waiting:$waitKey',
          waitKey: waitKey,
        ),
      ];
    }
    return [
      for (final approval in approvals)
        _Waiting(
          profile: profile,
          key: key,
          title: title,
          kind: PendingKind.approval,
          requestId: approval.requestId,
          waitKey: waitKey,
          approval: approval,
        ),
    ];
  }

  /// What marks the turn a session is waiting in: its message count, else
  /// when it last moved, else the hour, so that a server that reports neither
  /// is announced once an hour rather than never again.
  String _turn(Map<String, Object?> session) {
    return switch ((session['message_count'], session['last_active'])) {
      (final int count, _) => 'm$count',
      (_, final num active) => 't${active.floor()}',
      _ => 'h${_now().millisecondsSinceEpoch ~/ Duration.millisecondsPerHour}',
    };
  }

  /// The approvals a session waits on, without their commands. A server that
  /// refuses the question is the same as one that lists none; that is
  /// counted, by code only.
  Future<List<ApprovalRequest>> _approvals(
    BackgroundContext context,
    String? profile,
    String sessionId,
  ) async {
    final Map<String, Object?> result;
    try {
      result = await context.request('approval.pending', {
        'session_id': sessionId,
        'profile': ?profile,
      });
    } on GatewayRpcException catch (error) {
      try {
        context.events('background.requests_unreadable', {'code': error.code});
      } on Object {
        // Telemetry must not break the run.
      }
      return const [];
    }
    final rows = result['approvals'];
    return [
      if (rows is List)
        for (final row in rows)
          if (row is Map &&
              row['request_id'] is String &&
              (row['request_id'] as String).isNotEmpty)
            ApprovalRequest(
              requestId: row['request_id'] as String,
              command: '',
              description: '',
              choices: row['choices'] is List
                  ? (row['choices'] as List).whereType<String>().toList()
                  : const [],
            ),
    ];
  }

  /// Marks requests announced only after their posting attempt is accepted.
  /// While the app is in front it announces nothing: the app does.
  Future<int> _announce(
    BackgroundContext context,
    List<_Waiting> waiting,
  ) async {
    var accepted = 0;
    var failed = 0;
    var marksFailed = 0;
    void report() {
      context.hermes
        ..annotate('requests.post_accepted', accepted)
        ..annotate('requests.post_failed', failed)
        ..annotate('requests.mark_failed', marksFailed);
    }

    void recordFailure(String event, {String? reason, String? errorType}) {
      try {
        context.events(event, {'reason': ?reason, 'error.type': ?errorType});
      } on Object {
        // Telemetry failure cannot prevent other chat alerts.
      }
    }

    report();
    if (!context.notificationsOn || waiting.isEmpty) return 0;
    if (await context.isAppInFront()) return 0;
    final known = await context.announced.read();
    final fresh = [
      for (final w in waiting)
        if (_isNew(w, known)) w,
    ];
    if (fresh.isEmpty) return 0;
    final lockOn = await context.appLockOn();
    final chats = <(String?, String), List<_Waiting>>{};
    for (final w in fresh) {
      (chats[(w.profile, w.key)] ??= []).add(w);
    }
    var announced = 0;
    for (final requests in chats.values) {
      final result = await context.notifications.post(
        _notification(requests.first, lockOn),
      );
      if (result.status == NotificationPostStatus.accepted) {
        accepted++;
        report();
        try {
          await context.announced.add([
            for (final request in requests) ..._marks(request),
          ]);
          announced += requests.length;
        } on Object catch (error) {
          marksFailed++;
          report();
          recordFailure(
            'background.request_alert.mark_failed',
            errorType: error.runtimeType.toString(),
          );
        }
      } else {
        failed++;
        report();
        recordFailure(
          'background.request_alert.post_failed',
          reason: result.status.name,
          errorType: result.errorType,
        );
      }
    }
    return announced;
  }

  /// A request is new unless it, or the wait it belongs to, was announced:
  /// a wait told generically is not told again once its approval is known,
  /// nor the other way round. A second approval of one turn is still new.
  bool _isNew(_Waiting w, Set<String> known) {
    if (known.contains('g:${w.waitKey}')) return false;
    return w.approval == null
        ? !known.contains('a:${w.waitKey}')
        : !known.contains(w.requestId);
  }

  List<String> _marks(_Waiting w) =>
      w.approval == null ? ['g:${w.waitKey}'] : [w.requestId, 'a:${w.waitKey}'];

  /// The generic text and the buttons of #587's categories; the command is
  /// never read into either.
  AttentionNotification _notification(_Waiting w, bool lockOn) {
    final approval = w.approval;
    return AttentionNotification(
      threadId: w.key,
      profile: w.profile,
      title: w.title,
      body: approval == null ? kNeedsYouBody : kApprovalBody,
      category: approval == null
          ? null
          : requestCategoryFor(approval, appLock: lockOn),
      request: approval == null || lockOn
          ? null
          : pendingRequestFor(approval, raisedAsEvent: true),
    );
  }
}

class _PartialRead implements Exception {
  const _PartialRead();
}

/// Rebuilds the snapshot with the requests the other step found, or the
/// stored ones when it did not find them in time.
class SnapshotStep extends BackgroundStep {
  SnapshotStep(
    this._requests, {
    this.requestsWait = const Duration(seconds: 10),
  });

  final OpenRequestsStep _requests;

  /// How long the build waits for the requests before it goes on without.
  final Duration requestsWait;

  final _written = Completer<SurfaceSnapshot?>();

  /// The snapshot this step stored; null when it was dropped or the step
  /// failed.
  Future<SurfaceSnapshot?> get written => _written.future;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    try {
      final pending = await _requests.found.timeout(
        requestsWait,
        onTimeout: () => null,
      );
      final snapshot = await context.hermes.refreshSnapshot(pending: pending);
      _written.complete(snapshot);
      return const StepCounts();
    } finally {
      if (!_written.isCompleted) _written.complete(null);
    }
  }
}

/// What a run is wired to. A run uses the device's own parts unless told
/// otherwise, which only tests do.
class BackgroundRefreshDeps {
  const BackgroundRefreshDeps({
    this.headless,
    this.statusStore,
    this.notifications,
    this.announced,
    this.notificationsEnabled,
    this.appLockOn,
    this.steps,
    this.cancelSchedule,
    this.appInFront,
    this.request,
    this.timeout = kBackgroundRefreshBudget,
    this.stepTimeout = kBackgroundStepBudget,
  });

  final HeadlessDeps? headless;
  final BackgroundCheckStore? statusStore;
  final NotificationService? notifications;
  final AnnouncedRequests? announced;
  final Future<bool> Function()? notificationsEnabled;
  final Future<bool> Function()? appLockOn;

  /// The steps to run; the requests and snapshot steps by default.
  final List<BackgroundStep> Function()? steps;

  /// Cancels the periodic run when nobody is signed in.
  final Future<void> Function()? cancelSchedule;

  /// Whether the app is in front; asked over its presence port by default.
  final Future<bool> Function()? appInFront;

  /// Sends the gateway requests of the steps; the shared socket by default.
  final GatewayRequest? request;
  final Duration timeout;
  final Duration stepTimeout;
}

List<BackgroundStep> _defaultSteps() {
  final requests = OpenRequestsStep();
  final snapshot = SnapshotStep(requests);
  return [
    requests,
    snapshot,
    SpotlightRefreshStep(snapshot),
    BadgeRefreshStep(snapshot),
    ShortcutsRefreshStep(snapshot),
    RunningRepliesStep(),
    ScheduleAlertsStep(),
    AgentMessagesStep(),
  ];
}

Future<bool> _notificationsEnabled() async {
  final settings = NotificationSettings();
  await settings.load();
  return settings.enabled;
}

/// Runs the background refresh and says how it ended. Nothing is thrown, and
/// no outcome signs the user out: nothing stored cancels the periodic run;
/// a rejected refresh token, locked and unreachable leave everything as it is
/// for the next one.
Future<HeadlessOutcome<void>> runBackgroundRefresh({
  BackgroundRefreshDeps deps = const BackgroundRefreshDeps(),
}) async {
  final statusStore = deps.statusStore ?? BackgroundCheckStore();
  final attempt = await _checkStatusWithinBudget(statusStore.begin);
  var partial = false;
  var matchingAccount = true;
  final outcome = await withHeadlessHermes<void>(
    (hermes) async {
      matchingAccount = attempt == null || attempt.account == hermes.accountKey;
      final context = BackgroundContext(
        hermes: hermes,
        notificationsOn:
            await (deps.notificationsEnabled ?? _notificationsEnabled)(),
        notifications:
            deps.notifications ?? LocalNotificationService(background: true),
        announced: deps.announced ?? AnnouncedRequests(),
        appLockOn: deps.appLockOn ?? AppLockController.savedEnabled,
        inFront: deps.appInFront ?? appInFront,
        request: deps.request,
        stepTimeout: deps.stepTimeout,
      );
      var newRequests = 0;
      var repliesFinished = 0;
      var schedulesRan = 0;
      var messagesFound = 0;
      var failed = 0;
      void report() {
        hermes
          ..annotate('requests.new', newRequests)
          ..annotate('replies.finished', repliesFinished)
          ..annotate('schedules.ran', schedulesRan)
          ..annotate('agent_messages.found', messagesFound)
          ..annotate('steps_failed', failed);
      }

      report();
      await Future.wait([
        for (final step in (deps.steps ?? _defaultSteps)())
          _settle(step, context, deps.stepTimeout).then((counts) {
            if (counts == null) {
              failed++;
              partial = true;
            } else {
              newRequests += counts.newRequests;
              repliesFinished += counts.repliesFinished;
              schedulesRan += counts.schedulesRan;
              messagesFound += counts.messagesFound;
            }
            report();
          }),
      ]);
    },
    task: 'refresh',
    timeout: deps.timeout,
    deps: deps.headless,
  );
  // Only an empty storage cancels: a refresh token the server rejected may
  // just be one the app in front has rotated, and the schedule must outlive it.
  if (outcome is HeadlessSignedOut<void> && outcome.nothingStored) {
    await (deps.cancelSchedule ?? cancelBackgroundRefresh)();
  }
  if (matchingAccount) {
    await _checkStatusWithinBudget(
      () => statusStore.finish(attempt, switch (outcome) {
        HeadlessDone<void>() =>
          partial
              ? BackgroundCheckOutcome.partial
              : BackgroundCheckOutcome.completed,
        HeadlessLocked<void>() => BackgroundCheckOutcome.locked,
        HeadlessSignedOut<void>() => BackgroundCheckOutcome.signedOut,
        HeadlessUnreachable<void>() => BackgroundCheckOutcome.unreachable,
      }),
    );
  }
  return outcome;
}

Future<T?> _checkStatusWithinBudget<T>(Future<T> Function() operation) async {
  try {
    // Optional bookkeeping must leave time for the OS-limited refresh work.
    return await operation().timeout(const Duration(milliseconds: 500));
  } on Object {
    return null;
  }
}

/// The counts of [step], or null when it failed or took longer than [limit].
Future<StepCounts?> _settle(
  BackgroundStep step,
  BackgroundContext context,
  Duration limit,
) async {
  try {
    return await step.run(context).timeout(limit);
  } on Object {
    return null;
  }
}
