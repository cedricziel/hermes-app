import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/row_actions.dart';
import 'installed_plugin.dart';
import 'plugins_controller.dart';

const _fallback = 'Could not update this plugin';

/// Runs a change to a plugin and says so in a snack bar when the server
/// refused it, or when [success] has something to report.
Future<void> runPluginChange(
  BuildContext context,
  Future<PluginActionResult> Function() change, {
  String failure = _fallback,
  String? Function(PluginActionResult result)? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await change();
  final message = result.ok ? success?.call(result) : result.message ?? failure;
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Asks before removing [plugin] from the server, then does it.
Future<void> removePlugin(
  BuildContext context,
  PluginsController controller,
  InstalledPlugin plugin,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Remove ${plugin.name}?',
    message: 'Its files are deleted from the server.',
    confirmLabel: 'Remove',
    destructive: true,
    filled: false,
  );
  if (!confirmed || !context.mounted) return;
  await runPluginChange(
    context,
    () => controller.remove(plugin.name),
    failure: 'Could not remove this plugin',
  );
}

/// The row actions of [plugin] in the list: switch it, remove it.
List<RowAction> pluginRowActions(
  BuildContext context,
  PluginsController controller,
  InstalledPlugin plugin,
) {
  final enabled = plugin.status == PluginStatus.enabled;
  final busy = controller.isBusy(plugin.name);
  return [
    if (!busy)
      RowAction(
        label: enabled ? 'Disable' : 'Enable',
        icon: enabled ? AppIcons.toggleOff : AppIcons.toggleOn,
        onPressed: () => runPluginChange(
          context,
          () => controller.setEnabled(plugin.name, !enabled),
        ),
      ),
    if (plugin.canRemove && !busy)
      RowAction(
        label: 'Remove',
        icon: AppIcons.delete,
        destructive: true,
        onPressed: () => removePlugin(context, controller, plugin),
      ),
  ];
}
