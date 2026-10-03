import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import 'plugin_install_result.dart';

const installStillRunningText =
    'The server is still installing. Pull the list down in a moment to check.';

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
  final lines = [
    if (result.ok)
      result.pluginName.isEmpty ? 'Installed' : 'Installed ${result.pluginName}'
    else if (result.timedOut)
      installStillRunningText
    else
      result.message ?? 'Could not install this plugin',
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
  await showAdaptiveDialog<void>(
    context: context,
    builder: (context) => AppAlertDialog(
      title: const Text('Set these on the server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final name in result.missingEnv)
            Text(name, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
