import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../installed_plugin.dart';

/// An installed plugin in the grouped list: its name and version, "Bundled"
/// and its description, a warning when it needs a login or was removed, and
/// whether it is on. The switch lives in its details, which [onTap] opens.
class PluginRow extends StatelessWidget {
  const PluginRow({
    super.key,
    required this.plugin,
    required this.onTap,
    this.selected = false,
  });

  final InstalledPlugin plugin;
  final VoidCallback onTap;

  /// The plugin whose details show beside the list.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (plugin.bundled) 'Bundled',
      if (plugin.description.isNotEmpty) plugin.description,
    ].join(' · ');
    final warning = [
      if (plugin.authRequired) 'Needs login',
      if (plugin.removedReason case final reason?) 'Removed: $reason',
    ].join(' · ');
    return GroupedRow(
      key: ValueKey('plugin-row-${plugin.name}'),
      title: plugin.name,
      meta: plugin.version.isEmpty ? null : 'v${plugin.version}',
      subtitle: subtitle.isEmpty ? null : subtitle,
      warning: warning.isEmpty ? null : warning,
      value: switch (plugin.status) {
        PluginStatus.enabled => 'On',
        PluginStatus.disabled => 'Off',
        PluginStatus.inactive => 'Inactive',
      },
      chevron: platformChromeOf(context).isApple,
      selected: selected,
      onTap: onTap,
    );
  }
}
