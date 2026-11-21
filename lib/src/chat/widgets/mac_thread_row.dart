import 'package:flutter/material.dart';

import '../../macos/mac_source_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/named_icon_button.dart';
import '../../widgets/named_popup_menu_button.dart';
import 'thread_actions_menu.dart';
import 'working_dot.dart';

/// A thread in a Mac sidebar: a 28pt row with its title. Under the pointer an
/// Archive button (when [onArchive] is given) and a More button show at the
/// trailing edge; More and a right-click open the thread's menu.
class MacThreadRow extends StatefulWidget {
  const MacThreadRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.menuItems,
    required this.onAction,
    this.busy = false,
    this.onArchive,
    this.relativeTime,
    this.avatar,
  });

  final Widget? avatar;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final PopupMenuItemBuilder<ThreadAction> menuItems;
  final ValueChanged<ThreadAction> onAction;

  /// Whether a turn is running in this thread: a small spinner at the
  /// trailing edge.
  final bool busy;
  final VoidCallback? onArchive;

  /// When the thread was last active, for screen readers.
  final String? relativeTime;

  @override
  State<MacThreadRow> createState() => _MacThreadRowState();
}

ButtonStyle _buttonStyle(BuildContext context) =>
    IconButton.styleFrom(
      minimumSize: const Size.square(20),
      maximumSize: const Size.square(20),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ).copyWith(
      shape: focusRingShapeOf(
        context,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );

class _MacThreadRowState extends State<MacThreadRow> {
  final _menu = AdaptiveMenuController();

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final onArchive = widget.onArchive;
    return Semantics(
      hint: widget.relativeTime,
      child: MacSourceListTile(
        selected: widget.selected,
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _menu.open(at: details.globalPosition),
        builder: (context, hovered) => Row(
          children: [
            if (widget.avatar != null) ...[
              widget.avatar!,
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (widget.busy) ...[const WorkingDot(), const SizedBox(width: 4)],
            Visibility(
              visible: hovered,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onArchive != null)
                    NamedIconButton(
                      label: 'Archive',
                      icon: AppIcons.archive,
                      iconSize: 14,
                      color: subtle,
                      style: _buttonStyle(context),
                      onPressed: onArchive,
                    ),
                  // The 20 pt buttons' rings reach 4 pt out; a 2 pt gap would
                  // put one over the other.
                  const SizedBox(width: 4),
                  NamedPopupMenuButton<ThreadAction>(
                    controller: _menu,
                    label: 'More actions for ${widget.title}',
                    tooltip: 'More',
                    icon: AppIcons.more,
                    iconSize: 14,
                    color: subtle,
                    padding: EdgeInsets.zero,
                    style: _buttonStyle(context),
                    itemBuilder: widget.menuItems,
                    onSelected: widget.onAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
