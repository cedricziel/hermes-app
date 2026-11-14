import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_action_follower.dart';
import 'tools_controller.dart' show ToolsLoadState, kToolsCheckTimeout;
import 'tools_models.dart';
import 'tools_write.dart';

enum ComputerUseGrantPhase {
  idle,

  /// `grant` is on its way.
  starting,

  /// The permission window is open on the server's Mac; its log is followed.
  running,

  /// The action ended, or its answer was lost: the status is being read.
  checking,

  /// The status was read again. [ComputerUseController.status] is the result,
  /// whatever the log said.
  finished,

  /// The re-read failed; the status shows what was known before.
  unconfirmed,

  /// Hermes refused (not a macOS server, for one); the controller holds its
  /// text.
  refused,
  failed,
}

/// The Computer use readiness section and its "Allow access" step.
///
/// [grant] opens a permission window on the server's Mac, so nothing is sent
/// until [confirmGrant] answers true; the controller never asks itself, and
/// offers the grant only when [ComputerUseStatus.canOfferGrant]. The grant has
/// its own action slot (`computer-use-grant`), followed here with
/// [ActionFollower] while this controller lives; leaving the screen drops the
/// follow, and the status read when it opens again shows the result. When the
/// action ends, or the answer to the start was lost, the status is read
/// again: the result comes from that read, never from the log. A lost answer
/// is never sent again.
///
/// Holds no text. The span `tools.computer_use` carries `action` (status or
/// grant) and `outcome` only; `error`, the checks and the log lines are shown,
/// never logged.
class ComputerUseController extends ChangeNotifier with SafeNotifier {
  ComputerUseController(
    HermesToolsRepository repository, {
    required this.confirmGrant,
    this.telemetry = const ConnectionTelemetry(),
    this.interval = kToolsActionInterval,
    this.patience = kToolsActionPatience,
    this.checkTimeout = kToolsCheckTimeout,
  }) : _repository = repository;

  HermesToolsRepository _repository;

  /// Asks "Allow access on the server's Mac?". A throw counts as no.
  final Future<bool> Function() confirmGrant;
  final ConnectionTelemetry telemetry;
  final Duration interval;
  final Duration patience;

  /// How long the status read after a grant may take.
  final Duration checkTimeout;

  var _epoch = 0;
  var _state = ToolsLoadState.loading;
  var _hasLoaded = false;
  ComputerUseStatus? _status;
  var _phase = ComputerUseGrantPhase.idle;
  var _lines = const <String>[];
  String? _detail;
  ActionFollower? _follower;
  var _followFailing = false;
  var _followLost = false;
  int? _pid;

  ToolsLoadState get loadState => _state;
  bool get hasLoaded => _hasLoaded;

  /// The last good read; stays when a later one fails.
  ComputerUseStatus? get status => _status;

  /// "Allow access" may be offered: the server is a Mac with the driver
  /// installed and a permission known to be missing, and no grant is running.
  bool get canOfferGrant => (_status?.canOfferGrant ?? false) && !grantBusy;
  ComputerUseGrantPhase get grantPhase => _phase;

  bool get grantBusy =>
      _phase == ComputerUseGrantPhase.starting ||
      _phase == ComputerUseGrantPhase.running ||
      _phase == ComputerUseGrantPhase.checking;

  /// Reads of the grant's log are failing and being retried.
  bool get followFailing => _followFailing;

  /// The follow gave up on failed reads; [checkAgain] resumes it.
  bool get followLost => _followLost && !grantBusy;

  /// The last six lines of the grant's log. Shown, never logged.
  List<String> get grantLines => _lines;

  /// Hermes' own text when it refused the grant.
  String? get refusalDetail => _detail;

  bool _stale(int epoch) => disposed || epoch != _epoch;

  Future<void> load() async {
    final epoch = _epoch;
    if (!_hasLoaded) {
      _state = ToolsLoadState.loading;
      notifyListeners();
    }
    final span = startToolsSpan(telemetry, 'tools.computer_use', {
      'action': 'status',
    });
    final result = await _repository.computerUseStatus();
    endToolsSpan(span, result.outcome);
    if (_stale(epoch)) return;
    _apply(result);
    notifyListeners();
  }

