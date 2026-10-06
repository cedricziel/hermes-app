import 'package:flutter/material.dart';

import '../../chat/widgets/thread_actions_menu.dart';
import '../../macos/mac_toolbar.dart';
import '../../macos/mac_window.dart';
import '../../theme/app_icons.dart';
import '../../widgets/adaptive_popup_menu_button.dart';

/// The toolbar of a conversation window on macOS: the traffic lights, the
/// chat's title with its profile and model under it, and the window's
/// actions. A null callback disables its button.
class ConversationWindowToolbar extends StatelessWidget {
  const ConversationWindowToolbar({
    super.key,
    required this.title,
    this.subtitle,
    required this.pinned,
    this.onShowInMain,
    this.onTogglePin,
    this.onShare,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final bool pinned;
  final VoidCallback? onShowInMain;
  final VoidCallback? onTogglePin;

  /// Called with the Share button's rect in the window, for the share
  /// picker to point at.
  final ValueChanged<Rect>? onShare;

  /// Called for Rename, Copy Transcript, Archive and Delete in the … menu.
  final ValueChanged<ThreadAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final onShare = this.onShare;
    return MacWindowDragArea(
      child: SizedBox(
        height: kMacToolbarHeight,
        child: Row(
          children: [
            const SizedBox(width: kMacTrafficLightsWidth + 8),
            Expanded(
              child: MacToolbarTitle(title: title, subtitle: subtitle),
            ),
            MacToolbarButton(
              label: 'Show in Main Window',
              icon: AppIcons.sidebar,
              onPressed: onShowInMain,
            ),
            const SizedBox(width: 4),
            MacToolbarButton(
              label: pinned ? 'Unpin' : 'Pin',
              shortcut: '⇧⌘P',
              icon: pinned ? AppIcons.pin : AppIcons.pinOutline,
              selected: pinned,
              onPressed: onTogglePin,
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (button) => MacToolbarButton(
                label: 'Share',
                icon: AppIcons.share,
                onPressed: onShare == null
                    ? null
                    : () => onShare(_rectOf(button)),
              ),
            ),
            const SizedBox(width: 4),
            _MoreButton(onAction: onAction),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  static Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// The … button: the thread actions in the platform's menu (compact rows on
/// macOS), Delete last.
class _MoreButton extends StatefulWidget {
  const _MoreButton({required this.onAction});

  final ValueChanged<ThreadAction>? onAction;

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  final _menu = AdaptiveMenuController();

  @override
  Widget build(BuildContext context) {
    final onAction = widget.onAction;
    final button = MacToolbarButton(
      label: 'More',
      icon: AppIcons.more,
      onPressed: onAction == null ? null : _menu.open,
    );
    if (onAction == null) return button;
    return AdaptivePopupMenuButton<ThreadAction>(
      controller: _menu,
      tooltip: '',
      onSelected: onAction,
      // Pin has its own toolbar button.
      itemBuilder: (_) => [
        for (final entry in macThreadMenuItems(pinned: false, manageable: true))
          if (entry is! PopupMenuItem<ThreadAction> ||
              entry.value != ThreadAction.pin)
            entry,
      ],
      child: button,
    );
  }
}
