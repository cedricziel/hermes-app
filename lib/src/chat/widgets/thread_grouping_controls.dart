import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../macos/mac_source_list.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../thread_list_preferences.dart';

class ThreadGroupingMenu extends StatelessWidget {
  const ThreadGroupingMenu({
    super.key,
    required this.grouping,
    required this.onChanged,
  });

  final ThreadGrouping grouping;
  final ValueChanged<ThreadGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return NamedPopupMenuButton<ThreadGrouping>(
      iconSize: 14,
      color: context.hermesColors.subtleText,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: Size.square(mac ? 24 : kAppleMinTapTarget),
        maximumSize: Size.square(mac ? 24 : kAppleMinTapTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      label: 'Group chats',
      icon: AppIcons.more,
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(enabled: false, child: Text('Group by')),
        for (final value in ThreadGrouping.values)
          CheckedPopupMenuItem(
            value: value,
            checked: grouping == value,
            child: Text(value == ThreadGrouping.recent ? 'Recent' : 'Folder'),
          ),
      ],
    );
  }
}

class ThreadSectionHeader extends StatelessWidget {
  const ThreadSectionHeader({
    super.key,
    required this.label,
    required this.collapsed,
    required this.onToggle,
    this.count,
  });

  final String label;
  final bool collapsed;
  final VoidCallback onToggle;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = context.hermesColors.subtleText;
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: !collapsed,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.centerLeft,
          onPressed: onToggle,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text('$count', style: TextStyle(fontSize: 12, color: color)),
              ],
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: AppIcon(AppIcons.expandMore, size: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThreadSectionHeading extends StatelessWidget {
  const ThreadSectionHeading({
    super.key,
    required this.label,
    required this.grouping,
    this.onToggle,
    this.collapsed = false,
    this.count,
    this.onGroupingChanged,
  });

  final String label;
  final ThreadGrouping grouping;
  final VoidCallback? onToggle;
  final bool collapsed;
  final int? count;
  final ValueChanged<ThreadGrouping>? onGroupingChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: onToggle == null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(label, style: macSectionHeaderStyle(context)),
              )
            : platformChromeOf(context) == PlatformChrome.macos
            ? MacSidebarSectionHeader(
                label: label,
                count: count,
                collapsed: collapsed,
                onToggle: onToggle!,
              )
            : ThreadSectionHeader(
                label: label,
                count: count,
                collapsed: collapsed,
                onToggle: onToggle!,
              ),
      ),
      if (onGroupingChanged != null)
        ThreadGroupingMenu(grouping: grouping, onChanged: onGroupingChanged!),
    ],
  );
}
