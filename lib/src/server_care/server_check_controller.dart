// Named parameters cannot be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'action_status.dart';
import 'care_result.dart';
import 'doctor_report.dart';
import 'server_care_repository.dart';

enum CheckPhase {
  /// Nothing ran, or the result was dropped.
  idle,

  /// The run was asked for and the request is on its way.
  starting,

  /// Hermes is checking; the action's status is read until it ends.
  running,

  /// The report is in [ServerCheckController.report].
  finished,

  /// Not finished after the follow window; the run may still end.
  timedOut,

  /// Nothing to show: see [ServerCheckController.failure].
  failed,
}

/// Why a run ended without a report.
enum CheckFailure {
  /// Hermes refused to start it, with its own words in `message`.
  refused,

  /// The connection was refused or protected requests are not allowed.
  unreachable,

  /// The server has no such route.
  unsupported,

  /// The check stopped with no output the app can read.
  exited,
}

/// Runs Hermes' read-only `doctor` and follows it to its report.
///
/// One run at a time. The request is sent once per [run]: an answer that is
/// lost is "may have started" and is settled by reading the action, never by
/// sending again. The action's log keeps earlier runs and its status can
/// still describe one when the answer was lost, so only the lines after the
/// latest start header count, and after a lost answer only a run that is
/// going now or began with a new header is taken for this one.
///
/// What the check printed can hold paths and configuration names: it is
/// kept in memory here, never in preferences, a breadcrumb, a span or a
/// log, and is dropped by [drop] (sign-out, server change), [cover] (App
/// Lock) and [profileChanged]. Nothing is resumed after the app is killed.
/// All timing is wall-clock through the injected clock and delay.
class ServerCheckController extends ChangeNotifier with SafeNotifier {
  ServerCheckController({
    required ServerCareRepository repository,
    ConnectionTelemetry telemetry = const ConnectionTelemetry(),
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
    VoidCallback? onUnsupported,
  }) : _onUnsupported = onUnsupported,
       _repository = repository,
       _telemetry = telemetry,
       _breadcrumbs = breadcrumbs,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// How long the action's status is read for, from the run or from Keep
  /// waiting.
  static const followWindow = Duration(minutes: 3);
  static const _interval = Duration(milliseconds: 1500);

  /// Lines asked for: the whole output of a run, which is a few dozen.
  static const _lines = 500;

  final ServerCareRepository _repository;
  final ConnectionTelemetry _telemetry;
  final Breadcrumbs _breadcrumbs;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  /// Called once a run found that the server has no doctor route, so the
  /// shell can hide the check even while its page is closed.
  final VoidCallback? _onUnsupported;

  CheckPhase _phase = CheckPhase.idle;
  CheckFailure? _failure;
  String? _message;
  DoctorReport? _report;
  List<String> _output = const [];
  String? _profile;
  DateTime? _runStarted;
  DateTime? _finishedAt;
  int _progress = 0;
  int _runId = 0;
  Future<void>? _running;
  Completer<void>? _wake;

  // What tells this run's lines from an earlier run's, when the answer to the
  // request was lost.
  bool _lost = false;
  bool _baselineRead = false;
  String? _baselineHeader;

  // The header of a run adopted while it was going, so it is also accepted
  // when it has finished.
  String? _adoptedHeader;

  CheckPhase get phase => _phase;

  /// True while a run is starting or being followed.
  bool get busy =>
      _phase == CheckPhase.starting || _phase == CheckPhase.running;

  /// The profile of the run in progress or of the result; null when idle.
  String? get profile => _profile;

  /// The last finished run's report; null until one finished, and after
  /// [drop].
  DoctorReport? get report => _report;

  /// The last finished run's output, without ANSI escapes, one entry per
  /// non-empty line, so what no rule matched can be shown as it was written.
  List<String> get lines => _output;

  /// When the report was read.
  DateTime? get finishedAt => _finishedAt;

  /// With [CheckPhase.failed].
  CheckFailure? get failure => _failure;

  /// Hermes' own text for a failed run: its refusal, or the last lines of a
  /// check that stopped. Shown to the person, never logged.
  String? get message => _message;

  /// While running: how many checks have come in so far.
  int get progress => _progress;

  /// Runs a check for [profile]. While one is going a second call joins it
  /// and sends nothing; after a timeout it does nothing either, since that
  /// run may still end (see [keepWaiting]). After a result or a failure it
  /// starts a new run.
  Future<void> run({required String profile}) {
    final running = _running;
    if (running != null && busy) return running;
    if (disposed || _phase == CheckPhase.timedOut) return Future.value();
    final id = ++_runId;
    _clear();
    late final Future<void> done;
    done = _execute(profile, id).whenComplete(() {
      if (identical(_running, done)) _running = null;
    });
    _running = done;
    return done;
  }

