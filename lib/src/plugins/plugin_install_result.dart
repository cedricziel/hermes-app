/// How an install ended. [ok] means the server installed the plugin as
/// [pluginName]; [message] is the server's reason when it refused;
/// [timedOut] means the app stopped waiting, which is not a failure: the
/// server may still finish.
class PluginInstallResult {
  const PluginInstallResult({
    required this.ok,
    this.pluginName = '',
    this.warnings = const [],
    this.missingEnv = const [],
    this.message,
    this.timedOut = false,
  });

  final bool ok;
  final String pluginName;
  final List<String> warnings;

  /// Names of environment variables the user still has to set on the server.
  final List<String> missingEnv;
  final String? message;
  final bool timedOut;
}
