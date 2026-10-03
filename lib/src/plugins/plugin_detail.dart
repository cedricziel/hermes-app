import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'installed_plugin.dart';
import 'plugin_actions.dart';
import 'plugin_tag.dart';
import 'plugins_controller.dart';

import '../widgets/named_icon_button.dart';

/// One plugin's details and the changes the user can make to it. Shown in a
/// bottom sheet or in a pane; it does not know which.
class PluginDetail extends StatelessWidget {
  const PluginDetail({
    super.key,
    required this.plugin,
    required this.controller,
  });

  final InstalledPlugin plugin;
  final PluginsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurfaceVariant;
    final busy = controller.isBusy(plugin.name);
    final meta = [
      if (plugin.version.isNotEmpty) 'v${plugin.version}',
      if (plugin.source.isNotEmpty) plugin.source,
    ].join(' · ');
    return SingleChildScrollView(
      key: const Key('plugin-detail'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plugin.name, style: theme.textTheme.titleLarge),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(color: subtle),
            ),
          if (plugin.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(plugin.description),
          ],
          if (plugin.removedReason case final reason?) ...[
            const SizedBox(height: 12),
            PluginTag('Removed: $reason', strong: true),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            key: const Key('plugin-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: const Text('Applies to new chats'),
            value: plugin.status == PluginStatus.enabled,
            onChanged: busy
                ? null
                : (value) => runPluginChange(
                    context,
                    () => controller.setEnabled(plugin.name, value),
                  ),
          ),
          SwitchListTile.adaptive(
            key: const Key('plugin-hidden'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide from dashboard sidebar'),
            subtitle: const Text('Only affects the web dashboard'),
            value: plugin.hidden,
            onChanged: busy
                ? null
                : (value) => runPluginChange(
                    context,
                    () => controller.setHidden(plugin.name, value),
                  ),
          ),
          if (plugin.canUpdate) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const Key('plugin-update'),
              onPressed: busy
                  ? null
                  : () => runPluginChange(
                      context,
                      () => controller.update(plugin.name),
                      success: (result) => result.unchanged
                          ? 'Already up to date'
                          : 'Updated ${plugin.name}',
                    ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
          if (plugin.authRequired) ...[
            const SizedBox(height: 16),
            _LoginBlock(command: plugin.authCommand),
          ],
          if (plugin.canRemove) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              key: const Key('plugin-remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              onPressed: busy
                  ? null
                  : () => removePlugin(context, controller, plugin),
              child: const Text('Remove plugin'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginBlock extends StatelessWidget {
  const _LoginBlock({required this.command});

  final String? command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final command = this.command;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs login', style: theme.textTheme.labelLarge),
          if (command == null)
            const Text('This plugin needs a login on the server.')
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                NamedIconButton(
                  key: const Key('plugin-copy-login'),
                  label: 'Copy command',
                  icon: Icons.copy,
                  iconSize: 18,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: command));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
              ],
            ),
          Text(
            'Run this on the server.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
