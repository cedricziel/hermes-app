import 'package:flutter/cupertino.dart';

import '../theme/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/platform_chrome.dart';

/// One thing a list row can do besides opening: switch it, run it, delete it.
class RowAction {
  const RowAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final AppIconSet icon;
  final VoidCallback onPressed;

  /// Offered as a trailing swipe action and drawn in red.
  final bool destructive;
}

/// The Apple way to act on a list row. On iOS a swipe from the trailing edge
/// reveals the destructive actions and a long press opens an action sheet
/// with all of them; on macOS a right click opens a menu. VoiceOver gets every
/// action as a custom action on the row. Other platforms get [child] as is.
class RowActions extends StatelessWidget {
  const RowActions({
    super.key,
    required this.title,
    required this.actions,
    required this.child,
  });

  final String title;
  final List<RowAction> actions;
  final Widget child;

  Future<void> _showSheet(BuildContext context) async {
    final action = await showCupertinoModalPopup<RowAction>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.destructive,
              onPressed: () => Navigator.of(sheet).pop(action),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    action?.onPressed();
  }

  Future<void> _showMenu(BuildContext context, Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<RowAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
    action?.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    if (!chrome.isApple || actions.isEmpty) return child;
    final swipe = actions.where((action) => action.destructive).toList();
    return Semantics(
      customSemanticsActions: {
        for (final action in actions)
          CustomSemanticsAction(label: action.label): action.onPressed,
      },
      child: chrome == PlatformChrome.macos
          ? GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onSecondaryTapUp: (details) =>
                  _showMenu(context, details.globalPosition),
              child: child,
            )
          : Slidable(
              endActionPane: swipe.isEmpty
                  ? null
                  : ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.3,
                      children: [
                        for (final action in swipe)
                          SlidableAction(
                            onPressed: (_) => action.onPressed(),
                            backgroundColor: CupertinoColors.destructiveRed,
                            foregroundColor: CupertinoColors.white,
                            icon: action.icon.of(context),
                            label: action.label,
                          ),
                      ],
                    ),
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onLongPress: () => _showSheet(context),
                child: child,
              ),
            ),
    );
  }
}
