import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

import 'plugin_install_result.dart';
import 'widgets/plugin_missing_env_dialog.dart';

/// Tells the user how an install ended: what was installed and any warnings
/// the server gave, or why it was refused. A dialog then lists the
/// environment variables the user still has to set on the server.
///
/// Used for a catalog install and a Git URL install alike, so the two cannot
/// drift apart.
Future<void> reportInstall(
  BuildContext context,
  PluginInstallResult result,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final lines = [
    if (result.ok)
      result.pluginName.isEmpty
          ? l10n.pluginsInstalled
          : l10n.pluginsInstalledNamed(result.pluginName)
    else if (result.timedOut)
      l10n.pluginsInstallStillRunning
    else
      result.message ?? l10n.pluginsInstallFailed,
    if (result.ok) ...result.warnings,
  ];
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: result.warnings.isEmpty ? 4 : 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line)],
        ),
      ),
    );
  if (!result.ok || result.missingEnv.isEmpty || !context.mounted) return;
  await showAppDialog<void>(
    context: context,
    builder: (_) => PluginMissingEnvDialog(missingEnv: result.missingEnv),
  );
}
