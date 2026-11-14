import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_controller.dart' show ToolsLoadState, kToolsCheckTimeout;
import 'tools_models.dart';
import 'tools_write.dart';

/// The name Hermes gives the backend that runs commands on its own machine.
const kLocalTerminalBackend = 'local';

/// Where the Terminal toolset runs commands: the backends Hermes lists and the
/// pick between them.
///
/// Choosing `local` runs commands directly on the server, so nothing is sent
/// until [confirmLocal] answers true; this controller never asks itself. A
/// backend that still needs setup may be picked (Hermes allows it, and shows
/// guidance): [activeNeedsSetup] tells the screen to say commands will fail
/// until it is set up. A lost answer reads the list again for at most
/// [checkTimeout] and never sends the pick again.
///
/// Holds no text. The span `tools.terminal_backend` carries `outcome` only;
/// backend names and Hermes' `detail` text are shown, never logged.
class TerminalBackendsController extends ChangeNotifier with SafeNotifier {
  TerminalBackendsController(
    HermesToolsRepository repository, {
    required this.confirmLocal,
    this.telemetry = const ConnectionTelemetry(),
    this.checkTimeout = kToolsCheckTimeout,
  }) : _repository = repository;

  HermesToolsRepository _repository;

  /// Asks "Run commands directly on your server?". A throw counts as no.
  final Future<bool> Function() confirmLocal;
  final ConnectionTelemetry telemetry;
  final Duration checkTimeout;

  var _epoch = 0;
  var _state = ToolsLoadState.loading;
  var _hasLoaded = false;
  TerminalBackends? _backends;
  var _pick = ToolsWriteState.idle;
  String? _detail;
  var _writing = false;

  ToolsLoadState get loadState => _state;
  bool get hasLoaded => _hasLoaded;

  /// The backends; the last good read stays when a later one fails.
  List<TerminalBackend> get backends => _backends?.backends ?? const [];
  String? get active => _backends?.active;
  ToolsWriteState get pickState => _pick;

  /// Hermes' own text when it refused the last pick.
  String? get refusalDetail => _detail;

  /// The active backend is not ready: commands fail until it is set up on the
  /// server.
  bool get activeNeedsSetup =>
      backends.any((b) => b.name == active && b.status != BackendStatus.ready);

  bool _stale(int epoch) => disposed || epoch != _epoch;

  Future<void> load() async {
    final epoch = _epoch;
    if (!_hasLoaded) {
      _state = ToolsLoadState.loading;
      notifyListeners();
    }
    final result = await _repository.terminalBackends();
    if (_stale(epoch)) return;
    _apply(result);
    notifyListeners();
  }

  bool _apply(ToolsResult<TerminalBackends> result) {
    switch (result) {
      case ToolsOk(:final value):
        _backends = value;
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

  /// Hands the controller to another profile; answers still on their way are
  /// dropped.
  void switchProfile(HermesToolsRepository repository) {
    _epoch++;
    _repository = repository;
    _backends = null;
    _hasLoaded = false;
    _state = ToolsLoadState.loading;
    _pick = ToolsWriteState.idle;
    _detail = null;
    _writing = false;
    notifyListeners();
  }

  /// Picks [name], once. Only a name Hermes listed is sent, and the active
  /// one is not sent again.
  Future<void> pick(String name) async {
    if (_writing || name == active || !backends.any((b) => b.name == name)) {
      return;
    }
    final epoch = _epoch;
    _writing = true;
    try {
      await _pickBackend(epoch, name);
    } finally {
      if (epoch == _epoch) _writing = false;
    }
  }

  Future<void> _pickBackend(int epoch, String name) async {
    if (name == kLocalTerminalBackend) {
      var confirmed = false;
      try {
        confirmed = await confirmLocal();
      } on Object {
        confirmed = false;
      }
      if (_stale(epoch) || !confirmed) return;
    }
    _pick = ToolsWriteState.saving;
    _detail = null;
    notifyListeners();

    final span = startToolsSpan(telemetry, 'tools.terminal_backend', {});
    final result = await _repository.pickTerminalBackend(name);
    quietly(() {
      endToolsSpan(span, result.outcome);
      span?.end();
    });
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk():
        _pick = ToolsWriteState.idle;
        final fresh = await _repository.terminalBackends();
        if (_stale(epoch)) return;
        _apply(fresh);
      case ToolsRefused(:final detail):
        _detail = detail;
        _pick = ToolsWriteState.refused;
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        _pick = ToolsWriteState.checking;
        notifyListeners();
        ToolsResult<TerminalBackends>? fresh;
        try {
          fresh = await _repository.terminalBackends().timeout(checkTimeout);
        } on TimeoutException {
          fresh = null;
        }
        if (_stale(epoch)) return;
        _pick = fresh == null || !_apply(fresh)
            ? ToolsWriteState.unconfirmed
            : (active == name
                  ? ToolsWriteState.idle
                  : ToolsWriteState.notApplied);
      default:
        _pick = ToolsWriteState.failed;
    }
    if (_stale(epoch)) return;
    notifyListeners();
  }
}
