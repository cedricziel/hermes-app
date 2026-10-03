import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
    final action = await showCupertinoModalPopup<ThreadAction>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          for (final (action, label) in [
            (ThreadAction.rename, 'Rename'),
            (ThreadAction.pin, _pinLabel),
            (ThreadAction.archive, 'Archive'),
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheet).pop(action),
              child: Text(label),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheet).pop(ThreadAction.delete),
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (action != null) onAction(action);
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
              icon: pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
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
              icon: CupertinoIcons.delete,
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
