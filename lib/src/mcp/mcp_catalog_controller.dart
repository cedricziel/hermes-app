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

/// A build Hermes runs on the server for an entry the user installed.
class McpBuild {
  const McpBuild({required this.action, required this.enable});

  /// The background process to poll.
  final String action;

  /// Whether the entry is switched on once it is installed.
  final bool enable;
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
  final _builds = <String, McpBuild>{};
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

  /// The build running for [name] that this visit knows about. Closing the
  /// install screen does not stop a build, so the visit remembers it and the
  /// next screen for the entry follows it again.
  McpBuild? buildOf(String name) => _builds[name];

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
      _builds.removeWhere((name, _) => entryNamed(name)?.installed != false);
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

  void buildStarted(String name, McpBuild build) {
    _builds[name] = build;
    _notify();
  }

  void buildEnded(String name) {
    if (_builds.remove(name) != null) _notify();
  }

  /// Shows [name] as installed once Hermes has confirmed the install.
  void markInstalled(String name, {required bool enabled}) {
    _builds.remove(name);
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
