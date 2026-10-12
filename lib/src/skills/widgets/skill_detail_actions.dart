import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

class SkillDetailActions extends StatelessWidget {
  const SkillDetailActions({
    super.key,
    required this.enabled,
    required this.editable,
    required this.contentReady,
    required this.canUninstall,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onAskDelete,
    required this.onUninstall,
  });
  final bool enabled, editable, contentReady, canUninstall, busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit, onAskDelete, onUninstall;

  @override
  Widget build(BuildContext context) => GroupedSection(
    footer: !editable && !canUninstall
        ? 'Bundled and hub skills can only be switched on or off here.'
        : null,
    children: [
      GroupedSwitchRow(
        title: 'Enabled',
        subtitle: 'The agent may load this skill',
        value: enabled,
        onChanged: onToggle,
        onTap: () => onToggle(!enabled),
      ),
      if (editable) ...[
        GroupedRow(
          title: 'Edit',
          enabled: contentReady,
          onTap: contentReady ? onEdit : null,
        ),
        GroupedRow(
          title: 'Ask agent to delete',
          destructive: true,
          chevron: false,
          onTap: onAskDelete,
        ),
      ] else if (canUninstall)
        GroupedRow(
          title: 'Uninstall',
          destructive: true,
          chevron: false,
          enabled: !busy,
          onTap: busy ? null : onUninstall,
        ),
    ],
  );
}