  /// Takes a read. After a grant ([readBack]) a failed read changes nothing:
  /// the status that was loaded stays on screen.
  bool _apply(ToolsResult<ComputerUseStatus> result, {bool readBack = false}) {
    if (readBack && result is! ToolsOk<ComputerUseStatus>) return false;
    switch (result) {
      case ToolsOk(:final value):
        _status = value;
        _hasLoaded = true;
        _state = ToolsLoadState.ready;
        return true;
      case ToolsUnsupported():
        _state = ToolsLoadState.unsupported;
      case ToolsProfileGone():
        _state = ToolsLoadState.profileGone;
      case ToolsRefused():
        _state = ToolsLoadState.failed;
      case ToolsFailed(:final kind):
        _state = switch (kind) {
          ToolsFailure.offline => ToolsLoadState.offline,
          ToolsFailure.unauthorized => ToolsLoadState.unauthorized,
          _ => ToolsLoadState.failed,
        };
    }
    return false;
  }

  /// Hands the controller to another profile and stops following a grant.
  void switchProfile(HermesToolsRepository repository) {
    _epoch++;
    _follower?.cancel();
    _follower = null;
    _repository = repository;
    _status = null;
    _hasLoaded = false;
    _state = ToolsLoadState.loading;
    _phase = ComputerUseGrantPhase.idle;
    _lines = const [];
    _detail = null;
    _followFailing = false;
    _followLost = false;
    _pid = null;
    notifyListeners();
  }

  /// Asks, then starts the grant on the server's Mac, once. Does nothing
  /// unless [canOfferGrant].
  Future<void> grant() async {
    if (!canOfferGrant) return;
    final epoch = _epoch;
    // Holds the slot while the question is open, so a second tap waits.
    _phase = ComputerUseGrantPhase.starting;
    _detail = null;
    _lines = const [];
    _followLost = false;
    _pid = null;
    notifyListeners();
    var confirmed = false;
    try {
      confirmed = await confirmGrant();
    } on Object {
      confirmed = false;
    }
    if (_stale(epoch)) return;
    // A read may have run while the question was open and shown that the
    // grant is no longer needed or possible.
    if (!confirmed || !(_status?.canOfferGrant ?? false)) {
      _phase = ComputerUseGrantPhase.idle;
      notifyListeners();
      return;
    }

    final span = startToolsSpan(telemetry, 'tools.computer_use', {
      'action': 'grant',
    });
    final result = await _repository.grantComputerUse();
    endToolsSpan(span, result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk(:final value):
        _phase = ComputerUseGrantPhase.running;
        notifyListeners();
        _follow(epoch, value.pid);
        return;
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        // The window may be open on the Mac. Never ask for it again, and
        // follow the log read-only: the slot is not known to be free.
        _phase = ComputerUseGrantPhase.running;
        notifyListeners();
        _follow(epoch, null, waitForRun: true);
        return;
      case ToolsRefused(:final detail):
        _detail = detail;
        _phase = ComputerUseGrantPhase.refused;
      default:
        _phase = ComputerUseGrantPhase.failed;
    }
    notifyListeners();
  }

  /// After the follow gave up on failed reads: follows the log again,
  /// read-only. Does nothing otherwise.
  void checkAgain() {
    if (!followLost) return;
    final epoch = _epoch;
    _followLost = false;
    _phase = ComputerUseGrantPhase.running;
    notifyListeners();
    _follow(epoch, _pid);
  }

  void _follow(int epoch, int? pid, {bool waitForRun = false}) {
    _pid = pid;
    _follower = ActionFollower(
      fetch: (lines) => _repository.grantStatus(lines: lines),
      pid: pid,
      mustSeeRunning: pid == null && !waitForRun,
      waitForRun: waitForRun,
      interval: interval,
      patience: patience,
      onProgress: (lines) {
        if (_stale(epoch)) return;
        _pid = _follower?.pid ?? _pid;
        _lines = List.unmodifiable(lines);
        notifyListeners();
      },
      onFailing: ({required failing}) {
        if (_stale(epoch)) return;
        _followFailing = failing;
        notifyListeners();
      },
      onEnd: (end, code) {
        _pid = _follower?.pid ?? _pid;
        _follower = null;
        if (_stale(epoch)) return;
        _followFailing = false;
        _followLost = end == ActionEnd.lost;
        unawaited(_readAfter(epoch));
      },
    )..start();
  }

  Future<void> _readAfter(int epoch) async {
    _phase = ComputerUseGrantPhase.checking;
    notifyListeners();
    ToolsResult<ComputerUseStatus> result;
    try {
      result = await _repository.computerUseStatus().timeout(checkTimeout);
    } on TimeoutException {
      result = const ToolsFailed(ToolsFailure.timeout);
    }
    if (_stale(epoch)) return;
    _phase = _apply(result, readBack: true)
        ? ComputerUseGrantPhase.finished
        : ComputerUseGrantPhase.unconfirmed;
    notifyListeners();
  }

  @override
  void dispose() {
    if (disposed) return;
    _follower?.cancel();
    _follower = null;
    super.dispose();
  }
}
