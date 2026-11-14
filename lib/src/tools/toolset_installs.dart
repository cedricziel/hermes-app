import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_action_follower.dart';
import 'tools_write.dart';

enum ToolsInstallPhase {
  /// `post-setup` is on its way.
  starting,
  running,

  /// The process exited with 0. This is not "Installed": the screen says
  /// "Checking…" until the config it asked for has been read again.
  succeeded,
  failed,

  /// "Can't tell": no exit code, a run that is not the app's own, a lost
  /// answer to the start, or [kToolsActionPatience] without an end.
  unknown,

  /// Hermes refused the key; [ToolsInstallState.detail] is its own text.
  refused,

  /// The start failed and nothing is known to run.
  notStarted,
}

class ToolsInstallState {
  const ToolsInstallState({
    required this.phase,
    this.toolset,
    this.key,
    this.lines = const [],
    this.exitCode,
    this.switchStarted = false,
    this.detail,
    this.failure,
    this.followFailing = false,
    this.followLost = false,
    this.startLost = false,
  });

  final ToolsInstallPhase phase;

  /// The toolset the install is for, when the caller knew it.
  final String? toolset;

  /// The provider's install key. Shown, never logged.
  final String? key;

  /// The last [kToolsLogLines] log lines. Shown, never logged.
  final List<String> lines;
  final int? exitCode;

  /// Hermes started it because a switch turned the toolset on; the app only
  /// follows it.
  final bool switchStarted;
  final String? detail;
  final ToolsFailure? failure;

  /// Reads of the status are failing and being retried: "Couldn't follow the
  /// install", with the run still counted as running.
  final bool followFailing;

  /// The follow gave up after repeated failed reads. [phase] is
  /// [ToolsInstallPhase.unknown]; the screen offers
  /// [ToolsetInstalls.checkAgain].
  final bool followLost;

  /// The answer to the start was lost: the install may be running and is
  /// followed read-only.
  final bool startLost;

  bool get active =>
      phase == ToolsInstallPhase.starting || phase == ToolsInstallPhase.running;

  ToolsInstallState copyWith({
    ToolsInstallPhase? phase,
    List<String>? lines,
    int? exitCode,
    bool? followFailing,
    bool? followLost,
  }) => ToolsInstallState(
    phase: phase ?? this.phase,
    toolset: toolset,
    key: key,
    lines: lines ?? this.lines,
    exitCode: exitCode ?? this.exitCode,
    switchStarted: switchStarted,
    detail: detail,
    failure: failure,
    followFailing: followFailing ?? this.followFailing,
    followLost: followLost ?? this.followLost,
    startLost: startLost,
  );
}

/// What [ToolsetInstalls.startConfirmed] did.
enum ToolsInstallStart {
  started,

  /// An install already runs on this connection; nothing was sent.
  busy,

  /// The object was disposed or cleared (sign-out) meanwhile.
  dropped,
  refused,
  notStarted,

  /// The answer was lost. The install may run, so it stays busy and is
  /// followed read-only; nothing is sent again.
  unknown,
}

/// The one install step of a Hermes connection, which outlives the Tools
/// screens.
///
/// There is one per connection (the shell owns it and calls [clear] on
/// sign-out), because Hermes keeps one log and one process slot for
/// `tools-post-setup` for the whole dashboard, shared by every profile and
/// toolset and by the install a switch starts. So it runs one at a time.
///
/// The install step downloads and runs software on the server: this object
/// never asks, so [startConfirmed] is only called after the user said yes.
/// It follows `GET /api/actions/tools-post-setup/status` and, whatever the
/// end, asks [requestReread] for the toolset's config: the result is read
/// from there, never from the log. Log lines are shown, never logged; the
/// span `tools.setup` (`step: post_setup`) and the event `tools.setup_outcome`
/// carry the outcome only.
///
/// An end with no screen open is not lost: [requestReread] has no listener
/// then, and the next screen reads the config when it opens, which is where
/// the result shows.
///
/// The macOS permission grant has its own slot and is followed by
/// `ComputerUseController`, which shares [ActionFollower] with this.
class ToolsetInstalls extends ChangeNotifier with SafeNotifier {
  ToolsetInstalls({
    required this.requestReread,
    this.telemetry = const ConnectionTelemetry(),
    this.interval = kToolsActionInterval,
    this.patience = kToolsActionPatience,
  });

  /// Asks the open screen to read the toolset's config again. [toolset] is
  /// null when the install was followed without knowing which one it is for.
  final void Function(String? toolset) requestReread;
  final ConnectionTelemetry telemetry;
  final Duration interval;
  final Duration patience;

  ToolsInstallState? _state;
  ActionFollower? _follower;
  HermesToolsRepository? _repository;
  int? _pid;
  Span? _span;
  var _epoch = 0;

  /// The install this connection runs or last ran; null when none.
  ToolsInstallState? get state => _state;

  bool get busy => _state?.active ?? false;

