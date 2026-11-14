import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../telemetry/breadcrumbs.dart';
import '../process_output_state.dart';
import 'agent_work_result.dart';
import 'process_models.dart';
import 'subagent_repository.dart';
import 'subagent_detail_controller.dart' show kStopCheckLimit;

/// What a program's Stop needs from the app around it: the card as the
/// list last showed it, the connection, and a re-read of the list.
abstract interface class ProcessStopHost {
  /// Fires when the card, the connection or the list changed.
  Listenable get changes;

  /// The program's card now; null when there is none.
  ProcessOutput? get card;

  /// Whether the app has a connection to Hermes.
  bool get online;

  /// Reads `process.list` now and answers the program's row in it: [WorkOk]
  /// with null when the list no longer has it. Anything but [WorkOk] is a
  /// failed read.
  Future<AgentWorkResult<ListedProcess?>> rereadList();

  /// Puts a `process.kill` answer on the card.
  void applyKill(ProcessKill answer);
}

enum ProcessStopPhase {
  idle,

  /// The confirmation is open, bound to this program.
  confirming,
  sending,

  /// The answer was lost: "Couldn't confirm the stop. Checking…"
  checking,

  /// Stopped.
  killed,

  /// "It had already ended."
  alreadyEnded,

  /// `not_found` or 4044: "This program is no longer listed."
  notListed,

  /// "Couldn't stop the program." Stop is offered again.
  failed,

  /// "Couldn't confirm the stop. It may still be running." Stop is offered
  /// again.
  unconfirmed,

  /// The server has no `process.kill`: Stop is gone.
  unsupported,

  /// The program ended while the confirmation was open, which closes it.
  ended,
}

/// The Stop of one background program of a chat. It sends `process.kill`
/// only after the confirmation the caller shows ([startStop], then
/// [confirmStop]), once, and never again until the user confirms again: a
/// lost answer re-reads the list instead. The confirmation is bound to
/// [key], so a list that refreshes or reorders cannot move it to another
/// program.
///
/// Commands, output and ids never reach a log or breadcrumb: `process.stop`
/// carries only its outcome and `process.stop.pressed` nothing. A
/// conversation window, which holds no session, never makes one.
class ProcessStopController extends ChangeNotifier {
  ProcessStopController({
    required this.key,
    required this._repository,
    required this._host,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  }) {
    _host.changes.addListener(_onHostChanged);
  }

  final ProcessKey key;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  final SubagentRepository _repository;
  final ProcessStopHost _host;
  var _disposed = false;
  var _phase = ProcessStopPhase.idle;
  Completer<_Reread>? _check;

  ProcessStopPhase get phase => _phase;

  bool get offline => !_host.online;

  /// A confirmation shown for this program closes while this holds (pass it
  /// as the dialog's `dismissWhen`).
  bool get confirmationClosed => _phase == ProcessStopPhase.ended;

  bool get _running => _host.card?.running ?? false;

  /// Stop program can be pressed: the list shows the program running, the
  /// app is online and no stop is in flight or done.
  bool get canStop =>
      !_disposed &&
      _host.online &&
      _running &&
      switch (_phase) {
        ProcessStopPhase.idle ||
        ProcessStopPhase.unconfirmed ||
        ProcessStopPhase.failed ||
        ProcessStopPhase.ended => true,
        _ => false,
      };

  /// The user pressed Stop program: opens the confirmation. Nothing is
  /// sent.
  void startStop() {
    if (!canStop) return;
    breadcrumbs('process.stop.pressed');
    _set(ProcessStopPhase.confirming);
  }

  void cancelStop() {
    if (!_disposed && _phase == ProcessStopPhase.confirming) {
      _set(ProcessStopPhase.idle);
    }
  }

  /// The user confirmed. Sends one `process.kill` for [key]'s program.
  Future<void> confirmStop() async {
    if (_disposed || _phase != ProcessStopPhase.confirming) return;
    if (!_running || !_host.online) {
      // Offline, nothing is queued for later.
      _set(_running ? ProcessStopPhase.idle : ProcessStopPhase.ended);
      return;
    }
    _set(ProcessStopPhase.sending);
    final result = await _repository.processKill(
      key.threadId,
      key.processId,
      profile: key.profile,
    );
    if (_disposed) return;
    switch (result) {
      case WorkOk(:final value):
        _host.applyKill(value);
        final (phase, outcome) = switch (value.outcome) {
          KillOutcome.killed => (ProcessStopPhase.killed, 'killed'),
          KillOutcome.alreadyExited => (
            ProcessStopPhase.alreadyEnded,
            'already_exited',
          ),
          KillOutcome.notFound => (ProcessStopPhase.notListed, 'not_found'),
          KillOutcome.error => (ProcessStopPhase.failed, 'error'),
        };
        _log(outcome);
        _set(phase);
      case WorkLost():
        await _settleAfterCheck();
      case WorkUnsupported():
        _log('error');
        _set(ProcessStopPhase.unsupported);
      case WorkFailed() || WorkNotAttached():
        _log('error');
        _set(ProcessStopPhase.failed);
    }
  }

  /// "Checking…": re-reads the list, ends within [kStopCheckLimit], and
  /// words the outcome only from what the re-read showed. Nothing is resent.
  Future<void> _settleAfterCheck() async {
    _set(ProcessStopPhase.checking);
    final outcome = await _reread();
    if (_disposed || _phase != ProcessStopPhase.checking) return;
    _log('unconfirmed');
    _set(switch (outcome) {
      _Reread.stopped => ProcessStopPhase.killed,
      _Reread.exited => ProcessStopPhase.alreadyEnded,
      _Reread.gone => ProcessStopPhase.notListed,
      _Reread.running || _Reread.failed => ProcessStopPhase.unconfirmed,
    });
  }

  Future<_Reread> _reread() {
    _abortCheck();
    final done = _check = Completer<_Reread>();
    final timer = Timer(kStopCheckLimit, () => _finish(done, _Reread.failed));
    if (!_host.online) {
      _finish(done, _Reread.failed);
    } else {
      Future.sync(_host.rereadList)
          .then((result) {
            _finish(done, switch (result) {
              WorkOk(value: null) => _Reread.gone,
              WorkOk(:final value?) => switch (value.status) {
                ProgramStatus.running => _Reread.running,
                ProgramStatus.stopped => _Reread.stopped,
                ProgramStatus.exited || ProgramStatus.ended => _Reread.exited,
              },
              _ => _Reread.failed,
            });
          })
          .catchError((Object _) => _finish(done, _Reread.failed));
    }
    return done.future.whenComplete(timer.cancel);
  }

  void _finish(Completer<_Reread> done, _Reread outcome) {
    if (!done.isCompleted) done.complete(outcome);
  }

  void _abortCheck() {
    final pending = _check;
    if (pending != null) _finish(pending, _Reread.failed);
  }

  void _onHostChanged() {
    if (_disposed) return;
    if (_phase == ProcessStopPhase.confirming && !_running) {
      _phase = ProcessStopPhase.ended;
    }
    if (!_host.online) _abortCheck();
    notifyListeners();
  }

  void _set(ProcessStopPhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  void _log(String outcome) {
    try {
      events('process.stop', {'outcome': outcome});
    } on Object {
      // Telemetry never breaks the stop.
    }
  }

  /// A kill in flight is left to finish; its answer is ignored.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _abortCheck();
    _host.changes.removeListener(_onHostChanged);
    super.dispose();
  }

  @override
  String toString() => 'ProcessStopController($_phase)';
}

enum _Reread { running, stopped, exited, gone, failed }
