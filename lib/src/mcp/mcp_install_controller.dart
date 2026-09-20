import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_catalog_controller.dart';
import 'mcp_servers_controller.dart';

sealed class McpInstallState {
  const McpInstallState();
}

class McpInstallIdle extends McpInstallState {
  const McpInstallIdle();
}

/// The install request is in flight.
class McpInstalling extends McpInstallState {
  const McpInstalling();
}

/// Hermes is building the entry on the server.
class McpBuilding extends McpInstallState {
  const McpBuilding();
}

class McpInstalled extends McpInstallState {
  const McpInstalled();
}

/// Hermes no longer has the entry; the catalog has been reloaded.
class McpInstallGone extends McpInstallState {
  const McpInstallGone();
}

/// The entry is not installed. [message] says why and [log] is the tail of
/// what a failed build wrote.
class McpInstallFailed extends McpInstallState {
  const McpInstallFailed(this.message, {this.log = const []});

  final String message;
  final List<String> log;
}

/// One install of one catalog entry: the request and, for an entry Hermes
/// builds on the server, following the build until it ends.
///
/// The credentials are arguments of [install] and are not kept. Closing the
/// screen ([dispose]) stops following the build; it does not stop the build.
class McpInstallController extends ChangeNotifier {
  McpInstallController({
    required this.servers,
    required this.catalog,
    required this.entry,
    this.onInstalled,
    this.onGone,
    this.pollInterval = const Duration(seconds: 2),
  });

  final McpServersController servers;
  final McpCatalogController catalog;
  final HermesMcpCatalogEntry entry;

  /// Called once the entry is installed and [servers] lists it, unless the
  /// screen that follows the install has been closed by then.
  final VoidCallback? onInstalled;

  /// Called once Hermes has said it has no such entry and [catalog] has been
  /// reloaded, unless the screen has been closed by then.
  final VoidCallback? onGone;
  final Duration pollInterval;

  static const _logLines = 20;
  static const _maxReadFailures = 3;

  McpInstallState _state = const McpInstallIdle();
  bool _disposed = false;
  Timer? _timer;
  int _readFailures = 0;

  McpInstallState get state => _state;

  /// Whether a request or a build is running, so a second install must wait.
  bool get busy => _state is McpInstalling || _state is McpBuilding;

  /// Sends the install request and returns when Hermes has answered it. A
  /// build carries on after that and settles [state] when it ends.
  Future<void> install(Map<String, String> env, {required bool enable}) async {
    if (busy) return;
    _set(const McpInstalling());
    try {
      final result = await servers.repository.installEntry(
        entry,
        env: env,
        enable: enable,
        profile: servers.profile,
      );
      if (result.action case final action?) {
        _set(const McpBuilding());
        _follow(action, enable);
      } else {
        await _installed(enable);
      }
    } on McpRefused catch (e) {
      _set(McpInstallFailed(_couldNotInstall(e.reason)));
    } on Object catch (e) {
      if (isMcpNotFound(e)) {
        await catalog.load();
        _set(const McpInstallGone());
        if (!_disposed) onGone?.call();
      } else {
        _set(McpInstallFailed(_couldNotInstall()));
      }
    }
  }

  String _couldNotInstall([String reason = '']) =>
      reason.isNotEmpty ? reason : 'Could not install ${entry.name}';

  Future<void> _installed(bool enable) async {
    await servers.refresh();
    _set(const McpInstalled());
    if (!_disposed) onInstalled?.call();
    catalog.markInstalled(entry.name, enabled: enable);
  }

  void _follow(String action, bool enable) {
    _timer = Timer(pollInterval, () => _poll(action, enable));
  }

  Future<void> _poll(String action, bool enable) async {
    final HermesMcpAction status;
    try {
      status = await servers.repository.actionStatus(action);
    } on Object catch (e) {
      if (_disposed) return;
      if (isMcpNotFound(e) || ++_readFailures >= _maxReadFailures) {
        await _lostTrack();
      } else {
        _follow(action, enable);
      }
      return;
    }
    if (_disposed) return;
    _readFailures = 0;
    if (status.running) {
      _follow(action, enable);
    } else if (status.exitCode == 0) {
      await _installed(enable);
    } else if (status.exitCode == null) {
      await _lostTrack();
    } else {
      final lines = status.lines;
      _set(
        McpInstallFailed(
          'The build failed',
          log: lines.length > _logLines
              ? lines.sublist(lines.length - _logLines)
              : lines,
        ),
      );
    }
  }

  Future<void> _lostTrack() async {
    _set(McpInstallFailed('Could not follow the build of ${entry.name}'));
    await catalog.load();
  }

  void _set(McpInstallState state) {
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