  /// After a timeout: reads the same run for another [followWindow]. Sends
  /// no request to start one.
  Future<void> keepWaiting() {
    if (disposed || _phase != CheckPhase.timedOut) return Future.value();
    final id = _runId;
    _failure = null;
    _enter(CheckPhase.running);
    late final Future<void> done;
    done = _track(id, continued: true).whenComplete(() {
      if (identical(_running, done)) _running = null;
    });
    _running = done;
    return done;
  }

  /// Goes back to idle after a timeout or a failure, forgetting the run.
  void dismiss() {
    if (busy || _phase == CheckPhase.idle) return;
    drop();
  }

  /// Forgets the result and ends a run in flight: nothing it reads after
  /// this is kept.
  void drop() {
    _runId++;
    _running = null;
    _clear();
    notifyListeners();
  }

  /// App Lock covers the app: the output goes, and a run in flight is let go.
  void cover() {
    if (_phase == CheckPhase.idle && _report == null) return;
    drop();
  }

  /// The chat's profile changed: a result or run for another profile goes.
  void profileChanged(String? profile) {
    if (_profile == null || profile == _profile) return;
    drop();
  }

  /// The app came back to the front: the next read happens now instead of
  /// when a timer that the suspended app never ran would have fired.
  void resumed() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  @override
  void dispose() {
    _runId++;
    resumed();
    _clear();
    super.dispose();
  }

  void _clear() {
    _phase = CheckPhase.idle;
    _failure = null;
    _message = null;
    _report = null;
    _output = const [];
    _profile = null;
    _runStarted = null;
    _finishedAt = null;
    _progress = 0;
    _lost = false;
    _baselineRead = false;
    _baselineHeader = null;
    _adoptedHeader = null;
  }

  void _enter(CheckPhase phase) {
    if (disposed) return;
    _phase = phase;
    notifyListeners();
  }

  bool _stale(int id) => disposed || id != _runId;

  Future<void> _execute(String profile, int id) async {
    _profile = profile;
    _runStarted = _now();
    _enter(CheckPhase.starting);
    _breadcrumbs('server_care.check.started');
    await _track(id, profile: profile);
  }

  /// Follows the run and records how it ended: one span and one event, with
  /// fixed names and counts only.
  Future<void> _track(int id, {String? profile, bool continued = false}) async {
    final started = _now();
    Span? span;
    _quiet(
      () => span = _telemetry.tracer?.startSpan(
        'server_care.check',
        attributes: {
          ..._telemetry.serverAttributes,
          if (continued) 'continued': true,
        },
      ),
    );
    String? outcome;
    try {
      outcome = profile == null ? await _poll(id) : await _start(profile, id);
    } finally {
      final finished = outcome;
      if (finished != null) {
        final report = _report;
        final problems = _bucket(report?.problems ?? 0);
        final warnings = _bucket(report?.warnings ?? 0);
        _quiet(() {
          span?.setAttribute('outcome', finished);
          span?.setAttribute('problems', problems);
          span?.setAttribute('warnings', warnings);
          span?.setAttribute(
            'unknown_lines',
            _bucket(report?.unknownLines ?? 0),
          );
          span?.setAttribute(
            'duration',
            _durationBucket(_now().difference(_runStarted ?? started)),
          );
        });
        _quiet(
          () => _telemetry.events('server_care.check_finished', {
            'outcome': finished,
            'problems': problems,
            'warnings': warnings,
          }),
        );
      }
      _quiet(() => span?.end());
    }
  }

  /// Returns the outcome (`done`, `failed`, `timeout`); null when the run was
  /// dropped.
  Future<String?> _start(String profile, int id) async {
    // What the log said before this run, to tell its lines from the new
    // run's if the answer to the request is lost.
    final before = await _repository.actionStatus(
      CareAction.doctor,
      lines: _lines,
    );
    if (_stale(id)) return null;
    switch (before) {
      case CareUnsupported():
        // The run could not be followed, so it is not started.
        return _fail(CheckFailure.unsupported, null);
      case CareOk(:final value):
        _baselineRead = true;
        _baselineHeader = value.startHeader;
        if (value.running) {
          // A doctor is going already (this device earlier, or another
          // client): follow it instead of starting a second one.
          _lost = true;
          _adoptedHeader = value.startHeader;
          _enter(CheckPhase.running);
          return _poll(id);
        }
      case CareFailed():
        break;
    }
    final started = await _repository.startDoctor(profile: profile);
    if (_stale(id)) return null;
    switch (started) {
      case CareOk():
        break;
      case CareFailed(
        kind: CareFailureKind.offline ||
            CareFailureKind.unreadable ||
            CareFailureKind.server,
        message: null,
      ):
        // The answer is lost: it may have started. Never send it again.
        _lost = true;
      case CareFailed(:final kind, :final message):
        return _fail(
          kind == CareFailureKind.unauthorized
              ? CheckFailure.unreachable
              : CheckFailure.refused,
          message,
        );
      case CareUnsupported():
        return _fail(CheckFailure.unsupported, null);
    }
    _enter(CheckPhase.running);
    return _poll(id);
  }

