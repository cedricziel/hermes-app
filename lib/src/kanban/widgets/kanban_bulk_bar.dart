import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButton;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../models/model_provider_option.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../kanban_errors.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';
import 'kanban_task_choice_dialog.dart';

/// The actions for the tasks picked in selection mode. Each asks for its
/// value first and reports it; nothing is offered while none are picked.
class KanbanBulkBar extends StatelessWidget {
  const KanbanBulkBar({
    super.key,
    required this.selectedCount,
    required this.assignees,
    required this.onMove,
    required this.onAssign,
    required this.onPriority,
    required this.onEffort,
    required this.onArchive,
  });

  final int selectedCount;

  /// The names offered by Assign, after "Nobody" (an empty string).
  final List<String> assignees;
  final ValueChanged<String> onMove;
  final ValueChanged<String> onAssign;
  final ValueChanged<int> onPriority;

  /// A reasoning effort, or an empty string for the profile's own.
  final ValueChanged<String> onEffort;
  final VoidCallback onArchive;

  /// Asks which of [options] to apply to every selected task. No row is
  /// checked, since the tasks have no single current value; the footer says
  /// how many tasks the pick reaches. Closing without a pick returns null.
  Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<(String, T)> options,
  ) => showKanbanDialog<T>(
    context,
    builder: (dialog) => KanbanTaskChoiceDialog<(String, T)>(
      title: title,
      options: options,
      labelOf: (option) => option.$1,
      selected: null,
      footer: dialog.l10n.kanbanBulkPickerFooter(selectedCount),
      // Cancel, not the header's Done: Move to has a status named Done.
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(dialog.l10n.widgetsCancel),
        ),
      ],
      onPicked: (option) => Navigator.pop(dialog, option.$2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final none = selectedCount == 0;
    final l10n = context.l10n;
    final actions = <_BulkAction>[
      _BulkAction(l10n.kanbanBulkActionMove, AppIcons.move, () async {
        final status = await _pick(context, l10n.kanbanBulkMoveTitle, [
          for (final s in kanbanSettableStatuses) (kanbanStatusLabel(s), s),
        ]);
        if (status != null) onMove(status);
      }),
      _BulkAction(l10n.kanbanBulkActionAssign, AppIcons.personAdd, () async {
        final assignee = await _pick(context, l10n.kanbanBulkAssignTitle, [
          (l10n.kanbanBulkNobody, ''),
          for (final n in assignees) (n, n),
        ]);
        if (assignee != null) onAssign(assignee);
      }),
      _BulkAction(l10n.kanbanBulkActionPriority, AppIcons.flag, () async {
        final priority = await _pick(context, l10n.kanbanBulkPriorityTitle, [
          (l10n.kanbanBulkPriorityNormal, 0),
          for (final p in [1, 2, 3]) ('P$p', p),
        ]);
        if (priority != null) onPriority(priority);
      }),
      _BulkAction(l10n.kanbanBulkActionEffort, AppIcons.reasoning, () async {
        final effort = await _pick(context, l10n.kanbanBulkEffortTitle, [
          (l10n.kanbanBulkEffortDefault, ''),
          for (final e in kReasoningEfforts)
            if (e != 'none') (effortLabel(e), e),
        ]);
        if (effort != null) onEffort(effort);
      }),
      _BulkAction(l10n.kanbanBulkActionArchive, AppIcons.archive, () async {
        if (await confirmKanban(
          context,
          title: l10n.kanbanBulkArchiveTitle(selectedCount),
          confirm: l10n.kanbanBulkArchiveConfirm,
        )) {
          onArchive();
        }
      }),
    ];

    if (platformChromeOf(context) == PlatformChrome.ios) {
      final theme = Theme.of(context);
      return Material(
        color: theme.colorScheme.surface,
        shape: Border(top: BorderSide(color: theme.colorScheme.outline)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kAppleNavBarHeight,
            child: Row(
              children: [
                for (final action in actions)
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size.square(kAppleMinTapTarget),
                      onPressed: none ? null : action.onPressed,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(action.icon, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              action.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final action in actions)
            Expanded(
              child: TextButton(
                onPressed: none ? null : action.onPressed,
                child: Text(action.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _BulkAction {
  const _BulkAction(this.label, this.icon, this.onPressed);

  final String label;
  final AppIconSet icon;
  final VoidCallback onPressed;
}
