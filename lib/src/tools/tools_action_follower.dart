import 'dart:async';

import 'hermes_tools_repository.dart';
import 'tools_models.dart';

/// How long an action may run without an end before the app stops waiting,
/// counted from the start. Hermes' own install can take about 20 minutes.
const kToolsActionPatience = Duration(minutes: 22);

/// How often the status of an action is read.
const kToolsActionInterval = Duration(seconds: 2);

/// The log lines the screen shows.
const kToolsLogLines = 6;

enum ActionEnd {
  /// The process exited with 0. The caller still reads the real state.
  succeeded,
  failed,

  /// The end cannot be tied to the run the app started, or has no exit code.
  unknown,
}

/// Follows one of Hermes' background actions (`/api/actions/<name>/status`)
/// until it ends.
///
/// Hermes keeps one log and one process slot per action for the whole
/// dashboard, so another client or profile can replace the run. An end counts
/// as the app's own only when its process id matches the one the app knows;
/// everything else, a missing exit code included, is [ActionEnd.unknown].
/// A failed read is not an end: the next one runs after [interval].
class ActionFollower {
  ActionFollower({
    required this.fetch,
    required this.onProgress,
    required this.onEnd,
    this.pid,
    this.mustSeeRunning = false,
    this.interval = kToolsActionInterval,
    this.patience = kToolsActionPatience,
  });

  final Future<ToolsResult<ToolsActionStatus>> Function(int lines) fetch;

  /// The last [kToolsLogLines] lines, for display only.
  final void Function(List<String> lines) onProgress;
  final void Function(ActionEnd end, int? exitCode) onEnd;
  final Duration interval;
  final Duration patience;

  /// The process the app started; null when the start gave none, in which
  /// case the first run seen binds it.
  int? pid;

  /// An end counts only after the run was seen running: for a run the app did
  /// not start itself, whose old log may still be in the slot.
  final bool mustSeeRunning;

  Timer? _timer;
  Timer? _patience;
  var _sawRunning = false;
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
    switch (result) {
      case ToolsOk(:final value):
        _apply(value);
      case ToolsUnsupported():
        _end(ActionEnd.unknown, null);
      default:
        break;
    }
    if (!_done) _timer = Timer(interval, () => unawaited(_poll()));
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
    if (code == null || (mustSeeRunning && !_sawRunning)) {
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
