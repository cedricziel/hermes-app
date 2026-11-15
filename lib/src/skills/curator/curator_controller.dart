// Named parameters cannot be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../core/safe_notifier.dart';
import '../../files/widgets/safe_path_text.dart';
import '../../server_care/action_status.dart';
import '../../server_care/resumable_sleep.dart';
import 'curator_config.dart';
import 'curator_result.dart';
import 'curator_status.dart';
import 'curator_telemetry.dart';
import 'hermes_curator_repository.dart';

/// Where the status read stands. [unsupported] hides the section.
enum CuratorLoad {
  loading,
  loaded,
  offline,
  unavailable,
  failed,
  profileGone,
  unsupported,
}

/// How the last pause or resume went.
enum CuratorPause {
  idle,
  saving,

  /// Hermes refused or failed it (400, 422, 500): a section error.
  failed,

  /// No answer: the switch is back at its last known value.
  lost,

  /// The request never left the device.
  offline,
  profileGone,
}

enum CuratorRunPhase {
  /// The one read of the action status's `running` flag on open is on its way.
  opening,

  /// Nothing to report; a run may start.
  idle,
  starting,

  /// A pass this app started (or took for its own) is going; polled.
  following,

  /// `running` is false, a start header after the POST, exit code 0.
  finished,
  failed,

  /// The same proof, no exit code: the dashboard restarted or the pass was
  /// killed.
  stopped,

  /// `running` is false but no start header after the POST proves this pass.
  unconfirmed,
  notStarted,

  /// The answer to the POST never came: it may have started.
  lostAnswer,
  progressLost,

  /// 15 minutes of following without an end.
  stillRunning,

  /// The server was running a pass when the section opened.
  elsewhere,

  /// The open read failed: nothing is known about a running pass.
  unchecked,

  /// A read showed nothing running.
  checkedNothing,
}

/// Why a run did not start.
enum CuratorNotStarted { offline, refused, spawnFailed, profileGone }

const _canRun = {
  CuratorRunPhase.idle,
  CuratorRunPhase.finished,
  CuratorRunPhase.failed,
  CuratorRunPhase.notStarted,
  CuratorRunPhase.checkedNothing,
};

const _canCheck = {
  CuratorRunPhase.lostAnswer,
  CuratorRunPhase.progressLost,
  CuratorRunPhase.stillRunning,
  CuratorRunPhase.stopped,
  CuratorRunPhase.unconfirmed,
  CuratorRunPhase.elsewhere,
  CuratorRunPhase.unchecked,
};

/// The skill curator of one profile on the Skills screen: its status, the
/// pause switch and a confirmed run that is followed to its end. One per
/// Skills screen State.
///
/// A pause or a run is sent once; no answer is a lost answer, settled by
/// reading, never by sending again. A pass is "finished" only when `running`
/// is false and the log has a start header that the last header read before
/// the POST did not have (the header's time is the server's local time with
/// no zone, so it is compared as text against that baseline, not with the
/// clock). The output lines are shown for a pass this app started only,
/// cleaned for display, last [maxLines], in memory only, dropped by [lock]
/// and hidden while [blanked]. Nothing of a profile, a skill or a line
/// reaches telemetry. All timing goes through the injected clock and delay.
class CuratorController extends ChangeNotifier with SafeNotifier {
  CuratorController({
    required this.repository,
    required this.readConfig,
    required String profile,
    this.telemetry = const CuratorTelemetry(),
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
    this.onProfileGone,
    this.onRunEnded,
  }) : _profile = profile,
       _now = now ?? DateTime.now {
    _sleep = ResumableSleep(delay ?? Future<void>.delayed);
  }

  /// The most output lines kept.
  static const maxLines = 30;
  static const followLimit = Duration(minutes: 15);
  static const _progressLostAfter = Duration(seconds: 10);

  final HermesCuratorRepository repository;

  /// Reads the config switches the confirmation words itself by.
  final Future<CuratorConfig?> Function(String profile) readConfig;
  final CuratorTelemetry telemetry;
  final DateTime Function() _now;
  late final ResumableSleep _sleep;

