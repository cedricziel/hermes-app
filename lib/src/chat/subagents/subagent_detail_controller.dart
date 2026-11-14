import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../../telemetry/breadcrumbs.dart';
import 'agent_detail_host.dart';
import 'agent_models.dart';
import 'agent_work_result.dart';
import 'subagent_repository.dart';

enum StopPhase {
  idle,

  /// The confirmation is open, bound to this agent.
  confirming,
  sending,

  /// "Couldn't confirm the stop. Checking…"
  checking,

  /// The server accepted the stop: "Stopping…".
  stopping,
  alreadyFinished,

  /// "Hermes doesn't let this device stop or redirect this agent."
  notControllable,

  /// "Couldn't confirm the stop. It may still be running." Stop is offered
  /// again.
  unconfirmed,

  /// "Couldn't stop the agent. Try again."
  failed,

  /// "This server can't stop agents."
  unsupported,

  /// The agent ended while the confirmation was open: "That agent has ended."
  ended,
}

enum NotePhase {
  idle,
  sending,

  /// "Sent. The agent gets it after its current step."
  queued,

  /// "This agent isn't taking notes now."
  rejected,
  notControllable,

  /// "Couldn't confirm the note was sent." The text stays; only a tap sends
  /// again.
  lost,

  /// "Couldn't send the note. Try again."
  failed,

  /// "This server can't take notes for agents."
  unsupported,
}

enum TailPhase { loading, ready, noOutput, neverAvailable, unsupported }

/// How long a check after a stop may last.
const kStopCheckLimit = Duration(seconds: 10);

/// How often the detail reads the agent's output while it is visible.
const kTailEvery = Duration(seconds: 2);

/// How long after it started a running agent may have no output before the
/// detail says it never will.
const kOutputNeverAfter = Duration(seconds: 30);

/// The state of one open agent detail: its output, the stop and the notes. It holds typed text, notes and output in memory only,
/// and never lets any of them reach a log, span or breadcrumb: those carry
/// fixed words.
///
/// One controller serves one agent, named by its [key], fixed when the
/// detail opens; a list that refreshes or reorders cannot move a stop or a
/// note to another agent.
class SubagentDetailController extends ChangeNotifier {
  SubagentDetailController({
    required this.key,
    required this._repository,
    required this._host,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  }) : _openedAt = clock.now() {
    _wasUnlocked = _host.unlocked;
    _host.changes.addListener(_onHostChanged);
    _timer = Timer.periodic(kTailEvery, (_) => _readTail());
    // After construction, so a listener attached right away sees the start.
    scheduleMicrotask(_readTail);
  }

  final AgentKey key;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  final SubagentRepository _repository;
  final AgentDetailHost _host;
  final DateTime _openedAt;
  Timer? _timer;
  var _disposed = false;
  var _wasUnlocked = true;

  // ---- output ---------------------------------------------------------

  var _latest = '';
  String? _shown;
  var _holding = false;
  var _readInFlight = false;

  /// Counts the times held output was dropped, so a read that began before
  /// App Lock never lands after it.
  var _epoch = 0;
  var _answered = false;
  var _available = false;
  var _refreshFailed = false;
  var _tailUnsupported = false;

  /// The output the view shows: the newest, unless the reader holds it.
  String get tail => _shown ?? _latest;

  /// The reader selected text or scrolled away from the end: newer output
  /// is fetched but not shown until [jumpToLatest].
  bool get paused => _holding && _shown != null && _shown != _latest;

  void setReaderHolding(bool holding) {
    if (_disposed || _holding == holding) return;
    _holding = holding;
    _shown = holding ? _latest : null;
    notifyListeners();
  }

  void jumpToLatest() {
    if (_disposed) return;
    _holding = false;
    _shown = null;
    notifyListeners();
  }

  /// The last read failed after output was shown: "Couldn't refresh the
  /// output."
  bool get refreshFailed => _refreshFailed;

  TailPhase get tailPhase {
    if (_tailUnsupported) return TailPhase.unsupported;
    if (!_answered) return TailPhase.loading;
    if (_available) return TailPhase.ready;
    final started = _host.view?.startedAt ?? _openedAt;
    return clock.now().difference(started) >= kOutputNeverAfter
        ? TailPhase.neverAvailable
        : TailPhase.noOutput;
  }

