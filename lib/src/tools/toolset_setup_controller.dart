import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_controller.dart' show kToolsCheckTimeout;
import 'tools_models.dart';
import 'tools_write.dart';

/// The toolsets that have a model catalog (`/models`); every other one
/// answers `has_models: false`.
const kModelToolsets = {'image_gen', 'video_gen'};

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
///
/// Writes of this controller are one at a time, but `ToolsController` keeps
/// its own guard for the toolset switch, so a switch and a provider pick on
/// the same toolset can overlap. That is known: the screen disables the
/// switch while a setup write runs.
class ToolsetSetupController extends ChangeNotifier with SafeNotifier {
  ToolsetSetupController(
    HermesToolsRepository repository, {
    required this.toolset,
    this.telemetry = const ConnectionTelemetry(),
    this.checkTimeout = kToolsCheckTimeout,
    this.onWritten,
  }) : _repository = repository;

  HermesToolsRepository _repository;
  final String toolset;
  final ConnectionTelemetry telemetry;
  final Duration checkTimeout;

  /// Called after a key, provider or model write the server accepted (or a
  /// re-read showed landed), so the shell can read the toolset list again:
  /// the matrix and the list change together. Never called for a failure.
  final void Function()? onWritten;

  var _epoch = 0;
  var _modelsToken = 0;
  String? _modelsProvider;
  ToolsetConfig? _config;
  var _loading = false;
  ToolsFailure? _loadFailure;
  var _keys = ToolsetKeysState.idle;
  ToolsResult<ToolsetEnvSaved>? _lastRefusal;
  final _typed = <String, String>{};
  String? _selected;
  var _writing = false;
  var _provider = ToolsWriteState.idle;
  String? _providerDetail;
  var _needsNousAuth = false;
  ToolsetModels? _models;
  var _modelsLoading = false;
  ToolsFailure? _modelsFailure;
  var _model = ToolsWriteState.idle;
  String? _modelDetail;

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

  /// Where the last provider pick is.
  ToolsWriteState get providerState => _provider;

  /// Hermes' own text when it refused the last provider pick.
  String? get providerRefusalDetail => _providerDetail;

  /// The last pick wrote the config, but the row works only after a sign-in
  /// to the Nous Portal on the server. A state, not a sentence.
  bool get needsNousAuth => _needsNousAuth;

  /// The model catalog; null until [loadModels] answered or when the toolset
  /// has none.
  ToolsetModels? get models => _models;
  bool get modelsLoading => _modelsLoading;
  ToolsFailure? get modelsFailure => _modelsFailure;

  /// This toolset has a catalog to pick from.
  bool get hasModelCatalog => _models?.hasModels ?? false;
  ToolsWriteState get modelState => _model;

  /// Hermes' own text when it refused the last model pick.
  String? get modelRefusalDetail => _modelDetail;

  /// True while a write of this controller is in flight; a second one waits
  /// for the user to ask again.
  bool get writing => _writing;

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

