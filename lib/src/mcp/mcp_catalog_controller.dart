import 'package:flutter/foundation.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_servers_controller.dart';

enum McpCatalogFilter {
  all('All'),
  remote('Remote'),
  command('Command'),
  oauth('OAuth');

  const McpCatalogFilter(this.label);

  final String label;

  bool matches(HermesMcpCatalogEntry entry) => switch (this) {
    all => true,
    remote => entry.transport == McpTransport.remote,
    command => entry.transport == McpTransport.command,
    oauth => entry.authKind == McpAuthKind.oauth,
  };
}

/// One visit to the catalog: the entries Hermes offers for the profile the
/// MCP servers screen acts on, and the search and filter over them.
///
/// The profile is [servers]' profile, so an install lands on the profile the
/// screen names. When that profile has not been learned, [load] has [servers]
/// learn it first, and fails without asking for the catalog if it cannot.
class McpCatalogController extends ChangeNotifier {
  McpCatalogController(this.servers);

  final McpServersController servers;

  List<HermesMcpCatalogEntry>? _entries;
  bool _hasDiagnostics = false;
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;
  String _query = '';
  McpCatalogFilter _filter = McpCatalogFilter.all;

  List<HermesMcpCatalogEntry>? get entries => _entries;
  bool get hasDiagnostics => _hasDiagnostics;
  bool get loading => _loading;
  bool get failed => _failed;
  String get query => _query;
  McpCatalogFilter get filter => _filter;

  HermesMcpCatalogEntry? entryNamed(String? name) =>
      _entries?.where((e) => e.name == name).firstOrNull;

  /// The entries the search and the filter let through, in Hermes' order.
  List<HermesMcpCatalogEntry> get visible {
    final needle = _query.trim().toLowerCase();
    return [
      for (final entry in _entries ?? const <HermesMcpCatalogEntry>[])
        if (_filter.matches(entry) &&
            (needle.isEmpty ||
                entry.name.toLowerCase().contains(needle) ||
                entry.description.toLowerCase().contains(needle)))
          entry,
    ];
  }

  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      if (servers.servers == null || servers.failed) await servers.load();
      if (servers.servers == null || servers.failed) {
        throw StateError('The active profile is unknown');
      }
      final catalog = await servers.repository.loadCatalog(
        profile: servers.profile,
      );
      _entries = catalog.entries;
      _hasDiagnostics = catalog.hasDiagnostics;
    } on Object {
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  void search(String query) {
    _query = query;
    _notify();
  }

  void select(McpCatalogFilter filter) {
    _filter = filter;
    _notify();
  }

  void clearSearch() {
    _query = '';
    _filter = McpCatalogFilter.all;
    _notify();
  }

  /// Shows [name] as installed once Hermes has confirmed the install.
  void markInstalled(String name, {required bool enabled}) {
    _entries = [
      for (final entry in _entries ?? const <HermesMcpCatalogEntry>[])
        entry.name == name ? entry.withInstalled(enabled: enabled) : entry,
    ];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