  Future<String?> _poll(int id) async {
    final from = _now();
    while (true) {
      final result = await _repository.actionStatus(
        CareAction.doctor,
        lines: _lines,
      );
      if (_stale(id)) return null;
      switch (result) {
        case CareOk(:final value):
          if (_isThisRun(value)) {
            if (value.running) {
              _count(value);
            } else {
              return _finish(value);
            }
          }
        case CareUnsupported():
          return _fail(CheckFailure.unsupported, null);
        case CareFailed(:final kind, :final message):
          switch (kind) {
            case CareFailureKind.unauthorized:
              return _fail(CheckFailure.unreachable, null);
            case CareFailureKind.refused || CareFailureKind.storeUnreadable:
              return _fail(CheckFailure.refused, message);
            case CareFailureKind.offline ||
                CareFailureKind.server ||
                CareFailureKind.unreadable:
              break;
          }
      }
      if (_passed(from, followWindow)) {
        _enter(CheckPhase.timedOut);
        return 'timeout';
      }
      await _wait();
      if (_stale(id)) return null;
    }
  }

  /// Whether [status] describes this run. Normally the request's answer says
  /// so. After a lost answer the log may still hold an earlier, finished run:
  /// only a run going now, or one with a header the log did not have before,
  /// is this one.
  bool _isThisRun(ActionStatus status) {
    if (!_lost) return true;
    final header = status.startHeader;
    if (status.running) {
      _adoptedHeader ??= header;
      return true;
    }
    if (header == null || !_baselineRead) return false;
    return header != _baselineHeader || header == _adoptedHeader;
  }

  /// Whether [window] has passed since [since]. A clock set backwards makes
  /// the difference negative; that counts as passed, so no wait can last for
  /// ever.
  bool _passed(DateTime since, Duration window) {
    final elapsed = _now().difference(since);
    return elapsed.isNegative || elapsed >= window;
  }

  /// Counts the checks of a run that is still going.
  void _count(ActionStatus status) {
    final report = DoctorReport.parse(status.lines);
    final count = report.problems + report.warnings + report.passed;
    if (count == _progress) return;
    _progress = count;
    notifyListeners();
  }

  String _finish(ActionStatus status) {
    final output = [
      for (final line in status.lines)
        if (DoctorReport.clean(line).trim().isNotEmpty)
          DoctorReport.clean(line),
    ];
    final report = DoctorReport.parse(status.lines);
    final code = status.exitCode;
    // Hermes exits 0 when nothing needs attention and 1 with something to
    // address, which it lists. Any other end, or none, with nothing found is
    // a check that stopped part-way, not a report.
    final found =
        report.problems > 0 || report.warnings > 0 || report.fixes.isNotEmpty;
    final complete =
        report.allPassed || found || (code == 0 && output.isNotEmpty);
    if (!complete) return _fail(CheckFailure.exited, _tail(output));
    _report = report;
    _output = List.unmodifiable(output);
    _finishedAt = _now();
    _enter(CheckPhase.finished);
    return 'done';
  }

  String _fail(CheckFailure failure, String? message) {
    if (failure == CheckFailure.unsupported) {
      _quiet(() => _onUnsupported?.call());
    }
    _failure = failure;
    _message = message;
    _enter(CheckPhase.failed);
    return 'failed';
  }

  Future<void> _wait() async {
    final wake = _wake = Completer<void>();
    try {
      await Future.any([_delay(_interval), wake.future]);
    } finally {
      if (identical(_wake, wake)) _wake = null;
    }
  }

  static String? _tail(List<String> lines) {
    if (lines.isEmpty) return null;
    final text = [for (final line in lines) line.trim()];
    return text.skip(text.length > 5 ? text.length - 5 : 0).join('\n');
  }

  static String _bucket(int count) => switch (count) {
    0 => '0',
    <= 3 => '1-3',
    <= 10 => '4-10',
    _ => '>10',
  };

  static String _durationBucket(Duration d) => switch (d.inSeconds) {
    <= 10 => '0-10s',
    <= 30 => '11-30s',
    <= 90 => '31-90s',
    _ => '>90s',
  };

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