  /// The agent ended, so the output is the last that was read.
  bool get _notControllable =>
      _stop == StopPhase.notControllable ||
      _notePhase == NotePhase.notControllable;

  bool get lastOutput => !_agentActive && tail.isNotEmpty;

  bool get _agentActive => _host.view?.active ?? false;

  /// The roster's row exists and says the agent ended. A row not yet there
  /// is not an ended agent.
  bool get _agentEnded {
    final view = _host.view;
    return view != null && !view.active;
  }

  bool get _mayRead =>
      !_disposed &&
      _host.readingAllowed &&
      _host.unlocked &&
      _host.online &&
      _agentActive &&
      !_notControllable &&
      !_tailUnsupported;

  Future<void> _readTail() async {
    if (_readInFlight || !_mayRead) return;
    _readInFlight = true;
    final epoch = _epoch;
    final result = await _repository.tail(key);
    _readInFlight = false;
    // An answer that lands after the detail closed, the app locked or the
    // agent ended is not shown.
    if (_disposed || epoch != _epoch || !_host.unlocked || !_agentActive) {
      return;
    }
    switch (result) {
      case WorkOk(:final value):
        _answered = true;
        _available = value.available;
        _refreshFailed = false;
        if (value.available) {
          _latest = value.text;
          if (!_holding) _shown = null;
        }
      case WorkUnsupported():
        _tailUnsupported = true;
        _latest = '';
        _shown = null;
      case WorkNotAttached():
        _answered = true;
        _available = false;
      case WorkLost() || WorkFailed():
        _refreshFailed = _answered && _available;
    }
    notifyListeners();
  }

  void _dropOutput() {
    _epoch++;
    _latest = '';
    _shown = null;
    _answered = false;
    _available = false;
    _refreshFailed = false;
  }

  // ---- host changes ---------------------------------------------------

  void _onHostChanged() {
    if (_disposed) return;
    final unlocked = _host.unlocked;
    if (!unlocked && _wasUnlocked) {
      _dropOutput();
      _holding = false;
    }
    final unlockedNow = unlocked && !_wasUnlocked;
    _wasUnlocked = unlocked;

    if (_agentEnded) {
      _timer?.cancel();
      _timer = null;
      if (_stop == StopPhase.confirming) {
        _stop = StopPhase.ended;
      } else if (_stop == StopPhase.sending) {
        // A completion frame came first: it wins and the answer, when it
        // comes, changes nothing.
        _answerIgnored = true;
        _stop = StopPhase.idle;
      } else if (_stop == StopPhase.checking) {
        // The agent is gone: finished when the stop was told it had ended,
        // otherwise the row's own state says what happened.
        _abortCheck(_stopCheck);
        _stop = _foundFalse ? StopPhase.alreadyFinished : StopPhase.idle;
        _log('subagent.stop', _foundFalse ? 'already_ended' : 'unconfirmed');
      }
    }
    if (!_host.online) {
      _abortCheck(_stopCheck);
      _abortCheck(_noteCheck);
    }
    notifyListeners();
    if (unlockedNow) unawaited(_readTail());
    _noteMissedIfShown();
  }

  // ---- stop -----------------------------------------------------------

  var _stop = StopPhase.idle;
  var _stopAccepted = false;
  var _answerIgnored = false;
  Completer<_Reread>? _stopCheck, _noteCheck;
  var _foundFalse = false;

  StopPhase get stopPhase => _stop;

  bool get offline => !_host.online;

  /// Stop agent can be pressed.
  bool get canStop =>
      !_disposed &&
      _host.online &&
      _agentActive &&
      !_stopAccepted &&
      switch (_stop) {
        StopPhase.idle || StopPhase.unconfirmed || StopPhase.failed => true,
        _ => false,
      };

  /// The user pressed Stop agent: opens the confirmation, bound to this
  /// agent. Nothing is sent.
  void startStop() {
    if (!canStop) return;
    breadcrumbs('subagent.stop.pressed');
    _stop = StopPhase.confirming;
    notifyListeners();
  }

  void cancelStop() {
    if (_disposed || _stop != StopPhase.confirming) return;
    _stop = StopPhase.idle;
    notifyListeners();
  }

