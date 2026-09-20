import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import 'catalog_entry.dart';
import 'hermes_plugin_manager_repository.dart';
import 'plugin_install_result.dart';
import 'plugins_controller.dart' show PluginsFailure;

/// What the Catalog tab shows and does: the catalog, the search, the open
/// entry, and which entries have an install running.
///
/// [onInstalled] is called after an install went through, or may have (a
/// timeout), so the caller can reload what it shows.
class CatalogController extends ChangeNotifier {
  CatalogController(
    this._repository, {
    this._events = noopAppEventLogger,
    this.onInstalled,
  });

  final HermesPluginManagerRepository _repository;
  final AppEventLogger _events;
  final VoidCallback? onInstalled;

  List<CatalogEntry> _entries = const [];
  bool _loading = true;
  PluginsFailure? _failure;
  String _query = '';
  String? _selectedName;
  final _installing = <String>{};

  List<CatalogEntry> get entries => _entries;

  /// True until the first load has answered.
  bool get loading => _loading;

  PluginsFailure? get failure => _failure;

  String get query => _query;

  /// The entries the search leaves, in the server's order.
  List<CatalogEntry> get visible {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _entries;
    return [
      for (final entry in _entries)
        if (entry.name.toLowerCase().contains(needle) ||
            entry.description.toLowerCase().contains(needle) ||
            entry.maintainer.toLowerCase().contains(needle))
          entry,
    ];
  }

  String? get selectedName => _selectedName;

  CatalogEntry? get selected {
    for (final entry in _entries) {
      if (entry.name == _selectedName) return entry;
    }
    return null;
  }

  bool isInstalling(String name) => _installing.contains(name);

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

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
      _apply(await _repository.loadCatalog());
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
      _apply(await _repository.loadCatalog());
      _failure = null;
      notifyListeners();
      return true;
    } on Object {
      return false;
    }
  }

  void _apply(List<CatalogEntry> entries) {
    _entries = entries;
    if (selected == null) _selectedName = null;
  }

  /// Null when an install of [name] is already running.
  Future<PluginInstallResult?> installFromCatalog(
    String name, {
    bool enable = true,
  }) async {
    if (!_installing.add(name)) return null;
    notifyListeners();
    final PluginInstallResult result;
    try {
      result = await _repository.installFromCatalog(name, enable: enable);
    } finally {
      _installing.remove(name);
    }
    _events('plugins.install.${_outcome(result)}', {'plugin.name': name});
    await _afterInstall(result);
    return result;
  }

  /// Installs code the catalog has not reviewed. The identifier can carry a
  /// credential, so it is never put in an event.
  Future<PluginInstallResult> installFromSource(
    String identifier, {
    required bool enable,
    required bool force,
  }) async {
    final result = await _repository.installFromSource(
      identifier,
      enable: enable,
      force: force,
    );
    _events('plugins.install_custom.${_outcome(result)}');
    await _afterInstall(result);
    return result;
  }

  static String _outcome(PluginInstallResult result) => result.ok
      ? 'ok'
      : result.timedOut
      ? 'timeout'
      : 'error';

  Future<void> _afterInstall(PluginInstallResult result) async {
    if (result.ok || result.timedOut) {
      await refresh();
      onInstalled?.call();
    }
    notifyListeners();
  }
}
