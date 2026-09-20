import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../profiles/hermes_profiles_repository.dart';
import 'hermes_mcp_repository.dart';

/// Where a connection test of one server stands.
sealed class McpTestState {
  const McpTestState();
}

class McpTestRunning extends McpTestState {
  const McpTestRunning();
}

class McpTestFinished extends McpTestState {
  const McpTestFinished(this.result);

  final HermesMcpTestResult result;
}

/// The request itself failed, as opposed to the server failing the test.
class McpTestUnavailable extends McpTestState {
  const McpTestUnavailable();
}

enum McpOutcome {
  done,

  /// The dashboard no longer knows the server; the list has been reloaded.
  gone,
  failed,
}

/// The state of one visit to the MCP servers screen: the active profile, the
/// servers of that profile and the test results, which are dropped with the
/// visit because they only say "worked just now".
///
/// Every request carries the profile learned in [load]. A profile lookup that
/// fails for any reason but 404 fails the load, so nothing is listed or
/// changed unscoped.
class McpServersController extends ChangeNotifier {
  McpServersController({required this.repository, this.profiles});

  final HermesMcpRepository repository;
  final HermesProfilesRepository? profiles;

  String? _profile;
  List<HermesMcpServer>? _servers;
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;
  final _switching = <String>{};
  final _tests = <String, McpTestState>{};

  /// The profile the screen acts on; null when the dashboard has none.
  String? get profile => _profile;
  List<HermesMcpServer>? get servers => _servers;
  bool get loading => _loading;
  bool get failed => _failed;

  bool isSwitching(String name) => _switching.contains(name);
  McpTestState? testOf(String name) => _tests[name];

  HermesMcpServer? serverNamed(String name) =>
      _servers?.where((s) => s.name == name).firstOrNull;

  /// Learns the active profile, then lists its servers.
  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      _profile = await _activeProfile();
      await _fetch();
    } on Object {
      if (_disposed) return;
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  Future<String?> _activeProfile() async {
    try {
      final active = (await profiles?.loadActive())?.active;
      return active == null || active.isEmpty ? null : active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _fetch() async {
    final servers = await repository.loadServers(profile: _profile);
    if (_disposed) return;
    _servers = servers;
    _tests.removeWhere((name, _) => servers.every((s) => s.name != name));
  }

  Future<void> _reload() async {
    try {
      await _fetch();
    } on Object {
      if (_disposed) return;
      _failed = true;
    }
    _notify();
  }

  /// Sets the server on or off. The new state shows once the dashboard has
  /// confirmed it.
  Future<McpOutcome> setEnabled(HermesMcpServer server, bool enabled) async {
    final name = server.name;
    if (!_switching.add(name)) return McpOutcome.failed;
    _notify();
    try {
      await repository.setEnabled(name, enabled, profile: _profile);
      _servers = [
        for (final s in _servers ?? const <HermesMcpServer>[])
          s.name == name ? s.withEnabled(enabled) : s,
      ];
      return McpOutcome.done;
    } on Object catch (e) {
      if (!isMcpNotFound(e)) return McpOutcome.failed;
      await _reload();
      return McpOutcome.gone;
    } finally {
      _switching.remove(name);
      _notify();
    }
  }

  Future<void> test(HermesMcpServer server) async {
    final name = server.name;
    if (_tests[name] is McpTestRunning) return;
    _tests[name] = const McpTestRunning();
    _notify();
    try {
      final result = await repository.testServer(server, profile: _profile);
      _tests[name] = McpTestFinished(result);
    } on Object catch (e) {
      if (isMcpNotFound(e)) {
        _tests.remove(name);
        await _reload();
      } else {
        _tests[name] = const McpTestUnavailable();
      }
    }
    _notify();
  }

  /// Deletes the server. A server the dashboard no longer knows counts as
  /// removed.
  Future<McpOutcome> remove(HermesMcpServer server) async {
    final name = server.name;
    try {
      await repository.removeServer(name, profile: _profile);
    } on Object catch (e) {
      if (!isMcpNotFound(e)) return McpOutcome.failed;
      await _reload();
      return McpOutcome.gone;
    }
    _servers = _servers?.where((s) => s.name != name).toList();
    _tests.remove(name);
    _notify();
    return McpOutcome.done;
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
