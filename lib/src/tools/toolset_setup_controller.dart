import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_controller.dart' show kToolsCheckTimeout;
import 'tools_models.dart';

enum ToolsetKeysState {
  idle,
  saving,

  /// The last save succeeded and the fields were cleared.
  saved,

  /// The save failed. The typed values are still here, to be edited and sent
  /// again by the user, never by the controller.
  failed,

  /// The answer to the save was lost. The fields are cleared (the key may
  /// already be saved) and the config is being read again.
  checking,

  /// The re-read shows the key is not set: the user has to paste it again.
  notSaved,

  /// The re-read did not finish; the keys show their last known state.
  unconfirmed,
}

/// One open toolset's setup: its provider matrix and the key form.
///
/// Typed key values live only in this object's private map and in the body
/// of the one request that saves them. Nothing here logs, traces, stores or
/// prints them, and no method returns them: the screen shows only how many
/// characters were typed.
class ToolsetSetupController extends ChangeNotifier with SafeNotifier {
  ToolsetSetupController(
    HermesToolsRepository repository, {
    required this.toolset,
    this.telemetry = const ConnectionTelemetry(),
    this.checkTimeout = kToolsCheckTimeout,
  }) : _repository = repository;

  HermesToolsRepository _repository;
  final String toolset;
  final ConnectionTelemetry telemetry;
  final Duration checkTimeout;

  var _epoch = 0;
  ToolsetConfig? _config;
  var _loading = false;
  ToolsFailure? _loadFailure;
  var _keys = ToolsetKeysState.idle;
  ToolsResult<ToolsetEnvSaved>? _lastRefusal;
  final _typed = <String, String>{};

  ToolsetConfig? get config => _config;
  bool get loading => _loading;

  /// Why the matrix could not be read; null when it was or is loading.
  ToolsFailure? get loadFailure => _loadFailure;
  ToolsetKeysState get keysState => _keys;

  /// Hermes' own text when it refused the last save.
  String? get refusalDetail => switch (_lastRefusal) {
    ToolsRefused(:final detail) => detail,
    _ => null,
  };

  /// How many characters are typed for [key]; the line under the field.
  int typedLength(String key) => _typed[key]?.length ?? 0;

  /// True when at least one non-blank value is typed.
  bool get hasTypedKeys => _sendable().isNotEmpty;

  bool _stale(int epoch) => disposed || epoch != _epoch;

  /// Reads the provider matrix. Typed keys stay.
  Future<void> load() async {
    final epoch = _epoch;
    _loading = true;
    _loadFailure = null;
    notifyListeners();
    final result = await _repository.config(toolset);
    if (_stale(epoch)) return;
    _applyConfig(result);
    _loading = false;
    notifyListeners();
  }

  /// Whether the matrix was read; keeps the last good one on a failure.
  bool _applyConfig(ToolsResult<ToolsetConfig> result) {
    if (result case ToolsOk(:final value)) {
      _config = value;
      _loadFailure = null;
      return true;
    }
    _loadFailure = switch (result) {
      ToolsFailed(:final kind) => kind,
      _ => ToolsFailure.server,
    };
    return false;
  }

  /// Keeps what the user typed for [key]. A value is never read back out.
  void setKey(String key, String value) {
    if (_keys == ToolsetKeysState.saving) return;
    if (value.isEmpty) {
      _typed.remove(key);
    } else {
      _typed[key] = value;
    }
    if (_keys != ToolsetKeysState.idle) _keys = ToolsetKeysState.idle;
    notifyListeners();
  }

  /// Drops every typed value: App Lock, the form closing, a profile switch.
  void clearKeys() {
    if (_typed.isEmpty) return;
    _typed.clear();
    notifyListeners();
  }

  /// Hands the controller to another profile and drops everything typed.
  void switchProfile(HermesToolsRepository repository) {
    _epoch++;
    _repository = repository;
    _typed.clear();
    _config = null;
    _loadFailure = null;
    _keys = ToolsetKeysState.idle;
    _lastRefusal = null;
    notifyListeners();
  }

  /// The typed values that may be sent: only keys the toolset's providers
  /// list, and only non-blank ones.
  Map<String, String> _sendable() {
    final known = {
      for (final provider in _config?.providers ?? const <ToolsetProvider>[])
        for (final env in provider.envVars) env.key,
    };
    return {
      for (final entry in _typed.entries)
        if (known.contains(entry.key) && entry.value.trim().isNotEmpty)
          entry.key: entry.value,
    };
  }

  /// Sends the typed keys, once.
  ///
  /// Success clears the fields and reads the config. A failed save keeps the
  /// values so the user can edit and save again. A lost answer clears them
  /// (the key may be saved), reads the config for at most [checkTimeout] and
  /// never sends the request again.
  Future<void> saveKeys() async {
    if (_keys == ToolsetKeysState.saving ||
        _keys == ToolsetKeysState.checking) {
      return;
    }
    final env = _sendable();
    if (env.isEmpty) return;
    final epoch = _epoch;
    final wasSet = _setKeys(env.keys);
    _keys = ToolsetKeysState.saving;
    _lastRefusal = null;
    notifyListeners();

    final span = _startSpan(env.length);
    final result = await _repository.saveEnv(toolset, env);
    _finish(span, result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk():
        _typed.clear();
        _keys = ToolsetKeysState.saved;
        _applyConfig(await _repository.config(toolset));
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        _typed.clear();
        _keys = ToolsetKeysState.checking;
        notifyListeners();
        await _check(epoch, env.keys, wasSet);
      default:
        _lastRefusal = result;
        _keys = ToolsetKeysState.failed;
    }
    if (_stale(epoch)) return;
    notifyListeners();
  }

  Set<String> _setKeys(Iterable<String> keys) => {
    for (final provider in _config?.providers ?? const <ToolsetProvider>[])
      for (final env in provider.envVars)
        if (env.isSet && keys.contains(env.key)) env.key,
  };

  Future<void> _check(
    int epoch,
    Iterable<String> keys,
    Set<String> wasSet,
  ) async {
    ToolsResult<ToolsetConfig>? result;
    try {
      result = await _repository.config(toolset).timeout(checkTimeout);
    } on TimeoutException {
      result = null;
    }
    if (_stale(epoch)) return;
    if (result == null || !_applyConfig(result)) {
      _keys = ToolsetKeysState.unconfirmed;
      return;
    }
    final nowSet = _setKeys(keys);
    if (nowSet.length < keys.length) {
      _keys = ToolsetKeysState.notSaved;
    } else if (keys.any(wasSet.contains)) {
      // A key that was already set shows set either way.
      _keys = ToolsetKeysState.unconfirmed;
    } else {
      _keys = ToolsetKeysState.saved;
    }
  }

  Span? _startSpan(int keys) {
    try {
      return telemetry.tracer?.startSpan(
        'tools.setup',
        attributes: {
          ...telemetry.serverAttributes,
          'step': 'env',
          'keys': keys,
        },
      );
    } on Object {
      return null;
    }
  }

  void _finish(Span? span, String outcome) {
    try {
      span
        ?..setAttribute('outcome', outcome)
        ..end();
      telemetry.events('tools.setup_outcome', {
        'step': 'env',
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    _typed.clear();
    super.dispose();
  }
}
