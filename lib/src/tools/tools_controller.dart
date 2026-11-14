import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'toolset_risk.dart';
import 'tools_models.dart';

/// How long "Checking…" may last after a write whose answer was lost.
const kToolsCheckTimeout = Duration(seconds: 10);

enum ToolsLoadState {
  loading,
  ready,

  /// The server has no tools routes (404 or 405): hide Tools, say nothing.
  unsupported,

  /// The profile no longer exists. Not "unsupported": read the profile list.
  profileGone,
  offline,
  unauthorized,
  failed,
}

/// Where a row is in switching. Only [saving] and [checking] show the
/// optimistic or pending state; [awaitingConfirmation] still shows the last
/// saved position and has sent nothing.
enum ToolsRowPhase {
  idle,

  /// Reading the toolset's setup to learn whether switching it on can start
  /// an installer. Nothing is sent yet.
  preparing,
  awaitingConfirmation,
  saving,

  /// The answer to a write was lost; the list is being read again.
  checking,

  /// The write's answer was lost and the re-read did not finish. The row
  /// shows the last saved state; nothing is sent again.
  unconfirmed,
}

enum ToolsRowErrorKind {
  /// Hermes refused the value; [ToolsRowError.detail] is its own text.
  refused,
  forbidden,
  offline,

  /// Anything else, including a setup read that failed before asking.
  failed,
}

class ToolsRowError {
  const ToolsRowError(this.kind, {this.detail});

  final ToolsRowErrorKind kind;

  /// Hermes' own words for a refusal. Shown, never logged.
  final String? detail;
}

/// What the confirmation question for one toolset says.
class ToolsConfirmation {
  const ToolsConfirmation({
    required this.toolset,
    required this.risk,
    required this.installsSoftware,
  });

  final Toolset toolset;

  /// Set for a toolset that asks because of what it can do.
  final ToolsetRisk? risk;

  /// One of its providers has an install step the switch may start.
  final bool installsSoftware;
}

/// A toolset's switching state, apart from the list.
class ToolsRowState {
  const ToolsRowState({
    this.phase = ToolsRowPhase.idle,
    this.shownEnabled,
    this.error,
  });

  final ToolsRowPhase phase;

  /// The position to show while saving; null means the saved one.
  final bool? shownEnabled;
  final ToolsRowError? error;

  bool get busy =>
      phase == ToolsRowPhase.preparing ||
      phase == ToolsRowPhase.awaitingConfirmation ||
      phase == ToolsRowPhase.saving ||
      phase == ToolsRowPhase.checking;
}

typedef ToolsGroups = ({
  List<Toolset> needsSetup,
  List<Toolset> on,
  List<Toolset> off,
});

/// What the Tools list shows and does for one profile: the toolsets, their
/// switching state, and the questions that come before a risky switch.
///
/// Every switch on a toolset asks nothing, one question, or two answers
/// before anything is sent: a toolset in the risk table at the confirm level,
/// and any toolset with a provider that has an install step, wait for
/// [confirm]. The optimistic position starts after that. A write whose
/// answer is lost is never sent again; the list is read instead.
///
/// [initial] is a list the shell already read for this profile: shown at once
/// as the first data, and [load] still reads it again.
///
/// The controller holds no text: the screen words each state.
class ToolsController extends ChangeNotifier with SafeNotifier {
  ToolsController(
    HermesToolsRepository repository, {
    this.telemetry = const ConnectionTelemetry(),
    this.checkTimeout = kToolsCheckTimeout,
    List<Toolset> initial = const [],
  }) : _repository = repository,
       _toolsets = initial,
       _hasLoaded = initial.isNotEmpty,
       _state = initial.isEmpty ? ToolsLoadState.loading : ToolsLoadState.ready;

  HermesToolsRepository _repository;
  final ConnectionTelemetry telemetry;
  final Duration checkTimeout;

  var _epoch = 0;
  List<Toolset> _toolsets;
  ToolsLoadState _state;
  bool _hasLoaded;
  final _rows = <String, ToolsRowState>{};
  final _installSteps = <String, bool>{};
  final _queued = <String, bool>{};
  ToolsConfirmation? _confirmation;
  String? _postSetupStarted;
  String? _postSetupToolset;
  var _changed = false;
  final _changedNames = <String>{};
  var _toolVanished = false;
  final _setupBusy = <String>{};