  /// A request said the profile is gone: the owner reloads its profile list.
  final VoidCallback? onProfileGone;

  /// A pass ended, so skills may have been archived: re-read the list.
  final VoidCallback? onRunEnded;

  String _profile;
  int _epoch = 0;
  int _runId = 0;
  int _confirmId = 0;

  CuratorLoad _load = CuratorLoad.loading;
  CuratorStatus? _status;
  bool _refreshing = false;
  CuratorPause _pause = CuratorPause.idle;
  bool? _optimistic;
  bool _searching = false;

  CuratorRunPhase _phase = CuratorRunPhase.opening;
  CuratorNotStarted? _notStarted;
  CuratorConfig? _confirmation;
  bool _checking = false;
  bool _checkFailed = false;
  bool _own = false;
  bool _triggerLost = false;
  String? _baselineHeader;
  DateTime? _lastRunBefore;
  DateTime? _startedAt;
  Span? _span;

  List<String> _lines = const [];
  int _earlier = 0;
  bool _locked = false;
  bool _inactive = false;
  bool _dropped = false;

  String get profile => _profile;
  CuratorLoad get load => _load;

  /// The last status read; kept while it is read again.
  CuratorStatus? get status => _status;
  bool get refreshing => _refreshing;
  CuratorPause get pause => _pause;

  /// The switch: the value being sent while saving, else Hermes' last answer.
  bool? get paused => _optimistic ?? _status?.paused;

  CuratorRunPhase get phase => _phase;
  CuratorNotStarted? get notStarted => _notStarted;

  /// Set while the run confirmation is open; its values are null until the
  /// config read lands, and stay null when it cannot be read.
  CuratorConfig? get confirmation => _confirmation;

  /// A Check status read is in flight.
  bool get checking => _checking;

  /// The last Check status read got no answer.
  bool get checkFailed => _checkFailed;

  /// `last_run_at` when it changed since this app's POST: "A pass started
  /// at". It says nothing about how the pass ended.
  DateTime? get startedAt => _startedAt;

  bool get busy =>
      _phase == CuratorRunPhase.starting || _phase == CuratorRunPhase.following;

  bool get canRunNow => _confirmation == null && _runnable;

  bool get _runnable =>
      _load == CuratorLoad.loaded &&
      (_status?.isOn ?? false) &&
      !_checking &&
      _canRun.contains(_phase);

  bool get canCheck => !_checking && _canCheck.contains(_phase);

  bool get visible => !_searching && _load != CuratorLoad.unsupported;

  /// Search text or a filter is active: the section is hidden; nothing else
  /// changes, so a result is still there when it shows again.
  set searching(bool value) {
    if (_searching == value) return;
    _searching = value;
    notifyListeners();
  }

  /// App Lock covers the app, or the app is inactive on a phone: the output
  /// is not shown.
  bool get blanked => _locked || _inactive;
  bool get hasOutput => _lines.isNotEmpty;

  /// Output was dropped by App Lock and is gone.
  bool get outputDropped => _dropped;

  /// Display lines of the pass this app ran: control and bidi characters are
  /// drawn as `<U+XXXX>`, the last [maxLines], oldest first. Empty while
  /// [blanked].
  List<String> get outputLines => blanked ? const [] : _lines;

  /// How many lines before [outputLines] were left out.
  int get earlierLines => _earlier;

  /// Reads the status and, once, the action status's `running` flag.
  void start() {
    final epoch = _epoch;
    _phase = CuratorRunPhase.opening;
    notifyListeners();
    unawaited(Future.wait([_loadStatus(epoch), _open(epoch)]));
  }

  /// Try again after a failed read.
  Future<void> reload() => _loadStatus(_epoch);

  /// The Skills screen shows another profile: the old result and polling are
  /// dropped, and the new profile is read.
  void switchProfile(String profile) {
    if (profile == _profile) return;
    _drop();
    _profile = profile;
    _load = CuratorLoad.loading;
    _status = null;
    _refreshing = false;
    _pause = CuratorPause.idle;
    _optimistic = null;
    _confirmation = null;
    _notStarted = null;
    _clearResult();
    start();
  }