  /// The user confirmed. Sends one `subagent.interrupt`; never again until
  /// the user confirms again.
  Future<void> confirmStop() async {
    if (_disposed || _stop != StopPhase.confirming) return;
    if (!_agentActive) {
      _stop = StopPhase.ended;
      notifyListeners();
      return;
    }
    if (!_host.online) {
      _stop = StopPhase.idle;
      notifyListeners();
      return;
    }
    breadcrumbs('subagent.stop.confirmed');
    _stop = StopPhase.sending;
    _answerIgnored = false;
    notifyListeners();
    final result = await _repository.interrupt(key);
    if (_disposed) return;
    if (_answerIgnored || !_agentActive) {
      _log('subagent.stop', 'already_ended');
      if (_stop == StopPhase.sending) _stop = StopPhase.idle;
      notifyListeners();
      return;
    }
    switch (result) {
      case WorkOk(value: StopOutcome.stopped):
        _stopAccepted = true;
        _stop = StopPhase.stopping;
        _log('subagent.stop', 'stopped');
        notifyListeners();
      case WorkOk(value: StopOutcome.alreadyEnded):
        await _settleAfterCheck(foundFalse: true);
      case WorkLost():
        await _settleAfterCheck(foundFalse: false);
      case WorkUnsupported():
        _stop = StopPhase.unsupported;
        _log('subagent.stop', 'error');
        notifyListeners();
      case WorkFailed(:final kind):
        _stop = StopPhase.failed;
        _log(
          'subagent.stop',
          kind == WorkFailureKind.rejected ? 'rejected' : 'error',
        );
        notifyListeners();
      case WorkNotAttached():
        _stop = StopPhase.failed;
        _log('subagent.stop', 'error');
        notifyListeners();
    }
  }

  /// "Checking…": re-reads the list, ends within [kStopCheckLimit], and
  /// words the outcome only from what the re-read showed.
  Future<void> _settleAfterCheck({required bool foundFalse}) async {
    _stop = StopPhase.checking;
    _foundFalse = foundFalse;
    notifyListeners();
    final outcome = await _reread(stop: true);
    if (_disposed || _stop != StopPhase.checking) return;
    switch (outcome) {
      case _Reread.finished when foundFalse:
        _stop = StopPhase.alreadyFinished;
        _log('subagent.stop', 'already_ended');
      case _Reread.finished:
        // The stop's answer was lost and the agent is gone: the row's own
        // state (Stopped or Finished) says what happened, not a claim that
        // it had already finished.
        _stop = StopPhase.idle;
        _log('subagent.stop', 'unconfirmed');
      case _Reread.running when foundFalse:
        _stop = StopPhase.notControllable;
        _log('subagent.stop', 'not_controllable');
      case _Reread.running || _Reread.failed:
        _stop = StopPhase.unconfirmed;
        _log('subagent.stop', 'unconfirmed');
    }
    notifyListeners();
  }

  /// One re-read of the list that always ends: with its answer, after
  /// [kStopCheckLimit], or when the connection is lost.
  Future<_Reread> _reread({bool stop = false}) {
    final slot = stop ? _stopCheck : _noteCheck;
    _abortCheck(slot);
    final done = Completer<_Reread>();
    if (stop) {
      _stopCheck = done;
    } else {
      _noteCheck = done;
    }
    final timer = Timer(
      kStopCheckLimit,
      () => _finishCheck(done, _Reread.failed),
    );
    if (!_host.online) {
      _finishCheck(done, _Reread.failed);
    } else {
      Future.sync(_host.rereadList)
          .then((result) {
            _finishCheck(done, switch (result) {
              WorkOk(:final value) =>
                value == null || !value.active
                    ? _Reread.finished
                    : _Reread.running,
              _ => _Reread.failed,
            });
          })
          .catchError((Object _) => _finishCheck(done, _Reread.failed));
    }
    return done.future.whenComplete(timer.cancel);
  }

  void _finishCheck(Completer<_Reread> done, _Reread outcome) {
    if (!done.isCompleted) done.complete(outcome);
  }

  void _abortCheck(Completer<_Reread>? pending) {
    if (pending != null && !pending.isCompleted) {
      pending.complete(_Reread.failed);
    }
  }

  // ---- notes ----------------------------------------------------------

  var _note = '';
  var _notePhase = NotePhase.idle;
  final _sent = <String>[];
  var _missedLogged = false;

  /// What the user typed, untrimmed.
  String get note => _note;

  NotePhase get notePhase => _notePhase;

  /// Notes queued this time, oldest first.
  List<String> get sentNotes => List.unmodifiable(_sent);