  /// Reads the matrix (and the model catalog, for a toolset that has one)
  /// again for "Couldn't confirm. Pull to refresh." A read that works ends the
  /// unconfirmed and not-applied states: the screen then shows what Hermes
  /// says. Typed keys stay, and nothing is written.
  Future<void> refresh() async {
    final epoch = _epoch;
    final result = await _repository.config(toolset);
    if (_stale(epoch)) return;
    if (_applyConfig(result)) {
      if (_keys == ToolsetKeysState.unconfirmed) _keys = ToolsetKeysState.idle;
      if (_provider == ToolsWriteState.unconfirmed ||
          _provider == ToolsWriteState.notApplied) {
        _provider = ToolsWriteState.idle;
      }
      if (_model == ToolsWriteState.unconfirmed ||
          _model == ToolsWriteState.notApplied) {
        _model = ToolsWriteState.idle;
      }
    }
    notifyListeners();
    if (kModelToolsets.contains(toolset) && _models != null) {
      await loadModels(provider: _modelsProvider);
    }
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

  /// The provider whose keys the form shows: the one the user picked, else
  /// the active one.
  String? get selectedProvider => _selected ?? _config?.activeProvider;

  /// Picks the provider whose keys are shown. Values typed for another
  /// provider are dropped, so they can never leave with this one's keys.
  void selectProvider(String name) {
    if (name == selectedProvider) return;
    _selected = name;
    _typed.clear();
    notifyListeners();
  }

  /// Keeps what the user typed for [key]. A value is never read back out.
  void setKey(String key, String value) {
    if (_keys == ToolsetKeysState.saving ||
        _keys == ToolsetKeysState.checking) {
      return;
    }
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
    _loading = false;
    _selected = null;
    _writing = false;
    _provider = ToolsWriteState.idle;
    _providerDetail = null;
    _needsNousAuth = false;
    _models = null;
    _modelsLoading = false;
    _modelsFailure = null;
    _model = ToolsWriteState.idle;
    _modelDetail = null;
    notifyListeners();
  }

  /// The typed values that may be sent: only keys the toolset's providers
  /// list, and only non-blank ones.
  Map<String, String> _sendable() {
    final chosen = selectedProvider;
    final known = {
      for (final provider in _config?.providers ?? const <ToolsetProvider>[])
        if (provider.name == chosen)
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
        _keys == ToolsetKeysState.checking ||
        _writing) {
      return;
    }
    final env = _sendable();
    if (env.isEmpty) return;
    final epoch = _epoch;
    _writing = true;
    try {
      await _saveKeys(epoch, env);
    } finally {
      if (epoch == _epoch) _writing = false;
    }
  }

  Future<void> _saveKeys(int epoch, Map<String, String> env) async {
    final wasSet = _setKeys(env.keys);
    _keys = ToolsetKeysState.saving;
    _lastRefusal = null;
    notifyListeners();

    final span = _startSpan('env', keys: env.length);
    final result = await _repository.saveEnv(toolset, env);
    finishSetupStep(telemetry, span, 'env', result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk():
        _typed.clear();
        _keys = ToolsetKeysState.saved;
        final fresh = await _repository.config(toolset);
        if (_stale(epoch)) return;
        if (fresh is ToolsOk<ToolsetConfig>) _applyConfig(fresh);
        _written();
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

  /// Picks [name] as the provider, once.
  ///
  /// [capability] (`search` or `extract`) is for `web` only: it picks the
  /// provider of that capability and leaves the other as it is. A refusal
  /// keeps the old selection and holds Hermes' text. A lost answer reads the
  /// config for at most [checkTimeout] and never sends the pick again. After
  /// a success the config is read again.
  Future<void> pickProvider(String name, {String? capability}) async {
    if (_writing) return;
    final epoch = _epoch;
    _writing = true;
    try {
      await _pickProvider(epoch, name, capability);
    } finally {
      if (epoch == _epoch) _writing = false;
    }
  }

  Future<void> _pickProvider(int epoch, String name, String? capability) async {
    _provider = ToolsWriteState.saving;
    _providerDetail = null;
    _needsNousAuth = false;
    notifyListeners();

    final span = _startSpan('provider');
    final result = await _repository.pickProvider(
      toolset,
      name,
      capability: capability,
    );
    finishSetupStep(telemetry, span, 'provider', result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk(:final value):
        _needsNousAuth = value.needsNousAuth;
        if (capability == null) _adopt(name);
        _provider = ToolsWriteState.idle;
        final fresh = await _repository.config(toolset);
        if (_stale(epoch)) return;
        if (fresh is ToolsOk<ToolsetConfig>) _applyConfig(fresh);
        _written();
      case ToolsRefused(:final detail):
        _providerDetail = detail;
        _provider = ToolsWriteState.refused;
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        _provider = ToolsWriteState.checking;
        notifyListeners();
        await _checkPick(epoch, name, capability);
      default:
        _provider = ToolsWriteState.failed;
    }
    if (_stale(epoch)) return;
    notifyListeners();
  }

  /// The picked provider becomes the one whose keys show; what was typed for
  /// another one goes.
  void _adopt(String name) {
    if (selectedProvider != name) _typed.clear();
    _selected = name;
  }

  Future<void> _checkPick(int epoch, String name, String? capability) async {
    final result = await _readConfigWithin();
    if (_stale(epoch)) return;
    if (result == null || !_applyConfig(result)) {
      _provider = ToolsWriteState.unconfirmed;
      return;
    }
    switch (_pickLanded(name, capability)) {
      case true:
        if (capability == null) _adopt(name);
        _provider = ToolsWriteState.idle;
        _written();
      case false:
        _provider = ToolsWriteState.notApplied;
      case null:
        _provider = ToolsWriteState.unconfirmed;
    }
  }

  /// Whether the config shows the pick; null when it cannot tell.
  bool? _pickLanded(String name, String? capability) {
    final config = _config;
    final provider = config?.providers.where((p) => p.name == name).firstOrNull;
    if (config == null || provider == null) return null;
    if (capability == null) return config.activeProvider == name;
    final backend = provider.webBackend;
    if (backend == null) return null;
    return (capability == 'extract'
            ? config.activeExtractBackend
            : config.activeSearchBackend) ==
        backend;
  }

  Future<ToolsResult<ToolsetConfig>?> _readConfigWithin() async {
    try {
      return await _repository.config(toolset).timeout(checkTimeout);
    } on TimeoutException {
      return null;
    }
  }

  /// Reads the model catalog. Only `image_gen` and `video_gen` have one; for
  /// any other toolset nothing is sent. [provider] narrows it to one
  /// provider's models and is kept for the reads after a pick. An older
  /// answer never replaces a newer one.
  Future<void> loadModels({String? provider}) async {
    if (!kModelToolsets.contains(toolset)) return;
    final epoch = _epoch;
    final token = ++_modelsToken;
    _modelsProvider = provider;
    _modelsLoading = true;
    _modelsFailure = null;
    notifyListeners();
    final result = await _repository.models(toolset, provider: provider);
    if (_stale(epoch) || token != _modelsToken) return;
    _applyModels(result);
    _modelsLoading = false;
    notifyListeners();
  }

  bool _applyModels(ToolsResult<ToolsetModels> result) {
    if (result case ToolsOk(:final value)) {
      _models = value;
      _modelsFailure = null;
      return true;
    }
    _modelsFailure = switch (result) {
      ToolsFailed(:final kind) => kind,
      _ => ToolsFailure.server,
    };
    return false;
  }

  /// Reads the catalog again after a pick, with the provider the last load
  /// used. Null when a newer read overtook this one or [timeout] passed.
  Future<ToolsResult<ToolsetModels>?> _rereadModels(
    int epoch, {
    Duration? timeout,
  }) async {
    final token = ++_modelsToken;
    var read = _repository.models(toolset, provider: _modelsProvider);
    if (timeout != null) {
      read = read.timeout(
        timeout,
        onTimeout: () => const ToolsFailed(ToolsFailure.timeout),
      );
    }
    final result = await read;
    if (_stale(epoch) || token != _modelsToken) return null;
    return result;
  }

  /// Picks the model [id], once. Only an id the catalog lists is sent. The
  /// catalog is read again afterwards; a lost answer reads it for at most
  /// [checkTimeout] and never sends the pick again.
  Future<void> pickModel(String id) async {
    final catalog = _models;
    if (_writing ||
        catalog == null ||
        !catalog.hasModels ||
        !catalog.models.any((m) => m.id == id)) {
      return;
    }
    final epoch = _epoch;
    _writing = true;
    try {
      await _pickModel(epoch, id);
    } finally {
      if (epoch == _epoch) _writing = false;
    }
  }

  Future<void> _pickModel(int epoch, String id) async {
    _model = ToolsWriteState.saving;
    _modelDetail = null;
    notifyListeners();

    final span = _startSpan('model');
    final result = await _repository.pickModel(toolset, id);
    finishSetupStep(telemetry, span, 'model', result.outcome);
    if (_stale(epoch)) return;

    switch (result) {
      case ToolsOk():
        _model = ToolsWriteState.idle;
        final fresh = await _rereadModels(epoch);
        if (_stale(epoch)) return;
        if (fresh != null) _applyModels(fresh);
        _written();
      case ToolsRefused(:final detail):
        _modelDetail = detail;
        _model = ToolsWriteState.refused;
      case ToolsFailed(kind: ToolsFailure.unknownOutcome):
        _model = ToolsWriteState.checking;
        notifyListeners();
        final fresh = await _rereadModels(epoch, timeout: checkTimeout);
        if (_stale(epoch)) return;
        if (fresh == null || !_applyModels(fresh)) {
          _model = ToolsWriteState.unconfirmed;
        } else if (_models?.current == id) {
          _model = ToolsWriteState.idle;
          _written();
        } else {
          _model = ToolsWriteState.notApplied;
        }
      default:
        _model = ToolsWriteState.failed;
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
    final result = await _readConfigWithin();
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
      _written();
    }
  }

  void _written() => quietly(() => onWritten?.call());

  Span? _startSpan(String step, {int? keys}) =>
      startToolsSpan(telemetry, 'tools.setup', {'step': step, 'keys': ?keys});

  @override
  void dispose() {
    _typed.clear();
    super.dispose();
  }
}
