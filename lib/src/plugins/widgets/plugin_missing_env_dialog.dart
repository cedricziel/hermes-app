import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';

/// Lists the environment variables a plugin still needs on the server, in the
/// order given, in a monospace face. OK closes it.
class PluginMissingEnvDialog extends StatelessWidget {
  const PluginMissingEnvDialog({super.key, required this.missingEnv});

  final List<String> missingEnv;

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(context.l10n.pluginsInstallMissingEnvTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final name in missingEnv)
            Text(name, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