  int get noteLength => _note.trim().runes.length;

  bool get noteTooLong => noteLength > kMaxNoteLength;

  /// The typed text can no longer be sent and is shown read-only as "Not
  /// sent": a stop was accepted, the agent ended, or it cannot be
  /// controlled from here.
  bool get noteFrozen =>
      _note.isNotEmpty &&
      (_stopAccepted ||
          !_agentActive ||
          _host.view?.acceptingSteer == false ||
          _stop == StopPhase.notControllable ||
          _notePhase == NotePhase.notControllable);

  void setNote(String text) {
    if (_disposed || noteFrozen || text == _note) return;
    _note = text;
    notifyListeners();
  }

  /// Send to agent can be pressed. After a lost answer it stays enabled.
  bool get canSendNote =>
      !_disposed &&
      _host.online &&
      _agentActive &&
      (_host.view?.acceptingSteer ?? true) &&
      !_stopAccepted &&
      _stop != StopPhase.notControllable &&
      switch (_notePhase) {
        NotePhase.sending ||
        NotePhase.notControllable ||
        NotePhase.unsupported => false,
        _ => true,
      } &&
      noteLength > 0 &&
      !noteTooLong;

  /// Sends the typed note once, trimmed. Only an explicit tap calls this;
  /// nothing is resent after a failure or a lost answer.
  Future<void> sendNote() async {
    if (!canSendNote) return;
    final text = _note.trim();
    breadcrumbs('subagent.redirect.sent');
    _notePhase = NotePhase.sending;
    notifyListeners();
    final result = await _repository.steer(key, text);
    // A note in flight when the detail closed finishes in the background:
    // no outcome, no retry.
    if (_disposed) return;
    switch (result) {
      case WorkOk(value: SteerOutcome.queued):
        // Text typed while the note was in flight is never dropped.
        if (_note.trim() == text) _note = '';
        _sent.add(text);
        _notePhase = NotePhase.queued;
        _log('subagent.redirect', 'queued');
        _noteMissedIfShown();
      case WorkOk(value: SteerOutcome.rejected):
        _notePhase = NotePhase.rejected;
        _log('subagent.redirect', 'rejected');
        if (_host.view?.acceptingSteer == true) {
          notifyListeners();
          await _classifyRejectedNote();
          return;
        }
      case WorkLost():
        _notePhase = NotePhase.lost;
        _log('subagent.redirect', 'unconfirmed');
      case WorkUnsupported():
        _notePhase = NotePhase.unsupported;
        _log('subagent.redirect', 'error');
      case WorkFailed() || WorkNotAttached():
        _notePhase = NotePhase.failed;
        _log('subagent.redirect', 'error');
    }
    notifyListeners();
  }

  /// A note was refused by an agent the list says takes notes: re-read the
  /// list before saying why.
  Future<void> _classifyRejectedNote() async {
    final outcome = await _reread();
    if (_disposed || _notePhase != NotePhase.rejected) return;
    if (outcome == _Reread.running) _notePhase = NotePhase.notControllable;
    notifyListeners();
  }

  /// Hermes' notice that a queued note never reached the agent, in the
  /// completion summary or a failed delegation's error. Without it nothing
  /// is claimed.
  bool get noteMissed {
    final view = _host.view;
    return _sent.isNotEmpty &&
        view != null &&
        (summaryShowsMissedNote(view.summary) ||
            errorShowsMissedNote(view.error));
  }

  void _noteMissedIfShown() {
    if (_missedLogged || !noteMissed) return;
    _missedLogged = true;
    _log('subagent.redirect', 'missed');
  }

  // ---- lifecycle ------------------------------------------------------

  void _log(String name, String outcome) {
    try {
      events(name, {'outcome': outcome});
    } on Object {
      // Telemetry never breaks the detail.
    }
  }

  /// Closing the detail drops the typed text, the notes and the output. A
  /// call in flight is left to finish; its answer is ignored.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _abortCheck(_stopCheck);
    _abortCheck(_noteCheck);
    _stop = StopPhase.idle;
    _host.changes.removeListener(_onHostChanged);
    _dropOutput();
    _note = '';
    _sent.clear();
    super.dispose();
  }

  @override
  String toString() =>
      'SubagentDetailController(stop: $_stop, note: $_notePhase, '
      'notes: ${_sent.length})';
}

enum _Reread { finished, running, failed }