  /// The profile the list is for.
  String get profile => _repository.profile;

  List<Toolset> get toolsets => _toolsets;
  ToolsLoadState get loadState => _state;

  /// True once a list has been read; later failures keep the rows.
  bool get hasLoaded => _hasLoaded;

  /// The open question, if any. The screen shows it and answers with
  /// [confirm] or [cancel].
  ToolsConfirmation? get confirmation => _confirmation;

  /// The install step Hermes started because a switch turned a toolset on,
  /// until [clearPostSetupStarted].
  String? get postSetupStarted => _postSetupStarted;

  /// The toolset whose switch started that install.
  String? get postSetupToolset => _postSetupToolset;

  /// True after a switch succeeded: chats pick the change up from the next
  /// one on.
  bool get changedSinceOpen => _changed;

  /// True when a switch of [name] itself succeeded since the screen opened;
  /// the details show "Applies from your next chat" only for such a toolset.
  bool changedToolset(String name) => _changedNames.contains(name);

  /// True when a refused switch found its toolset gone from the server.
  bool get toolVanished => _toolVanished;

  ToolsRowState rowState(String name) => _rows[name] ?? const ToolsRowState();

  /// A setup write (a provider, a key, a model) of [name] is out. Its switch
  /// is disabled meanwhile, so a switch and a setup write never overlap.
  bool switchLocked(String name) => _setupBusy.contains(name);

  /// Tells the controller that the setup of [name] is [busy] with a write.
  void setSetupBusy(String name, {required bool busy}) {
    if (busy ? !_setupBusy.add(name) : !_setupBusy.remove(name)) return;
    notifyListeners();
  }

  /// The position of [toolset]'s switch.
  bool shownEnabled(Toolset toolset) =>
      rowState(toolset.name).shownEnabled ?? toolset.enabled;

  /// Rows by what works: needing setup first, then on, then off, each in the
  /// server's order. A row keeps its group until the list is read again.
  ToolsGroups get groups => (
    needsSetup: [
      for (final t in _toolsets)
        if (!t.configured) t,
    ],
    on: [
      for (final t in _toolsets)
        if (t.configured && t.enabled) t,
    ],
    off: [
      for (final t in _toolsets)
        if (t.configured && !t.enabled) t,
    ],
  );

  bool _stale(int epoch) => disposed || epoch != _epoch;

  /// Reads the list. Errors on rows go; rows already shown stay if it fails.
  Future<void> load() async {
    final epoch = _epoch;
    if (!_hasLoaded) {
      _state = ToolsLoadState.loading;
      notifyListeners();
    }
    final result = await _repository.list();
    if (_stale(epoch)) return;
    _applyList(result);
    notifyListeners();
  }

  /// Hands the controller to another profile. Answers still on their way for
  /// the old one are dropped.
  void switchProfile(HermesToolsRepository repository) {
    _epoch++;
    _repository = repository;
    _toolsets = const [];
    _state = ToolsLoadState.loading;
    _hasLoaded = false;
    _rows.clear();
    _installSteps.clear();
    _queued.clear();
    _setupBusy.clear();
    _confirmation = null;
    _postSetupStarted = null;
    _postSetupToolset = null;
    _changed = false;
    _changedNames.clear();
    _toolVanished = false;
    notifyListeners();
  }

  void clearPostSetupStarted() {
    _postSetupStarted = null;
    _postSetupToolset = null;
    notifyListeners();
  }

  void dismissVanished() {
    _toolVanished = false;
    notifyListeners();
  }