  /// Starts [key]'s install step for [toolset]. Call it only after the user
  /// confirmed "Install on your server?". While one runs, nothing is sent.
  Future<ToolsInstallStart> startConfirmed(
    HermesToolsRepository repository,
    String toolset,
    String key,
  ) async {
    if (disposed) return ToolsInstallStart.dropped;
    if (busy) return ToolsInstallStart.busy;
    final epoch = ++_epoch;
    _repository = repository;
    _pid = null;
    _span = startToolsSpan(telemetry, 'tools.setup', {'step': 'post_setup'});
    _state = ToolsInstallState(
      phase: ToolsInstallPhase.starting,
      toolset: toolset,
      key: key,
    );
    notifyListeners();

    final result = await repository.startPostSetup(toolset, key);
    if (disposed || epoch != _epoch) return ToolsInstallStart.dropped;
    switch (result) {
      case ToolsOk(:final value):
        _state = _state!.copyWith(phase: ToolsInstallPhase.running);
        notifyListeners();
        _follow(repository, epoch, pid: value.pid);
        return ToolsInstallStart.started;
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        // It may run. Sending again could start a second one, and the slot
        // must not look free: follow it read-only until it ends.
        _state = ToolsInstallState(
          phase: ToolsInstallPhase.running,
          toolset: toolset,
          key: key,
          startLost: true,
        );
        notifyListeners();
        _follow(repository, epoch, pid: null, waitForRun: true);
        return ToolsInstallStart.unknown;
      case ToolsRefused(:final detail):
        _finishWith(
          ToolsInstallState(
            phase: ToolsInstallPhase.refused,
            toolset: toolset,
            key: key,
            detail: detail,
          ),
          'refused',
        );
        return ToolsInstallStart.refused;
      default:
        _finishWith(
          ToolsInstallState(
            phase: ToolsInstallPhase.notStarted,
            toolset: toolset,
            key: key,
            failure: switch (result) {
              ToolsFailed(:final kind) => kind,
              _ => ToolsFailure.server,
            },
          ),
          result.outcome,
        );
        return ToolsInstallStart.notStarted;
    }
  }

  /// Follows an install Hermes started because a switch turned [toolset] on
  /// (`ToolsController.postSetupStarted` names [key]). Read-only: nothing is
  /// sent. The answer carried no process id, so an end counts only after the
  /// run was seen running.
  bool followSwitchStarted(
    HermesToolsRepository repository,
    String key, {
    String? toolset,
  }) {
    if (disposed || busy) return false;
    final epoch = ++_epoch;
    _repository = repository;
    _pid = null;
    _span = startToolsSpan(telemetry, 'tools.setup', {'step': 'post_setup'});
    _state = ToolsInstallState(
      phase: ToolsInstallPhase.running,
      toolset: toolset,
      key: key,
      switchStarted: true,
    );
    notifyListeners();
    _follow(repository, epoch, pid: null);
    return true;
  }

  /// After the follow gave up on failed reads: reads the status again, still
  /// read-only, with the process id it knew. Does nothing otherwise.
  bool checkAgain() {
    final state = _state;
    final repository = _repository;
    if (disposed || busy || repository == null || state == null) return false;
    if (!state.followLost) return false;
    final epoch = ++_epoch;
    _span = startToolsSpan(telemetry, 'tools.setup', {'step': 'post_setup'});
    _state = state.copyWith(
      phase: ToolsInstallPhase.running,
      followLost: false,
    );
    notifyListeners();
    _follow(repository, epoch, pid: _pid);
    return true;
  }

  /// Drops a finished install's state once the screen showed it.
  void acknowledge() {
    if (_state == null || busy) return;
    _state = null;
    notifyListeners();
  }

  /// Sign-out or a server change: stops following and forgets everything.
  void clear() {
    _epoch++;
    _follower?.cancel();
    _follower = null;
    if (_span != null) {
      finishSetupStep(telemetry, _span, 'post_setup', 'unknown');
      _span = null;
    }
    _repository = null;
    _pid = null;
    if (_state != null) {
      _state = null;
      notifyListeners();
    }
  }

  void _follow(
    HermesToolsRepository repository,
    int epoch, {
    required int? pid,
    bool waitForRun = false,
  }) {
    _pid = pid;
    _follower = ActionFollower(
      fetch: (lines) => repository.postSetupStatus(lines: lines),
      pid: pid,
      mustSeeRunning: pid == null && !waitForRun,
      waitForRun: waitForRun,
      interval: interval,
      patience: patience,
      onProgress: (lines) {
        if (epoch != _epoch || _state == null) return;
        _pid = _follower?.pid ?? _pid;
        _state = _state!.copyWith(lines: List.unmodifiable(lines));
        notifyListeners();
      },
      onFailing: ({required failing}) {
        if (epoch != _epoch || _state == null) return;
        _state = _state!.copyWith(followFailing: failing);
        notifyListeners();
      },
      onEnd: (end, code) {
        if (epoch != _epoch || _state == null) return;
        _pid = _follower?.pid ?? _pid;
        final phase = switch (end) {
          ActionEnd.succeeded => ToolsInstallPhase.succeeded,
          ActionEnd.failed => ToolsInstallPhase.failed,
          ActionEnd.unknown || ActionEnd.lost => ToolsInstallPhase.unknown,
        };
        final toolset = _state!.toolset;
        _finishWith(
          _state!.copyWith(
            phase: phase,
            exitCode: code,
            followFailing: false,
            followLost: end == ActionEnd.lost,
          ),
          switch (end) {
            ActionEnd.succeeded => 'ok',
            ActionEnd.failed => 'failed',
            ActionEnd.unknown || ActionEnd.lost => 'unknown',
          },
        );
        _reread(toolset);
      },
    )..start();
  }

  void _finishWith(ToolsInstallState state, String outcome) {
    _follower = null;
    _state = state;
    finishSetupStep(telemetry, _span, 'post_setup', outcome);
    _span = null;
    notifyListeners();
  }

  void _reread(String? toolset) => quietly(() => requestReread(toolset));

  @override
  void dispose() {
    if (disposed) return;
    clear();
    super.dispose();
  }
}
