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
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _repository = repository,
       _store = store,
       _care = care,
       _probeConnection = probeConnection,
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

  final ServerCareRepository _repository;
  final UpdateRunStore? _store;
  final ServerCareController? _care;
  final Future<void> Function()? _probeConnection;
  final ConnectionTelemetry _telemetry;
  final Breadcrumbs _breadcrumbs;
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
        return _launch(_checkStale);
      case UpdatePhase.unauthorized:
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
    if (_now().difference(record.startedAt) < resumeWindow) {
      _startSpan(resumed: true);
      await _launch(() => _follow(_Step.update));
    } else {
      await _launch(_readOld);
    }
  }

  @override
  void dispose() {
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

  void _reset() {
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
    final answer = await _repository.startUpdate();
    if (_stale(generation)) return;
    switch (answer) {
      case CareOk(value: final UpdateRefused refused):
        _refusalMessage = refused.message;
        _refusalCommand = refused.command;
        return _settle(UpdatePhase.refused, 'refused');
      case CareOk(value: final UpdateStarted started):
        _actionId = started.actionId;
      case CareFailed(kind: CareFailureKind.unauthorized):
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
        _refusalMessage = message;
        return _settle(UpdatePhase.refused, 'refused');
      case CareUnsupported():
        _refusalMessage = null;
        return _settle(UpdatePhase.refused, 'refused');
    }
    await _store?.write(
      UpdateRunRecord(
        startedAt: _startedAt!,
        actionId: _actionId,
        versionBefore: _versionBefore,
        commitBefore: _commitBefore,
      ),
    );
    if (_stale(generation)) return;
    await _follow(_Step.update);
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
          if (value.lines.isNotEmpty) _lines = value.lines;
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
          _cameBack = true;
          return _Step.restart;
      }
      if (_lost &&
          !_sawRunning &&
          _now().difference(from) >= lostAnswerWindow) {
        _finish(UpdateResult.unknown);
        return null;
      }
      notifyListeners();
      await _delay(_poll);
      if (_stale(generation)) return null;
    }
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

  /// Reads `/api/health` and nothing else until Hermes answers.
  Future<_Step?> _restart(int generation) async {
    _enter(UpdatePhase.restarting);
    _restartSince ??= _now();
    var backoff = _firstBackoff;
    while (true) {
      final health = await _repository.health();
      if (_stale(generation)) return null;
      if (health case CareOk(:final value)) {
        _noteHealth(value);
        if (_changed(value)) {
          _cameBack = true;
          return _Step.verify;
        }
        // The same code answers: either Hermes restarted onto it or it never
        // stopped. A child still running means the update is not over.
        final status = await _repository.actionStatus(
          CareAction.hermesUpdate,
          lines: 60,
        );
        if (_stale(generation)) return null;
        if (status case CareOk(:final value) when value.running) {
          if (value.lines.isNotEmpty) _lines = value.lines;
          return _Step.update;
        }
        _cameBack = true;
        return _Step.verify;
      }
      await _delay(backoff);
      if (_stale(generation)) return null;
      if (_now().difference(_restartSince!) >= restartWindow) {
        _settle(UpdatePhase.notBack, 'not_back');
        return null;
      }
      backoff = backoff * 2 > _lastBackoff ? _lastBackoff : backoff * 2;
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
          // Hermes went away again.
          _cameBack = true;
          return _Step.restart;
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

  /// Settles the run from a receipt of this action; false when it does not
  /// say yet (`running`, or an outcome this app does not know).
  bool _resolve(UpdateReceiptSummary receipt) {
    switch (receipt.outcome) {
      case UpdateOutcome.success || UpdateOutcome.partial:
        _postVersion = receipt.postVersion;
        _reasons = [
          for (final f in [
            ?receipt.userAction,
            if (receipt.userAction == null) ...receipt.followups,
          ])
            ?f.reason,
        ];
        final result = receipt.outcome == UpdateOutcome.success
            ? UpdateResult.success
            : UpdateResult.partial;
        if (!_cameBack &&
            _commitBefore != null &&
            _commitNow == _commitBefore) {
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