  void _drop() {
    _epoch++;
    _runId++;
    _confirmId++;
    _checking = false;
    _endSpan(CuratorRunOutcome.unknown);
    _sleep.release();
  }

  void _clearResult() {
    _lines = const [];
    _earlier = 0;
    _dropped = false;
    _startedAt = null;
    _checkFailed = false;
    _own = false;
    _triggerLost = false;
  }

  bool _gone(int epoch, [int? run]) =>
      disposed || epoch != _epoch || (run != null && run != _runId);

  Future<void> _loadStatus(int epoch) async {
    if (_status == null) _load = CuratorLoad.loading;
    _refreshing = _status != null;
    notifyListeners();
    final result = await repository.status(profile: _profile);
    if (_gone(epoch)) return;
    _refreshing = false;
    switch (result) {
      case CuratorOk(:final value):
        _status = value;
        _load = CuratorLoad.loaded;
      case CuratorUnsupported():
        _status = null;
        _load = CuratorLoad.unsupported;
      case CuratorProfileGone():
        _load = CuratorLoad.profileGone;
        onProfileGone?.call();
      case CuratorFailed(:final kind):
        _load = switch (kind) {
          CuratorFailure.offline => CuratorLoad.offline,
          CuratorFailure.unavailable => CuratorLoad.unavailable,
          _ => CuratorLoad.failed,
        };
    }
    notifyListeners();
  }

  /// An action status whose `running` is missing or ill-typed is no answer:
  /// it would read as "not running", which no proof may rest on.
  Future<CuratorResult<ActionStatus>> _readRun() async {
    final result = await repository.runStatus();
    if (result case CuratorOk(:final value) when !value.runningKnown) {
      return const CuratorFailed(CuratorFailure.unreadable);
    }
    return result;
  }

  /// The one read on open: only `running` and the header baseline are used.
  Future<void> _open(int epoch) async {
    final result = await _readRun();
    if (_gone(epoch) || _phase != CuratorRunPhase.opening) return;
    if (result case CuratorOk(:final value)) {
      _baselineHeader = value.startHeader;
      _phase = value.running ? CuratorRunPhase.elsewhere : CuratorRunPhase.idle;
    } else {
      _phase = CuratorRunPhase.unchecked;
    }
    notifyListeners();
  }

  /// Flips the switch. Optimistic; the value shown afterwards is the
  /// `paused` Hermes answered, or the last known one when no answer came.
  Future<void> setPaused(bool value) async {
    final current = _status;
    if (current == null || !current.isOn || _pause == CuratorPause.saving) {
      return;
    }
    final epoch = _epoch;
    _optimistic = value;
    _pause = CuratorPause.saving;
    notifyListeners();
    final result = await repository.setPaused(value, profile: _profile);
    if (_gone(epoch)) return;
    _optimistic = null;
    switch (result) {
      case CuratorOk(value: final answered):
        _status = _withPaused(_status ?? current, answered);
        _pause = CuratorPause.idle;
        telemetry.paused(paused: answered);
      case CuratorProfileGone():
        _pause = CuratorPause.profileGone;
        onProfileGone?.call();
      case CuratorUnsupported():
        _load = CuratorLoad.unsupported;
      case CuratorFailed(:final kind):
        _pause = switch (kind) {
          CuratorFailure.lostAnswer ||
          CuratorFailure.timeout => CuratorPause.lost,
          CuratorFailure.offline => CuratorPause.offline,
          _ => CuratorPause.failed,
        };
        if (_pause == CuratorPause.lost) unawaited(_loadStatus(epoch));
    }
    notifyListeners();
  }

  /// Opens the run confirmation at once with the hedged wording; the config
  /// read refines it when it lands and never delays it.
  void beginRun() {
    if (!canRunNow) return;
    _confirmation = const CuratorConfig();
    final epoch = _epoch;
    final id = ++_confirmId;
    notifyListeners();
    unawaited(() async {
      final config = await readConfig(_profile);
      if (_gone(epoch) || id != _confirmId || _confirmation == null) return;
      _confirmation = config ?? const CuratorConfig();
      notifyListeners();
    }());
  }

