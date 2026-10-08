import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../widgets/grouped_list.dart';
import '../widgets/named_icon_button.dart';
import 'installed_plugin.dart';
import 'plugin_actions.dart';
import 'plugins_controller.dart';
import 'widgets/detail_page.dart';

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
    final busy = controller.isBusy(plugin.name);
    final removedReason = plugin.removedReason;
    return DetailPage(
      key: const Key('plugin-detail'),
      title: plugin.name,
      meta: [
        if (plugin.version.isNotEmpty) 'v${plugin.version}',
        if (plugin.source.isNotEmpty) plugin.source,
      ].join(' · '),
      description: plugin.description,
      sections: [
        if (removedReason != null)
          GroupedSection(
            children: [GroupedRow(title: 'Removed', warning: removedReason)],
          ),
        GroupedSection(
          children: [
            GroupedSwitchRow(
              key: const Key('plugin-enabled'),
              title: 'Enabled',
              subtitle: 'Applies to new chats',
              value: plugin.status == PluginStatus.enabled,
              onChanged: busy
                  ? null
                  : (value) => runPluginChange(
                      context,
                      () => controller.setEnabled(plugin.name, value),
                    ),
            ),
            GroupedSwitchRow(
              key: const Key('plugin-hidden'),
              title: 'Hide from dashboard sidebar',
              subtitle: 'Only affects the web dashboard',
              value: plugin.hidden,
              onChanged: busy
                  ? null
                  : (value) => runPluginChange(
                      context,
                      () => controller.setHidden(plugin.name, value),
                    ),
            ),
          ],
        ),
        if (plugin.authRequired) _LoginSection(command: plugin.authCommand),
        if (plugin.canUpdate || plugin.canRemove)
          GroupedSection(
            children: [
              if (plugin.canUpdate)
                GroupedRow(
                  key: const Key('plugin-update'),
                  title: 'Update',
                  chevron: false,
                  trailing: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  onTap: busy
                      ? null
                      : () => runPluginChange(
                          context,
                          () => controller.update(plugin.name),
                          success: (result) => result.unchanged
                              ? 'Already up to date'
                              : 'Updated ${plugin.name}',
                        ),
                ),
              if (plugin.canRemove)
                GroupedRow(
                  key: const Key('plugin-remove'),
                  title: 'Remove plugin',
                  destructive: true,
                  chevron: false,
                  onTap: busy
                      ? null
                      : () => removePlugin(context, controller, plugin),
                ),
            ],
          ),
      ],
    );
  }
}

class _LoginSection extends StatelessWidget {
  const _LoginSection({required this.command});

  final String? command;

  @override
  Widget build(BuildContext context) {
    final command = this.command;
    if (command == null) {
      return const GroupedSection(
        header: 'Needs login',
        children: [
          GroupedRow(title: 'This plugin needs a login on the server.'),
        ],
      );
    }
    final metrics = GroupedMetrics.of(context);
    return GroupedSection(
      header: 'Needs login',
      footer: 'Run this on the server.',
      children: [
        Padding(
          padding: EdgeInsets.only(left: metrics.rowPadding, right: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: metrics.subtitleSize,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                NamedIconButton(
                  key: const Key('plugin-copy-login'),
                  label: 'Copy command',
                  icon: AppIcons.copy,
                  iconSize: 18,
                  color: context.hermesColors.subtleText,
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
          ),
        ),
      ],
    );
  }
}
