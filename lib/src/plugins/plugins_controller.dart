import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import 'hermes_plugin_manager_repository.dart';
import 'installed_plugin.dart';

enum PluginsFailure { failed, unsupported }

/// What the Plugins screen shows and does: the installed plugins, which one is
/// open, and which have a change running.
class PluginsController extends ChangeNotifier {
  PluginsController(this._repository, {this._events = noopAppEventLogger});

  final HermesPluginManagerRepository _repository;
  final AppEventLogger _events;

  List<InstalledPlugin> _plugins = const [];
  bool _loading = true;
  PluginsFailure? _failure;
  String? _selectedName;
  final _busy = <String>{};

  List<InstalledPlugin> get plugins => _plugins;

  /// True until the first load has answered.
  bool get loading => _loading;

  /// Why the first load produced no list; null once a list is showing.
  PluginsFailure? get failure => _failure;

  String? get selectedName => _selectedName;

  InstalledPlugin? get selected {
    for (final plugin in _plugins) {
      if (plugin.name == _selectedName) return plugin;
    }
    return null;
  }

  bool isBusy(String name) => _busy.contains(name);

  void select(String? name) {
    if (name == _selectedName) return;
    _selectedName = name;
    notifyListeners();
  }

  /// The first load, and its retry.
  Future<void> load() async {
    _loading = true;
    _failure = null;
    notifyListeners();
    try {
      _apply(await _repository.load());
    } on PluginsUnsupported {
      _failure = PluginsFailure.unsupported;
    } on Object {
      _failure = PluginsFailure.failed;
    }
    _loading = false;
    notifyListeners();
  }

  /// Loads again without hiding what is shown. False when it failed, in which
  /// case the list is as it was.
  Future<bool> refresh() async {
    try {
      _apply(await _repository.load());
      _failure = null;
      notifyListeners();
      return true;
    } on Object {
      return false;
    }
  }

  void _apply(List<InstalledPlugin> plugins) {
    _plugins = plugins;
    if (selected == null) _selectedName = null;
  }

  Future<PluginActionResult> setEnabled(String name, bool enabled) => _change(
    name,
    enabled ? 'enable' : 'disable',
    () => _repository.setEnabled(name, enabled),
  );

  Future<PluginActionResult> update(String name) =>
      _change(name, 'update', () => _repository.update(name));

  Future<PluginActionResult> remove(String name) =>
      _change(name, 'remove', () => _repository.remove(name));

  Future<PluginActionResult> setHidden(String name, bool hidden) =>
      _change(name, 'hide', () => _repository.setHidden(name, hidden));

  Future<PluginActionResult> _change(
    String name,
    String action,
    Future<PluginActionResult> Function() call,
  ) async {
    _busy.add(name);
    notifyListeners();
    final PluginActionResult result;
    try {
      result = await call();
    } finally {
      _busy.remove(name);
    }
    final outcome = !result.ok
        ? 'error'
        : (action == 'update' && result.unchanged ? 'unchanged' : 'ok');
    _events('plugins.$action.$outcome', {'plugin.name': name});
    if (result.ok) {
      await refresh();
    }
    notifyListeners();
    return result;
  }
}