  void cancelRun() {
    _confirmId++;
    if (_confirmation == null) return;
    _confirmation = null;
    notifyListeners();
  }

  /// Sends the run, once. Only an open confirmation sends: a second press,
  /// while a pass is running or may be, sends nothing.
  Future<void> confirmRun() async {
    if (_confirmation == null || !_runnable) return;
    _confirmation = null;
    _confirmId++;
    telemetry.confirmed();
    final epoch = _epoch;
    final id = ++_runId;
    _clearResult();
    _notStarted = null;
    _own = true;
    _lastRunBefore = _status?.lastRunAt;
    _span = telemetry.startRun();
    _phase = CuratorRunPhase.starting;
    notifyListeners();
    final result = await repository.run(profile: _profile);
    if (_gone(epoch, id)) return;
    switch (result) {
      case CuratorOk():
        _phase = CuratorRunPhase.following;
        notifyListeners();
        await _follow(epoch, id);
      case CuratorProfileGone():
        _refused(CuratorNotStarted.profileGone);
        onProfileGone?.call();
      case CuratorUnsupported():
        _refused(CuratorNotStarted.refused);
      case CuratorFailed(:final kind):
        switch (kind) {
          case CuratorFailure.offline:
            _refused(CuratorNotStarted.offline);
          case CuratorFailure.refused || CuratorFailure.unauthorized:
            _refused(CuratorNotStarted.refused);
          case CuratorFailure.spawnFailed:
            _refused(CuratorNotStarted.spawnFailed);
          default:
            _triggerLost = true;
            _unsure(CuratorRunPhase.lostAnswer, CuratorRunOutcome.unknown);
        }
    }
  }

  void _refused(CuratorNotStarted why) {
    _notStarted = why;
    _phase = CuratorRunPhase.notStarted;
    _endSpan(CuratorRunOutcome.failed);
    notifyListeners();
  }

  void _unsure(CuratorRunPhase phase, CuratorRunOutcome outcome) {
    _phase = phase;
    final first = _span != null;
    _endSpan(outcome);
    if (first) telemetry.runFinished(outcome);
    notifyListeners();
    if (_own) unawaited(_noteStart(_epoch));
  }

  void _endSpan(CuratorRunOutcome outcome) {
    final span = _span;
    if (span == null) return;
    _span = null;
    telemetry.endRun(span, outcome, triggerLost: _triggerLost);
  }

  /// Reads the action status every 2 s, backing off to 5 s, until `running`
  /// is false, the progress is lost or the limit passes.
  Future<void> _follow(int epoch, int run) async {
    final began = _now();
    DateTime? failingSince;
    var polls = 0;
    while (true) {
      await _sleep.sleep(Duration(seconds: math.min(5, 2 + polls ~/ 5)));
      if (_gone(epoch, run)) return;
      polls++;
      final asked = _now();
      final result = await _readRun();
      if (_gone(epoch, run)) return;
      if (result case CuratorOk(:final value)) {
        failingSince = null;
        if (!value.running) return _settle(value, epoch, checking: false);
      } else {
        failingSince ??= asked;
        if (_now().difference(failingSince) >= _progressLostAfter) {
          return _unsure(
            CuratorRunPhase.progressLost,
            CuratorRunOutcome.unknown,
          );
        }
      }
      if (_now().difference(began) >= followLimit) {
        return _unsure(
          CuratorRunPhase.stillRunning,
          CuratorRunOutcome.timedOut,
        );
      }
    }
  }

  /// One read, for a state that is unsure. A run that is going is followed
  /// again with a new 15-minute limit.
  Future<void> checkStatus() async {
    if (!canCheck) return;
    final epoch = _epoch;
    final run = ++_runId;
    _checking = true;
    notifyListeners();
    final result = await _readRun();
    if (_gone(epoch, run)) return;
    _checking = false;
    if (result case CuratorOk(:final value)) {
      _checkFailed = false;
      if (value.running) {
        _phase = CuratorRunPhase.following;
        notifyListeners();
        return _follow(epoch, run);
      }
      return _settle(value, epoch, checking: true);
    }
    _checkFailed = true;
    notifyListeners();
  }

