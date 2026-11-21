import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../theme/app_icons.dart';
import '../../widgets/app_action_sheet.dart';
import 'thread_actions_menu.dart';

/// The iOS way to act on a thread row: swipe right to pin, swipe left to
/// delete, long press for every action in an action sheet. VoiceOver gets the
/// same actions as custom actions on the row.
class SwipeableThreadRow extends StatelessWidget {
  const SwipeableThreadRow({
    super.key,
    required this.title,
    required this.pinned,
    required this.onAction,
    required this.child,
  });

  final String title;
  final bool pinned;
  final ValueChanged<ThreadAction> onAction;
  final Widget child;

  String get _pinLabel => pinned ? 'Unpin' : 'Pin';

  Future<void> _showSheet(BuildContext context) async {
    final action = await showAppActionSheet<ThreadAction>(
      context: context,
      title: title,
      entries: [
        const AppActionSheetEntry('Rename', ThreadAction.rename),
        AppActionSheetEntry(_pinLabel, ThreadAction.pin),
        const AppActionSheetEntry('Archive', ThreadAction.archive),
        const AppActionSheetEntry(
          'Delete',
          ThreadAction.delete,
          destructive: true,
        ),
      ],
    );
    if (action != null && context.mounted) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Rename'): () =>
            onAction(ThreadAction.rename),
        CustomSemanticsAction(label: _pinLabel): () =>
            onAction(ThreadAction.pin),
        const CustomSemanticsAction(label: 'Archive'): () =>
            onAction(ThreadAction.archive),
        const CustomSemanticsAction(label: 'Delete'): () =>
            onAction(ThreadAction.delete),
      },
      child: Slidable(
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            SlidableAction(
              onPressed: (_) => onAction(ThreadAction.pin),
              backgroundColor: CupertinoColors.systemOrange,
              foregroundColor: CupertinoColors.white,
              icon: (pinned ? AppIcons.unpin : AppIcons.pin).of(context),
              label: _pinLabel,
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            SlidableAction(
              onPressed: (_) => onAction(ThreadAction.delete),
              backgroundColor: CupertinoColors.destructiveRed,
              foregroundColor: CupertinoColors.white,
              icon: AppIcons.delete.of(context),
              label: 'Delete',
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
