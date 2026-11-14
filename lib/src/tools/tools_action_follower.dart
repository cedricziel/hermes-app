import 'dart:async';

import 'hermes_tools_repository.dart';
import 'tools_models.dart';

/// How long an action may run without an end before the app stops waiting,
/// counted from the start. Hermes' own install can take about 20 minutes.
const kToolsActionPatience = Duration(minutes: 22);

/// How often the status of an action is read; also the first back-off step.
const kToolsActionInterval = Duration(seconds: 2);

/// The log lines the screen shows.
const kToolsLogLines = 6;

/// How many reads in a row may fail before the follow gives up.
const kToolsFollowFailures = 3;

enum ActionEnd {
  /// The process exited with 0. The caller still reads the real state.
  succeeded,
  failed,

  /// The end cannot be tied to the run the app started, or has no exit code.
  unknown,

  /// [kToolsFollowFailures] reads in a row failed. The run's fate is unknown;
  /// the caller reads the real state and may offer to check again.
  lost,
}

/// Follows one of Hermes' background actions (`/api/actions/<name>/status`)
/// until it ends.
///
/// Hermes keeps one log and one process slot per action for the whole
/// dashboard, so another client or profile can replace the run, and the log
/// of an earlier run stays in the slot. An end counts as the app's own only
/// when it can be tied to the run: the process id the app knows matches, or
/// the run was seen running (which binds its id). A finished status with no
/// id or another one, a missing exit code and a run never seen running are
/// all [ActionEnd.unknown].
///
/// A failed read is not an end. It is reported through [onFailing], the next
/// read waits twice as long as the last ([interval], then double), and after
/// [kToolsFollowFailures] in a row the follow ends as [ActionEnd.lost].
class ActionFollower {
  ActionFollower({
    required this.fetch,
    required this.onProgress,
    required this.onEnd,
    this.onFailing,
    this.pid,
    this.mustSeeRunning = false,
    this.waitForRun = false,
    this.interval = kToolsActionInterval,
    this.patience = kToolsActionPatience,
  });

  final Future<ToolsResult<ToolsActionStatus>> Function(int lines) fetch;

  /// The last [kToolsLogLines] lines, for display only.
  final void Function(List<String> lines) onProgress;
  final void Function(ActionEnd end, int? exitCode) onEnd;

  /// Called with true on the first failed read after a good one, and with
  /// false when a read works again.
  final void Function({required bool failing})? onFailing;
  final Duration interval;
  final Duration patience;

  /// The process the app started; null when it is not known, in which case
  /// an end counts only after the run was seen running.
  int? pid;

  /// An end counts only after the run was seen running, even when [pid] is
  /// known.
  final bool mustSeeRunning;

  /// A finished log that was never seen running is ignored instead of ending
  /// the follow: the app does not know whether its start went through, so an
  /// earlier run's log must not decide.
  final bool waitForRun;

  Timer? _timer;
  Timer? _patience;
  var _sawRunning = false;
  var _failures = 0;
  var _done = false;

  bool get running => !_done;

  void start() {
    _patience = Timer(patience, () => _end(ActionEnd.unknown, null));
    unawaited(_poll());
  }

  void cancel() {
    _done = true;
    _timer?.cancel();
    _patience?.cancel();
  }

  Future<void> _poll() async {
    ToolsResult<ToolsActionStatus> result;
    try {
      result = await fetch(kToolsLogLines * 4);
    } on Object {
      result = const ToolsFailed(ToolsFailure.server);
    }
    if (_done) return;
    var wait = interval;
    switch (result) {
      case ToolsOk(:final value):
        if (_failures > 0) {
          _failures = 0;
          onFailing?.call(failing: false);
        }
        _apply(value);
      case ToolsUnsupported():
        _end(ActionEnd.unknown, null);
      default:
        _failures++;
        if (_failures >= kToolsFollowFailures) {
          _end(ActionEnd.lost, null);
        } else {
          if (_failures == 1) onFailing?.call(failing: true);
          wait = interval * (1 << (_failures - 1));
        }
    }
    if (!_done) _timer = Timer(wait, () => unawaited(_poll()));
  }

  void _apply(ToolsActionStatus status) {
    final seen = status.pid;
    if (seen != null) {
      if (pid == null && status.running) {
        pid = seen;
      } else if (pid != null && seen != pid) {
        return _end(ActionEnd.unknown, null);
      }
    }
    final lines = [
      for (final line in status.lines)
        if (line.trim().isNotEmpty) line.trimRight(),
    ];
    onProgress(
      lines.length > kToolsLogLines
          ? lines.sublist(lines.length - kToolsLogLines)
          : lines,
    );
    if (status.running) {
      _sawRunning = true;
      return;
    }
    final code = status.exitCode;
    if (code == null) return _end(ActionEnd.unknown, null);
    final tied = _sawRunning || (pid != null && seen == pid && !mustSeeRunning);
    if (!tied) {
      // An earlier run's finished log. With nothing known about the start it
      // is not an answer yet.
      if (waitForRun) return;
      return _end(ActionEnd.unknown, null);
    }
    _end(code == 0 ? ActionEnd.succeeded : ActionEnd.failed, code);
  }

  void _end(ActionEnd end, int? code) {
    if (_done) return;
    cancel();
    onEnd(end, code);
  }
}