  /// `running` is false. Proof that the pass this app started is over:
  /// a start header that is not the baseline's.
  Future<void> _settle(
    ActionStatus status,
    int epoch, {
    required bool checking,
  }) async {
    final header = status.startHeader;
    // A failed spawn writes a header before it fails: a new header with no
    // line after it, or no exit code, proves nothing.
    final hasLines = status.lines.any((l) => l.trim().isNotEmpty);
    final newHeader = _own && header != null && header != _baselineHeader;
    final proof = newHeader && hasLines;
    _baselineHeader = header ?? _baselineHeader;
    CuratorRunOutcome? outcome;
    if (proof) {
      _phase = switch (status.exitCode) {
        0 => CuratorRunPhase.finished,
        null => CuratorRunPhase.stopped,
        _ => CuratorRunPhase.failed,
      };
      outcome = switch (_phase) {
        CuratorRunPhase.finished => CuratorRunOutcome.done,
        CuratorRunPhase.failed => CuratorRunOutcome.failed,
        _ => CuratorRunOutcome.unknown,
      };
      _keepLines(status.lines);
    } else if (_own && !checking) {
      _phase = CuratorRunPhase.unconfirmed;
      outcome = CuratorRunOutcome.unknown;
    } else {
      _phase = CuratorRunPhase.checkedNothing;
    }
    if (outcome != null) {
      final first = _span != null;
      _endSpan(outcome);
      final final_ =
          outcome == CuratorRunOutcome.done ||
          outcome == CuratorRunOutcome.failed;
      if (first || final_) {
        telemetry.runFinished(
          outcome,
          archived: proof ? _archived(status.lines) : null,
        );
      }
    }
    notifyListeners();
    if (proof || !checking || _own) {
      await _noteStart(epoch);
      if (!_gone(epoch) && (proof || !checking)) onRunEnded?.call();
    }
  }

  /// Reads the status again; a `last_run_at` that changed since the POST is
  /// [startedAt] (Hermes saves it before consolidation ends).
  Future<void> _noteStart(int epoch) async {
    await _loadStatus(epoch);
    if (_gone(epoch)) return;
    final at = _status?.lastRunAt;
    if (_own && at != null && at != _lastRunBefore) _startedAt = at;
    notifyListeners();
  }

  static final _archivedLine = RegExp(r'\barchived=(\d+)');

  int? _archived(List<String> lines) {
    int? found;
    for (final line in lines) {
      for (final m in _archivedLine.allMatches(line)) {
        found = int.tryParse(m.group(1)!) ?? found;
      }
    }
    return found;
  }

  void _keepLines(List<String> raw) {
    final shown = [
      for (final line in raw)
        if (line.trim().isNotEmpty)
          safeContentText(line.replaceFirst(RegExp(r'[\r\n]+$'), '')),
    ];
    if (_locked) {
      _lines = const [];
      _earlier = 0;
      _dropped = shown.isNotEmpty;
      return;
    }
    _earlier = math.max(0, shown.length - maxLines);
    _lines = shown.sublist(_earlier);
  }

  /// App Lock locked: the output is dropped, not only hidden.
  void lock() {
    _locked = true;
    if (_lines.isNotEmpty) _dropped = true;
    _lines = const [];
    _earlier = 0;
    notifyListeners();
  }

  void unlocked() {
    _locked = false;
    notifyListeners();
  }

  /// The app is inactive (on a phone): the output is hidden until it is back.
  void setInactive(bool value) {
    if (_inactive == value) return;
    _inactive = value;
    notifyListeners();
  }

  /// The app came back to the front: a poll's wait ends now.
  void resumed() => _sleep.resumed();

  @override
  void dispose() {
    _drop();
    _lines = const [];
    super.dispose();
  }
}

CuratorStatus _withPaused(CuratorStatus s, bool paused) => CuratorStatus(
  enabled: s.enabled,
  paused: paused,
  intervalHours: s.intervalHours,
  lastRun: s.lastRun,
  lastRunAt: s.lastRunAt,
  minIdleHours: s.minIdleHours,
  staleAfterDays: s.staleAfterDays,
  archiveAfterDays: s.archiveAfterDays,
);
