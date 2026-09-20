/// Whether the server runs a plugin: `enabled`, `disabled`, or `inactive`
/// (found but never switched on). A value the app does not know reads as
/// inactive.
enum PluginStatus { enabled, disabled, inactive }

/// One row of the dashboard's plugin hub.
///
/// The server's `path` for the plugin is deliberately not read, so it cannot
/// reach the screen or telemetry.
class InstalledPlugin {
  const InstalledPlugin({
    required this.name,
    this.version = '',
    this.description = '',
    this.source = '',
    this.status = PluginStatus.inactive,
    this.canRemove = false,
    this.canUpdate = false,
    this.authRequired = false,
    this.authCommand,
    this.hidden = false,
    this.removedReason,
  });

  final String name;
  final String version;
  final String description;

  /// Where the plugin comes from: `bundled`, `user` or `entrypoint`.
  final String source;
  final PluginStatus status;
  final bool canRemove;

  /// Whether the server can pull a newer version (`can_update_git`).
  final bool canUpdate;

  /// The plugin's tools need a login the user runs on the server.
  final bool authRequired;
  final String? authCommand;

  /// The user hid the plugin from the web dashboard's sidebar.
  final bool hidden;

  /// Why the server's catalog dropped this plugin, when it did.
  final String? removedReason;

  bool get bundled => source == 'bundled';
}

/// What the server said to a change: [ok], whether it [unchanged] anything,
/// and, when it refused, its own reason as [message].
class PluginActionResult {
  const PluginActionResult({
    required this.ok,
    this.unchanged = false,
    this.message,
  });

  final bool ok;
  final bool unchanged;
  final String? message;
}
