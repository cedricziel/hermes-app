// Named parameters cannot be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'care_result.dart';
import 'server_care_controller.dart';
import 'server_care_repository.dart';
import 'update_receipt.dart';
import 'update_run_record.dart';

enum UpdatePhase {
  idle,

  /// The person is being asked; nothing is sent yet.
  confirming,
  starting,
  updating,

  /// The dashboard stopped answering; only `/api/health` is read.
  restarting,
  verifying,
  finished,

  /// The update ran, but the server still runs the old code.
  staleServer,

  /// Hermes did not answer for 15 minutes.
  notBack,

  /// Hermes (or its receipt) refused the update.
  refused,

  /// A signed-in call was refused twice: not a failed update.
  unauthorized,
}

/// How a run that [UpdatePhase.finished] ended, read from the receipt.
enum UpdateResult { success, partial, failed, interrupted, unknown }

/// Updates Hermes on the server and follows it until the receipt says how it
/// went.
///
/// `starting -> updating -> restarting -> verifying -> finished`, or one of
/// `staleServer`, `notBack`, `refused`, `unauthorized`. The outcome is decided
/// by the receipt naming this run's action id, never by liveness. The POST is
/// sent once per [start]: a lost answer is "may have started" and is settled
/// by reading, never by sending again. All timing is wall-clock, through the
/// injected clock and delay, so a long suspension lands in [UpdatePhase.notBack]
/// and never in a success nobody read.
class HermesUpdateRun extends ChangeNotifier with SafeNotifier {
  HermesUpdateRun({
    required ServerCareRepository repository,
    UpdateRunStore? store,
    ServerCareController? care,
    Future<void> Function()? probeConnection,
    ConnectionTelemetry telemetry = const ConnectionTelemetry(),
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
    bool Function()? covered,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _repository = repository,
       _store = store,
       _care = care,
       _probeConnection = probeConnection,
       _covered = covered,
       _telemetry = telemetry,
       _breadcrumbs = breadcrumbs,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// How long Hermes is waited for after it stopped answering.
  static const restartWindow = Duration(minutes: 15);

  /// A saved update older than this is read once and dropped on launch.
  static const resumeWindow = Duration(hours: 1);

  /// How long the receipt is waited for once Hermes answers.
  static const receiptWindow = Duration(seconds: 60);

  /// How long a run whose answer was lost waits to see its child running.
  static const lostAnswerWindow = Duration(seconds: 30);
  static const _poll = Duration(seconds: 2);
  static const _firstBackoff = Duration(seconds: 1);
  static const _lastBackoff = Duration(seconds: 10);

  /// How often a run may go from verifying back to restarting.
  static const _maxFlaps = 5;

  final ServerCareRepository _repository;
  final UpdateRunStore? _store;
  final ServerCareController? _care;
  final Future<void> Function()? _probeConnection;
  final ConnectionTelemetry _telemetry;
  final Breadcrumbs _breadcrumbs;
  final bool Function()? _covered;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdateResult? _result;
  Future<void>? _running;
  int _generation = 0;

  String? _actionId;
  String? _versionBefore;
  String? _commitBefore;
  String? _versionNow;
  String? _commitNow;
  String? _postVersion;
  List<String> _reasons = const [];
  List<String> _lines = const [];
  String? _refusalMessage;
  String? _refusalCommand;
  DateTime? _startedAt;
  DateTime? _restartSince;
  bool _lost = false;
  bool _postSent = false;
  bool _resumedAfterLaunch = false;
  bool _nothingStarted = false;
  int _flaps = 0;
  bool _sawRunning = false;
  bool _cameBack = false;
  UpdatePhase _reached = UpdatePhase.starting;
  Span? _span;
  UpdateResult? _staleResult;

  UpdatePhase get phase => _phase;

  /// Set with [UpdatePhase.finished].
  UpdateResult? get result => _result;

  /// True from the moment the request is sent until the run settles.
  bool get busy => switch (_phase) {
    UpdatePhase.starting ||
    UpdatePhase.updating ||
    UpdatePhase.restarting ||
    UpdatePhase.verifying => true,
    _ => false,
  };

  /// Whether the thin banner shows: only while Hermes restarts or is verified.
  bool get showsBanner =>
      _phase == UpdatePhase.restarting || _phase == UpdatePhase.verifying;

  /// The version running before the update, when `/api/health` said.
  String? get versionBefore => _versionBefore;

  /// The version `/api/health` last reported: what is running now.
  String? get versionNow => _versionNow;

  /// The version the receipt says Hermes was updated to.
  String? get postVersion => _postVersion;

  /// With [UpdateResult.partial] and [UpdatePhase.staleServer]: what is left
  /// to do, in Hermes' own words. Shown, never logged.
  List<String> get reasons => _reasons;

  /// The tail of the update's log, for "Show details". Hermes' own text.
  List<String> get lines => _lines;

  /// With [UpdatePhase.refused]: Hermes' message, when it sent one.
  String? get refusalMessage => _refusalMessage;

  /// With [UpdatePhase.refused]: the command to run on the server.
  String? get refusalCommand => _refusalCommand;

  /// The run was picked up from a saved record on launch, so a result was
  /// not observed live (no "ready" banner for it).
  bool get resumedAfterLaunch => _resumedAfterLaunch;

  /// With [UpdatePhase.unauthorized]: the update request itself was refused
  /// for lack of access, so nothing was started and there is nothing to
  /// check. The person dismisses and asks again; the request is never resent.
  bool get nothingStarted => _nothingStarted;

  bool get _isCovered => _covered?.call() ?? false;

  /// When the run started; null when idle.
  DateTime? get startedAt => _startedAt;

  /// Drops Hermes' own words (the log tail, the reasons, a refusal and its
  /// command), for when the app is covered; the page then says only how the
  /// run ended.
  void forgetText() {
    if (_lines.isEmpty &&
        _reasons.isEmpty &&
        _refusalMessage == null &&
        _refusalCommand == null) {
      return;
    }
    _lines = const [];
    _reasons = const [];
    _refusalMessage = null;
    _refusalCommand = null;
    notifyListeners();
  }

  /// The confirmation is open: nothing is sent until [start].
  void beginConfirmation() {
    if (busy || disposed) return;
    _reset();
    _enter(UpdatePhase.confirming);
  }

  /// The person confirmed in the UI.
  void confirmed() => _breadcrumbs('server_care.update.confirmed');

  /// Sends the update once and follows it. While a run is going a second call
  /// joins it and sends nothing; after a run ended it starts a new one.
  Future<void> start() {
    final running = _running;
    if (running != null && busy) return running;
    if (disposed) return Future.value();
    _reset();
    return _launch(_begin);
  }

  /// Goes back to idle from a settled phase. From [UpdatePhase.notBack] this
  /// ends the run.
  void dismiss() {
    if (busy || _phase == UpdatePhase.idle) return;
    if (_phase == UpdatePhase.notBack || _phase == UpdatePhase.unauthorized) {
      unawaited(_store?.clear());
    }
    _reset();
    notifyListeners();
  }

  /// "Keep waiting" after [UpdatePhase.notBack]: another 15 minutes.
  Future<void> keepWaiting() {
    if (_phase != UpdatePhase.notBack || disposed) return Future.value();
    _restartSince = null;
    _startSpan(resumed: false);
    return _launch(() => _follow(_Step.restart));
  }

  /// "Check again" after [UpdatePhase.staleServer] (reads `/api/health`: a new
  /// commit moves to finished) or [UpdatePhase.unauthorized] (reads the
  /// receipt again).
  Future<void> checkAgain() {
    if (disposed) return Future.value();
    switch (_phase) {
      case UpdatePhase.staleServer:
        return _running ?? _launch(_checkStale);
      case UpdatePhase.unauthorized:
        if (_nothingStarted || _running != null) return Future.value();
        _startSpan(resumed: false);
        return _launch(() => _follow(_Step.verify));
      default:
        return Future.value();
    }
  }

  /// Stops following and drops the run: sign-out and server change.
  Future<void> reset() {
    _reset();
    notifyListeners();
    return _store?.clear() ?? Future.value();
  }

  /// On launch: picks up an update a previous run of the app saved. One
  /// younger than an hour resumes at [UpdatePhase.updating] (the action's
  /// status and the receipt tell where it is); an older one is read once and
  /// dropped.
  Future<void> resume() async {
    final store = _store;
    if (store == null || busy || disposed) return;
    final record = await store.read();
    if (record == null || busy || disposed) return;
    _reset();
    _startedAt = record.startedAt;
    _actionId = record.actionId;
    _versionBefore = record.versionBefore;
    _commitBefore = record.commitBefore;
    _resumedAfterLaunch = true;
    // A record with no action id is one whose request may not have been
    // answered: its child must be seen running before anything is credited.
    _lost = record.actionId == null;
    if (_now().difference(record.startedAt) < resumeWindow) {
      _startSpan(resumed: true);
      await _launch(() => _follow(_Step.update));
    } else {
      await _launch(_readOld);
    }
  }

  @override
  void dispose() {
    _endOpenSpan();
    _generation++;
    super.dispose();
  }

  // -- run ------------------------------------------------------------------

  Future<void> _launch(Future<void> Function() body) {
    late final Future<void> done;
    done = body().whenComplete(() {
      if (identical(_running, done)) _running = null;
    });
    _running = done;
    return done;
  }

  bool _stale(int generation) => disposed || generation != _generation;

  /// Ends a span the run still holds: only an interrupted or cancelled run
  /// has one.
  void _endOpenSpan() {
    if (_span == null) return;
    _report(_postSent ? 'interrupted' : 'cancelled');
  }

  void _reset() {
    _endOpenSpan();
    _generation++;
    _running = null;
    _phase = UpdatePhase.idle;
    _result = null;
    _actionId = null;
    _versionBefore = null;
    _commitBefore = null;
    _versionNow = null;
    _commitNow = null;
    _postVersion = null;
    _reasons = const [];
    _lines = const [];
    _refusalMessage = null;
    _refusalCommand = null;
    _startedAt = null;
    _restartSince = null;
    _lost = false;
    _postSent = false;
    _resumedAfterLaunch = false;
    _nothingStarted = false;
    _flaps = 0;
    _sawRunning = false;
    _cameBack = false;
    _staleResult = null;
    _reached = UpdatePhase.starting;
    _span = null;
  }

  void _enter(UpdatePhase phase) {
    if (disposed) return;
    _phase = phase;
    if (busy && phase.index > _reached.index) _reached = phase;
    notifyListeners();
  }

  Future<void> _begin() async {
    final generation = _generation;
    _startedAt = _now();
    _startSpan(resumed: false);
    _enter(UpdatePhase.starting);
    final health = await _repository.health();
    if (_stale(generation)) return;
    if (health case CareOk(:final value)) {
      _versionBefore = value.version;
      _commitBefore = value.commit;
      _versionNow = value.version;
      _commitNow = value.commit;
    }
    // Saved before the request, without an action id: a kill while it is in
    // flight resumes as an answer that was lost.
    await _store?.write(_record());
    if (_stale(generation)) return;
    _postSent = true;
    final answer = await _repository.startUpdate();
    if (_stale(generation)) return;
    switch (answer) {
      case CareOk(value: final UpdateRefused refused):
        _setRefusal(refused.message, refused.command);
        return _settle(UpdatePhase.refused, 'refused');
      case CareOk(value: final UpdateStarted started):
        _actionId = started.actionId;
      case CareFailed(kind: CareFailureKind.unauthorized):
        // Nothing was started, and the request is never resent.
        _nothingStarted = true;
        await _store?.clear();
        if (_stale(generation)) return;
        return _settle(UpdatePhase.unauthorized, 'unauthorized');
      case CareFailed(
        kind: CareFailureKind.offline ||
            CareFailureKind.unreadable ||
            CareFailureKind.server,
        message: null,
      ):
        // The answer is lost: it may have started. Never send it again.
        _lost = true;
      case CareFailed(:final message):
        _setRefusal(message, null);
        return _settle(UpdatePhase.refused, 'refused');
      case CareUnsupported():
        return _settle(UpdatePhase.refused, 'refused');
    }
    if (_actionId != null) await _store?.write(_record());
    if (_stale(generation)) return;
    await _follow(_Step.update);
  }

  UpdateRunRecord _record() => UpdateRunRecord(
    startedAt: _startedAt!,
    actionId: _actionId,
    versionBefore: _versionBefore,
    commitBefore: _commitBefore,
  );

  void _setRefusal(String? message, String? command) {
    if (_isCovered) return;
    _refusalMessage = message;
    _refusalCommand = command;
  }

  void _setLines(List<String> lines) {
    if (lines.isNotEmpty && !_isCovered) _lines = lines;
  }

  /// An update saved long ago: the receipt is read once. When it names the
  /// action its outcome is shown; otherwise there is nothing to say.
  Future<void> _readOld() async {
    final generation = _generation;
    _enter(UpdatePhase.verifying);
    final health = await _repository.health();
    if (_stale(generation)) return;
    if (health case CareOk(:final value)) _noteHealth(value);
    final receipt = await _repository.updateReceipt();
    if (_stale(generation)) return;
    if (receipt case CareOk(:final value?)
        when _isMine(value) && _resolve(value)) {
      return;
    }
    await _store?.clear();
    if (_stale(generation)) return;
    _reset();
    notifyListeners();
  }

  /// Runs the steps until one settles the run.
  Future<void> _follow(_Step first) async {
    final generation = _generation;
    _Step? step = first;
    while (step != null) {
      step = switch (step) {
        _Step.update => await _update(generation),
        _Step.restart => await _restart(generation),
        _Step.verify => await _verify(generation),
      };
      if (_stale(generation)) return;
    }
  }

  /// Polls the update's action until it stops, the dashboard goes away or the
  /// receipt can be read.
  Future<_Step?> _update(int generation) async {
    _enter(UpdatePhase.updating);
    final from = _now();
    while (true) {
      final status = await _repository.actionStatus(
        CareAction.hermesUpdate,
        lines: 60,
      );
      if (_stale(generation)) return null;
      switch (status) {
        case CareOk(:final value):
          _setLines(value.lines);
          if (value.running) {
            _sawRunning = true;
          } else if (!_lost || _sawRunning) {
            // An answer that was lost cannot say whether this status is the
            // run's own or an earlier one's until its child was seen running.
            _actionId ??= value.actionId;
            return _afterStopped(generation, value.exitCode);
          }
        case CareFailed(kind: CareFailureKind.unauthorized):
          _settle(UpdatePhase.unauthorized, 'unauthorized');
          return null;
        case CareFailed() || CareUnsupported():
          return _Step.restart;
      }
      if (_lost &&
          !_sawRunning &&
          _now().difference(from) >= lostAnswerWindow) {
        if (_resumedAfterLaunch) {
          await _dropUnseen(generation);
        } else {
          _finish(UpdateResult.unknown);
        }
        return null;
      }
      notifyListeners();
      await _delay(_poll);
      if (_stale(generation)) return null;
    }
  }

  /// A saved run whose request was never seen running: there is nothing to
  /// report, so the record is dropped without a word.
  Future<void> _dropUnseen(int generation) async {
    await _store?.clear();
    if (_stale(generation)) return;
    _reset();
    notifyListeners();
  }

  /// The action stopped: tell a restart that was missed from one that did not
  /// happen.
  Future<_Step?> _afterStopped(int generation, int? exitCode) async {
    final health = await _repository.health();
    if (_stale(generation)) return null;
    switch (health) {
      case CareOk(:final value):
        _noteHealth(value);
        if (_changed(value)) {
          _cameBack = true;
          return _Step.verify;
        }
        if (exitCode != null && exitCode != 0) {
          return _failedBeforeRestart(generation);
        }
        return _Step.verify;
      case CareFailed() || CareUnsupported():
        _cameBack = true;
        return _Step.restart;
    }
  }

  /// A non-zero exit with the old dashboard still up: the receipt is read
  /// once, and without one the run failed.
  Future<_Step?> _failedBeforeRestart(int generation) async {
    final receipt = await _repository.updateReceipt();
    if (_stale(generation)) return null;
    if (receipt case CareOk(:final value?) when _isMine(value)) {
      if (_resolve(value)) return null;
    }
    _finish(UpdateResult.failed);
    return null;
  }

  /// Reads `/api/health` and nothing else until Hermes answers. The window
  /// belongs to this stay in `restarting`; one more read follows a wait that
  /// outlasted it, since a suspended app may have slept through the return.
  Future<_Step?> _restart(int generation) async {
    _enter(UpdatePhase.restarting);
    final since = _restartSince ??= _now();
    var backoff = _firstBackoff;
    try {
      while (true) {
        final health = await _repository.health();
        if (_stale(generation)) return null;
        if (health case CareOk(:final value)) {
          _noteHealth(value);
          if (_changed(value)) {
            _cameBack = true;
            return _Step.verify;
          }
          // The same code answers: either Hermes restarted onto it or it
          // never stopped. A child still running means the update is not
          // over.
          final status = await _repository.actionStatus(
            CareAction.hermesUpdate,
            lines: 60,
          );
          if (_stale(generation)) return null;
          if (status case CareOk(:final value) when value.running) {
            _setLines(value.lines);
            return _Step.update;
          }
          return _Step.verify;
        }
        _cameBack = true;
        if (_now().difference(since) >= restartWindow) {
          _settle(UpdatePhase.notBack, 'not_back');
          return null;
        }
        await _delay(backoff);
        if (_stale(generation)) return null;
        backoff = backoff * 2 > _lastBackoff ? _lastBackoff : backoff * 2;
      }
    } finally {
      _restartSince = null;
    }
  }

  /// Reads the receipt until it names this run's action.
  Future<_Step?> _verify(int generation) async {
    _enter(UpdatePhase.verifying);
    if (_actionId == null && _lost && _sawRunning) {
      // The answer to the POST was lost but its child was seen running: the
      // finished run's id, from the same log the receipt comes from, is its.
      final status = await _repository.actionStatus(
        CareAction.hermesUpdate,
        lines: 60,
      );
      if (_stale(generation)) return null;
      if (status case CareOk(:final value) when !value.running) {
        _actionId = value.actionId;
      }
    }
    final from = _now();
    while (true) {
      final receipt = await _repository.updateReceipt();
      if (_stale(generation)) return null;
      switch (receipt) {
        case CareOk(:final value):
          if (value != null && _isMine(value) && _resolve(value)) return null;
        case CareFailed(kind: CareFailureKind.unauthorized):
          _settle(UpdatePhase.unauthorized, 'unauthorized');
          return null;
        case CareFailed():
          // Only a health read that fails too means Hermes went away again;
          // a receipt route that keeps failing on a healthy server is read
          // until the window ends, never in a tight loop.
          final health = await _repository.health();
          if (_stale(generation)) return null;
          if (health case CareOk(:final value)) {
            _noteHealth(value);
          } else {
            _cameBack = true;
            if (++_flaps > _maxFlaps) {
              _finish(UpdateResult.unknown);
              return null;
            }
            await _delay(_poll);
            if (_stale(generation)) return null;
            return _Step.restart;
          }
        case CareUnsupported():
          break;
      }
      if (_now().difference(from) >= receiptWindow) {
        _finish(UpdateResult.unknown);
        return null;
      }
      await _delay(_poll);
      if (_stale(generation)) return null;
    }
  }

  Future<void> _checkStale() async {
    final generation = _generation;
    final health = await _repository.health();
    if (_stale(generation)) return;
    if (health case CareOk(:final value)) {
      _noteHealth(value);
      if (_changed(value)) {
        _cameBack = true;
        _finish(_staleResult ?? UpdateResult.success);
        return;
      }
    }
    notifyListeners();
  }

  // -- reading --------------------------------------------------------------

  bool _isMine(UpdateReceiptSummary receipt) =>
      _actionId != null && receipt.actionId == _actionId;

  void _noteHealth(ServerHealth health) {
    _versionNow = health.version ?? _versionNow;
    _commitNow = health.commit ?? _commitNow;
  }

  /// Different code answers than before the update.
  bool _changed(ServerHealth health) {
    final commit = health.commit;
    if (commit != null && _commitBefore != null) {
      return commit != _commitBefore;
    }
    final version = health.version;
    return version != null &&
        _versionBefore != null &&
        version != _versionBefore;
  }

  /// Whether the process answering is still the old code, judged from the
  /// commits: the receipt's `post_sha` is what it should run now, its
  /// `pre_sha` (or the commit read before) is what it ran. Hermes may send
  /// either as a short or a full SHA, so they are compared by prefix.
  bool _serverStale(UpdateReceiptSummary receipt) {
    final now = _commitNow;
    if (now == null) return false;
    final post = receipt.postSha;
    if (post != null && _sameSha(now, post)) return false;
    final ranBefore =
        _sameSha(now, receipt.preSha) || _sameSha(now, _commitBefore);
    // Without a post_sha, a restart that was seen settles it.
    return ranBefore && (post != null || !_cameBack);
  }

  static bool _sameSha(String a, String? b) {
    if (b == null || b.isEmpty || a.isEmpty) return false;
    final x = a.toLowerCase();
    final y = b.toLowerCase();
    return x.startsWith(y) || y.startsWith(x);
  }

  /// Settles the run from a receipt of this action; false when it does not
  /// say yet (`running`, or an outcome this app does not know).
  bool _resolve(UpdateReceiptSummary receipt) {
    switch (receipt.outcome) {
      case UpdateOutcome.success || UpdateOutcome.partial:
        _postVersion = receipt.postVersion;
        _reasons = _isCovered
            ? const []
            : [
                for (final f in [
                  ?receipt.userAction,
                  if (receipt.userAction == null) ...receipt.followups,
                ])
                  ?f.reason,
              ];
        final result = receipt.outcome == UpdateOutcome.success
            ? UpdateResult.success
            : UpdateResult.partial;
        if (_serverStale(receipt)) {
          // Updated, but the old process still answers.
          _staleResult = result;
          _settle(UpdatePhase.staleServer, 'stale_server');
        } else {
          _finish(result);
        }
        return true;
      case UpdateOutcome.failed:
        _finish(UpdateResult.failed);
        return true;
      case UpdateOutcome.interrupted:
        _finish(UpdateResult.interrupted);
        return true;
      case UpdateOutcome.refused:
        _settle(UpdatePhase.refused, 'refused');
        return true;
      case UpdateOutcome.running || UpdateOutcome.other:
        return false;
    }
  }

  // -- ending ---------------------------------------------------------------

  void _finish(UpdateResult result) {
    _result = result;
    _settle(UpdatePhase.finished, result.name);
  }

  /// Enters a phase the run stops in, reports it, and (for a phase that
  /// resolves the update) drops the saved record and reads the server again.
  void _settle(UpdatePhase phase, String outcome) {
    final keepsRecord =
        phase == UpdatePhase.notBack || phase == UpdatePhase.unauthorized;
    _enter(phase);
    _report(outcome);
    if (!keepsRecord) unawaited(_afterResolved());
  }

  Future<void> _afterResolved() async {
    await _store?.clear();
    try {
      await _probeConnection?.call();
    } on Object {
      // The probe is a refresh; a failure leaves the old reading.
    }
    try {
      await _care?.refresh();
    } on Object {
      // Same.
    }
  }

  void _startSpan({required bool resumed}) {
    _reached = UpdatePhase.starting;
    _span = null;
    _quiet(
      () => _span = _telemetry.tracer?.startSpan(
        'server_care.update',
        attributes: {
          ..._telemetry.serverAttributes,
          'resumed_after_launch': resumed,
        },
      ),
    );
  }

  void _report(String outcome) {
    final started = _startedAt;
    final duration = started == null
        ? '<1m'
        : _bucket(_now().difference(started));
    final span = _span;
    _span = null;
    _quiet(() {
      span?.setAttribute('outcome', outcome);
      span?.setAttribute('phase_reached', _reached.name);
      span?.setAttribute('came_back', _cameBack);
      span?.setAttribute('duration', duration);
      span?.end();
    });
    _quiet(
      () => _telemetry.events('server_care.update_finished', {
        'outcome': outcome,
        'came_back': _cameBack,
        'duration': duration,
      }),
    );
  }

  static String _bucket(Duration d) => switch (d.inSeconds) {
    < 60 => '<1m',
    < 180 => '1-3m',
    < 600 => '3-10m',
    _ => '>10m',
  };

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}

enum _Step { update, restart, verify }
