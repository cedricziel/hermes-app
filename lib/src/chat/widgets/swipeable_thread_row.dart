import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/app_action_sheet.dart';
import 'thread_actions_menu.dart';
import 'touch_row_menu.dart';

/// The iOS way to act on a thread row: swipe right to pin, swipe left to
/// delete, long press for every action in an action sheet, or in a popover
/// menu at the row on an iPad ([TouchRowMenu]). VoiceOver gets the same
/// actions as custom actions on the row.
class SwipeableThreadRow extends StatelessWidget {
  const SwipeableThreadRow({
    super.key,
    required this.title,
    required this.pinned,
    required this.onAction,
    required this.child,
    this.canonical = false,
  });

  final String title;
  final bool pinned;
  final ValueChanged<ThreadAction> onAction;
  final Widget child;

  /// A canonical Bot Chat: the popover leaves out Rename and offers Retire.
  final bool canonical;

  String _pinLabel(BuildContext context) => pinned
      ? context.l10n.chatWidgetsThreadMenuUnpin
      : context.l10n.chatWidgetsThreadMenuPin;

  String _archiveLabel(BuildContext context) => canonical
      ? context.l10n.chatWidgetsThreadMenuRetire
      : context.l10n.chatWidgetsThreadMenuArchive;

  Future<void> _showSheet(BuildContext context) async {
    final l10n = context.l10n;
    final pinLabel = _pinLabel(context);
    final archiveLabel = _archiveLabel(context);
    final action = await showAppActionSheet<ThreadAction>(
      context: context,
      title: title,
      entries: [
        for (final (action, label) in [
          if (!canonical)
            (ThreadAction.rename, l10n.chatWidgetsThreadMenuRename),
          (ThreadAction.pin, pinLabel),
          (ThreadAction.archive, archiveLabel),
        ])
          AppActionSheetEntry(label: label, value: action),
        AppActionSheetEntry(
          label: l10n.chatWidgetsThreadMenuDelete,
          value: ThreadAction.delete,
          destructive: true,
        ),
      ],
    );
    if (action != null && context.mounted) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pinLabel = _pinLabel(context);
    return Semantics(
      customSemanticsActions: {
        if (!canonical)
          CustomSemanticsAction(label: l10n.chatWidgetsThreadMenuRename): () =>
              onAction(ThreadAction.rename),
        CustomSemanticsAction(label: pinLabel): () =>
            onAction(ThreadAction.pin),
        CustomSemanticsAction(label: _archiveLabel(context)): () =>
            onAction(ThreadAction.archive),
        CustomSemanticsAction(label: l10n.chatWidgetsThreadMenuDelete): () =>
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
              label: pinLabel,
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
              label: l10n.chatWidgetsThreadMenuDelete,
            ),
          ],
        ),
        child: isWideLayout(context)
            ? TouchRowMenu(
                title: title,
                pinned: pinned,
                canonical: canonical,
                onAction: onAction,
                child: child,
              )
            : GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onLongPress: () => _showSheet(context),
                child: child,
              ),
      ),
    );
  }
}