  void _applyList(ToolsResult<ToolsetList> result) {
    switch (result) {
      case ToolsOk(:final value):
        _toolsets = value.toolsets;
        _hasLoaded = true;
        _state = ToolsLoadState.ready;
        _rows.removeWhere((name, row) => !row.busy);
        _installSteps.removeWhere((name, _) => !_hasToolset(name));
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
  }

  bool _hasToolset(String name) => _toolsets.any((t) => t.name == name);

  Toolset? _toolset(String name) =>
      _toolsets.where((t) => t.name == name).firstOrNull;

  void _setRow(String name, ToolsRowState row) {
    if (row.phase == ToolsRowPhase.idle &&
        row.error == null &&
        row.shownEnabled == null) {
      _rows.remove(name);
    } else {
      _rows[name] = row;
    }
  }

  /// Asks to switch [name] to [enabled].
  ///
  /// Turning a toolset off sends at once. Turning one on first reads its
  /// setup, to learn whether the switch can start an installer, and then
  /// either sends or opens [confirmation]; nothing is sent, and the switch
  /// keeps its saved position, until [confirm]. A second request for a row
  /// that is busy waits for the first answer.
  Future<void> requestSwitch(String name, {required bool enabled}) async {
    final toolset = _toolset(name);
    if (toolset == null || _confirmation != null) return;
    // The switch is disabled while a setup write runs; a request that still
    // arrives is dropped, not queued, so nothing is sent behind the write.
    if (_setupBusy.contains(name)) return;
    if (rowState(name).busy) {
      _queued[name] = enabled;
      return;
    }
    if (!enabled) return _write(toolset, enabled: false);

    final epoch = _epoch;
    _setRow(name, const ToolsRowState(phase: ToolsRowPhase.preparing));
    notifyListeners();
    final installs = await _hasInstallStep(name);
    if (_stale(epoch)) return;
    if (installs == null) {
      _queued.remove(name);
      // The setup could not be read, so what the switch may start is
      // unknown. Nothing is sent.
      _setRow(
        name,
        const ToolsRowState(error: ToolsRowError(ToolsRowErrorKind.failed)),
      );
      notifyListeners();
      return;
    }
    if (_confirmation != null) {
      // Another toolset's question opened while this one read its setup.
      _queued.remove(name);
      _setRow(name, const ToolsRowState());
      notifyListeners();
      return;
    }
    final risk = toolsetRisk(name);
    if (risk?.asksBeforeSwitchingOn == true || installs) {
      _confirmation = ToolsConfirmation(
        toolset: toolset,
        risk: risk,
        installsSoftware: installs,
      );
      _setRow(
        name,
        const ToolsRowState(phase: ToolsRowPhase.awaitingConfirmation),
      );
      notifyListeners();
      return;
    }
    await _write(toolset, enabled: true);
  }

  /// Answers the open question with "Switch on": the write starts now.
  Future<void> confirm() async {
    final question = _confirmation;
    if (question == null) return;
    _confirmation = null;
    _recordConfirmation(question.toolset.name, confirmed: true);
    await _write(question.toolset, enabled: true);
  }

  /// Answers the open question with Cancel, or App Lock dismissing it.
  void cancel() {
    final question = _confirmation;
    if (question == null) return;
    _confirmation = null;
    _setRow(question.toolset.name, const ToolsRowState());
    _recordConfirmation(question.toolset.name, confirmed: false);
    _queued.remove(question.toolset.name);
    notifyListeners();
  }

  /// Whether any provider of [name] has an install step; null when its setup
  /// cannot be read.
  Future<bool?> _hasInstallStep(String name) async {
    final known = _installSteps[name];
    if (known != null) return known;
    final epoch = _epoch;
    final result = await _repository.config(name);
    if (_stale(epoch)) return null;
    if (result case ToolsOk(:final value)) {
      final installs = value.providers.any((p) => p.postSetup != null);
      _installSteps[name] = installs;
      return installs;
    }
    return null;
  }

  Future<void> _write(Toolset toolset, {required bool enabled}) async {
    final epoch = _epoch;
    final name = toolset.name;
    _setRow(
      name,
      ToolsRowState(phase: ToolsRowPhase.saving, shownEnabled: enabled),
    );
    notifyListeners();

    final span = _startSpan(name, enabled);
    final result = await _repository.switchToolset(name, enabled: enabled);
    _endSpan(span, name, enabled, result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk(:final value):
        _changed = true;
        _changedNames.add(name);
        final started = value.postSetupStarted;
        if (started != null) {
          _postSetupStarted = started;
          _postSetupToolset = name;
        }
        await _readBack(epoch, name, saved: value.enabled);
      case ToolsRefused(:final detail):
        if (detail != null && detail.startsWith('Unknown toolset')) {
          await _readBackAfterUnknown(epoch, name, detail);
        } else {
          _fail(name, ToolsRowError(ToolsRowErrorKind.refused, detail: detail));
        }
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        await _check(epoch, name);
      case ToolsFailed(kind: ToolsFailure.unauthorized):
        _fail(name, const ToolsRowError(ToolsRowErrorKind.forbidden));
      case ToolsFailed(kind: ToolsFailure.offline):
        _fail(name, const ToolsRowError(ToolsRowErrorKind.offline));
      case ToolsFailed():
        _fail(name, const ToolsRowError(ToolsRowErrorKind.failed));
      case ToolsProfileGone():
        _state = ToolsLoadState.profileGone;
        _fail(name, const ToolsRowError(ToolsRowErrorKind.failed));
      case ToolsUnsupported():
        _state = ToolsLoadState.unsupported;
        _fail(name, const ToolsRowError(ToolsRowErrorKind.failed));
    }
    if (_stale(epoch)) return;
    notifyListeners();
    _runQueued(name);
  }

  void _fail(String name, ToolsRowError error) {
    _setRow(name, ToolsRowState(error: error));
  }

  /// After a switch the server accepted: reads the list again. If that read
  /// fails, the row still takes the state the server confirmed.
  Future<void> _readBack(int epoch, String name, {required bool saved}) async {
    final result = await _repository.list();
    if (_stale(epoch)) return;
    if (result is ToolsOk<ToolsetList>) {
      _applyList(result);
      _setRow(name, const ToolsRowState());
    } else {
      _toolsets = [
        for (final t in _toolsets)
          if (t.name == name) t.copyWith(enabled: saved) else t,
      ];
      _applyList(result);
      _setRow(name, const ToolsRowState());
    }
  }

  Future<void> _readBackAfterUnknown(
    int epoch,
    String name,
    String detail,
  ) async {
    final result = await _repository.list();
    if (_stale(epoch)) return;
    _applyList(result);
    if (result is ToolsOk<ToolsetList> && !_hasToolset(name)) {
      _toolVanished = true;
      _setRow(name, const ToolsRowState());
    } else {
      _setRow(
        name,
        ToolsRowState(
          error: ToolsRowError(ToolsRowErrorKind.refused, detail: detail),
        ),
      );
    }
  }

  /// The answer to a write was lost: shows the last saved state, reads the
  /// list for at most [checkTimeout], and never sends the write again.
  Future<void> _check(int epoch, String name) async {
    _setRow(name, const ToolsRowState(phase: ToolsRowPhase.checking));
    notifyListeners();
    ToolsResult<ToolsetList>? result;
    try {
      result = await _repository.list().timeout(checkTimeout);
    } on TimeoutException {
      result = null;
    }
    if (_stale(epoch)) return;
    if (result is ToolsOk<ToolsetList>) {
      _applyList(result);
      _setRow(name, const ToolsRowState());
    } else {
      _setRow(name, const ToolsRowState(phase: ToolsRowPhase.unconfirmed));
    }
  }

  void _runQueued(String name) {
    final next = _queued.remove(name);
    final toolset = _toolset(name);
    if (next == null || toolset == null || next == toolset.enabled) return;
    unawaited(requestSwitch(name, enabled: next));
  }

  Span? _startSpan(String name, bool enabled) {
    try {
      return telemetry.tracer?.startSpan(
        'tools.toggle',
        attributes: {
          ...telemetry.serverAttributes,
          'toolset': toolsetSlug(name),
          'enabled': enabled,
        },
      );
    } on Object {
      return null;
    }
  }

  void _endSpan(Span? span, String name, bool enabled, String outcome) {
    try {
      span
        ?..setAttribute('outcome', outcome)
        ..end();
      telemetry.events('tools.toggled', {
        'toolset': toolsetSlug(name),
        'enabled': enabled,
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  void _recordConfirmation(String name, {required bool confirmed}) {
    try {
      telemetry.events('tools.risk_confirmed', {
        'toolset': toolsetSlug(name),
        'confirmed': confirmed,
      });
    } on Object {
      return;
    }
  }
}
