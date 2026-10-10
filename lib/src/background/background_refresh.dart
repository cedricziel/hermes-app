/// What one periodic background run does: look for open requests, tell the
/// user of new ones, and refresh what the system surfaces show.
///
/// A run is a list of independent [BackgroundStep]s. One that fails or runs
/// too long is counted and does not stop the others.
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_lock/app_lock_controller.dart';
import '../chat/chat_models.dart';
import '../chat/gateway/gateway_rpc_client.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../notifications/attention_policy.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../notifications/request_notifications.dart'
    show pendingRequestFor, requestCategoryFor;
import '../surfaces/chat_hints.dart' show kUnnamedChatLabel;
import '../surfaces/surface_snapshot.dart';
import 'background_scheduler.dart';
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
  const StepCounts({this.newRequests = 0});

  /// Open requests announced for the first time.
  final int newRequests;
}

/// Everything a step may use. The gateway socket is shared by all steps.
class BackgroundContext {
  BackgroundContext({
    required this.hermes,
    required this.notificationsOn,
    required this.notifications,
    required this.announced,
    required this._appLockOn,
  });

  final HeadlessHermes hermes;

  /// Whether the user wants notifications at all.
  final bool notificationsOn;
  final NotificationService notifications;
  final AnnouncedRequests announced;
  final Future<bool> Function() _appLockOn;

  HermesGatewayTransport? _transport;
  Future<bool>? _lockOn;

  HermesGatewayTransport get transport => _transport ??= hermes.transport();

  /// Whether App Lock is on, read once: unreadable counts as on.
  Future<bool> appLockOn() => _lockOn ??= _appLockOn();
}

/// One independent piece of a run.
abstract class BackgroundStep {
  const BackgroundStep();

  /// Never given text, titles or ids to record: only counts come back.
  Future<StepCounts> run(BackgroundContext context);
}

/// The ids of the requests earlier runs told the user about, the newest
/// [kMaxAnnouncedRequests] of them. Only background runs write it: a request
/// the app already showed in front may be announced once more, and that
/// notification replaces the chat's earlier one.
class AnnouncedRequests {
  AnnouncedRequests({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  Future<Set<String>> read() async => (await _read()).toSet();

  Future<void> add(Iterable<String> ids) async {
    final added = ids.toSet();
    if (added.isEmpty) return;
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
    this.approval,
  });

  /// Null on a server without profiles.
  final String? profile;
  final String key;
  final String title;
  final PendingKind kind;
  final String requestId;
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
      final listed = await context.transport.request('session.active_list', {
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
    } on GatewayRpcException {
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
    final approvals = await _approvals(context, profile, id);
    if (approvals.isEmpty) {
      // Hermes lists approvals only; a clarify, secret or sudo request has no
      // id of its own, so one wait is told by when the session last moved.
      return [
        _Waiting(
          profile: profile,
          key: key,
          title: title,
          kind: PendingKind.input,
          requestId: 'waiting:$key:${session['last_active']}',
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
          approval: approval,
        ),
    ];
  }

  /// The approvals a session waits on, without their commands. A server that
  /// refuses the question is the same as one that lists none.
  Future<List<ApprovalRequest>> _approvals(
    BackgroundContext context,
    String? profile,
    String sessionId,
  ) async {
    final Map<String, Object?> result;
    try {
      result = await context.transport.request('approval.pending', {
        'session_id': sessionId,
        'profile': ?profile,
      });
    } on GatewayRpcException {
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

  /// Posts one notification per chat that has a request not announced
  /// before, and remembers them. Returns how many requests were new.
  Future<int> _announce(
    BackgroundContext context,
    List<_Waiting> waiting,
  ) async {
    if (!context.notificationsOn || waiting.isEmpty) return 0;
    final known = await context.announced.read();
    final fresh = [
      for (final w in waiting)
        if (!known.contains(w.requestId)) w,
    ];
    if (fresh.isEmpty) return 0;
    final lockOn = await context.appLockOn();
    final posted = <(String?, String)>{};
    for (final w in fresh) {
      if (!posted.add((w.profile, w.key))) continue;
      await context.notifications.show(_notification(w, lockOn));
    }
    await context.announced.add([for (final w in fresh) w.requestId]);
    return fresh.length;
  }

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

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    final pending = await _requests.found.timeout(
      requestsWait,
      onTimeout: () => null,
    );
    await context.hermes.refreshSnapshot(pending: pending);
    return const StepCounts();
  }
}

/// What a run is wired to. A run uses the device's own parts unless told
/// otherwise, which only tests do.
class BackgroundRefreshDeps {
  const BackgroundRefreshDeps({
    this.headless,
    this.notifications,
    this.announced,
    this.notificationsEnabled,
    this.appLockOn,
    this.steps,
    this.cancelSchedule,
    this.timeout = kBackgroundRefreshBudget,
    this.stepTimeout = kBackgroundStepBudget,
  });

  final HeadlessDeps? headless;
  final NotificationService? notifications;
  final AnnouncedRequests? announced;
  final Future<bool> Function()? notificationsEnabled;
  final Future<bool> Function()? appLockOn;

  /// The steps to run; the requests and snapshot steps by default.
  final List<BackgroundStep> Function()? steps;

  /// Cancels the periodic run when nobody is signed in.
  final Future<void> Function()? cancelSchedule;
  final Duration timeout;
  final Duration stepTimeout;
}

List<BackgroundStep> _defaultSteps() {
  final requests = OpenRequestsStep();
  return [requests, SnapshotStep(requests)];
}

Future<bool> _notificationsEnabled() async {
  final settings = NotificationSettings();
  await settings.load();
  return settings.enabled;
}

/// Runs the background refresh and says how it ended. Nothing is thrown, and
/// no outcome signs the user out: signed out cancels the periodic run,
/// locked and unreachable leave everything as it is for the next one.
Future<HeadlessOutcome<void>> runBackgroundRefresh({
  BackgroundRefreshDeps deps = const BackgroundRefreshDeps(),
}) async {
  final outcome = await withHeadlessHermes<void>(
    (hermes) async {
      final context = BackgroundContext(
        hermes: hermes,
        notificationsOn:
            await (deps.notificationsEnabled ?? _notificationsEnabled)(),
        notifications:
            deps.notifications ?? LocalNotificationService(background: true),
        announced: deps.announced ?? AnnouncedRequests(),
        appLockOn: deps.appLockOn ?? AppLockController.savedEnabled,
      );
      var newRequests = 0;
      var failed = 0;
      void report() {
        hermes
          ..annotate('requests.new', newRequests)
          ..annotate('steps_failed', failed);
      }

      report();
      await Future.wait([
        for (final step in (deps.steps ?? _defaultSteps)())
          _settle(step, context, deps.stepTimeout).then((counts) {
            if (counts == null) {
              failed++;
            } else {
              newRequests += counts.newRequests;
            }
            report();
          }),
      ]);
    },
    task: 'refresh',
    timeout: deps.timeout,
    deps: deps.headless,
  );
  if (outcome is HeadlessSignedOut<void>) {
    await (deps.cancelSchedule ?? cancelBackgroundRefresh)();
  }
  return outcome;
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
