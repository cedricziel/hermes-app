import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import 'hermes_plugin_manager_repository.dart';
import 'installed_plugin.dart' show PluginActionResult;
import 'plugins_controller.dart' show PluginsFailure;
import 'provider_settings.dart';

/// What the Providers tab shows and does: the server's memory provider and
/// context engine settings, the user's unsaved choices, and saving them.
///
/// An empty memory choice is the built-in provider, as on the server.
class ProvidersController extends ChangeNotifier {
  ProvidersController(this._repository, {this._events = noopAppEventLogger});

  final HermesPluginManagerRepository _repository;
  final AppEventLogger _events;

  ProviderSettings _settings = const ProviderSettings();
  bool _loading = true;
  PluginsFailure? _failure;
  String _memoryChoice = '';
  String _contextChoice = '';
  bool _saving = false;

  ProviderSettings get settings => _settings;

  /// True until the first load has answered.
  bool get loading => _loading;

  PluginsFailure? get failure => _failure;

  String get memoryChoice => _memoryChoice;

  String get contextChoice => _contextChoice;

  bool get saving => _saving;

  /// Whether a choice differs from what the server reports.
  bool get dirty => _changedMemory || _changedContext;

  bool get _changedMemory => _memoryChoice != _settings.memoryProvider;

  bool get _changedContext => _contextChoice != _settings.contextEngine;

  /// The engines to show: the server's list, with the engine in use first
  /// when the list does not have it.
  List<ContextEngineOption> get contextOptions {
    final listed = _settings.contextOptions;
    final inUse = _settings.contextEngine;
    if (inUse.isEmpty || listed.any((o) => o.name == inUse)) return listed;
    return [ContextEngineOption(name: inUse), ...listed];
  }

  /// False when the server lists no engine, so there is nothing to choose.
  bool get hasContextChoice => _settings.contextOptions.isNotEmpty;

  void chooseMemory(String name) {
    if (name == _memoryChoice) return;
    _memoryChoice = name;
    notifyListeners();
  }

  void chooseContext(String name) {
    if (name == _contextChoice) return;
    _contextChoice = name;
    notifyListeners();
  }

  /// The first load, and its retry.
  Future<void> load() async {
    _loading = true;
    _failure = null;
    notifyListeners();
    try {
      _apply(await _repository.loadProviders());
    } on PluginsUnsupported {
      _failure = PluginsFailure.unsupported;
    } on Object {
      _failure = PluginsFailure.failed;
    }
    _loading = false;
    notifyListeners();
  }

  /// Loads again and replaces the choices with what the server reports.
  /// False when it failed, in which case everything is as it was.
  Future<bool> refresh() async {
    try {
      _apply(await _repository.loadProviders());
      _failure = null;
      notifyListeners();
      return true;
    } on Object {
      return false;
    }
  }

  void _apply(ProviderSettings settings) {
    _settings = settings;
    _memoryChoice = settings.memoryProvider;
    _contextChoice = settings.contextEngine;
  }

  /// Sends only the choices that changed. On success the settings are loaded
  /// again; on a refusal the choices are kept.
  Future<PluginActionResult> save() async {
    final memory = _changedMemory ? _memoryChoice : null;
    final context = _changedContext ? _contextChoice : null;
    _saving = true;
    notifyListeners();
    final PluginActionResult result;
    try {
      result = await _repository.saveProviders(
        memoryProvider: memory,
        contextEngine: context,
      );
    } finally {
      _saving = false;
    }
    _events('plugins.providers.save.${result.ok ? 'ok' : 'error'}', {
      if (memory != null)
        'memory.provider': memory.isEmpty ? 'builtin' : memory,
      'context.engine': ?context,
    });
    if (result.ok) await refresh();
    notifyListeners();
    return result;
  }
}
