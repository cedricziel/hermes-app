import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';

import '../../models/model_provider_option.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../kanban_errors.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';

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

  Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<(String, T)> options,
  ) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (label, value) in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Text(label),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final none = selectedCount == 0;
    final actions = <_BulkAction>[
      _BulkAction('Move', AppIcons.move, () async {
        final status = await _pick(context, 'Move to', [
          for (final s in kanbanSettableStatuses) (kanbanStatusLabel(s), s),
        ]);
        if (status != null) onMove(status);
      }),
      _BulkAction('Assign', AppIcons.personAdd, () async {
        final assignee = await _pick(context, 'Assign to', [
          ('Nobody', ''),
          for (final n in assignees) (n, n),
        ]);
        if (assignee != null) onAssign(assignee);
      }),
      _BulkAction('Priority', AppIcons.flag, () async {
        final priority = await _pick(context, 'Priority', [
          ('Normal', 0),
          for (final p in [1, 2, 3]) ('P$p', p),
        ]);
        if (priority != null) onPriority(priority);
      }),
      _BulkAction('Effort', AppIcons.reasoning, () async {
        final effort = await _pick(context, 'Reasoning effort', [
          ('Profile default', ''),
          for (final e in kReasoningEfforts)
            if (e != 'none') (effortLabel(e), e),
        ]);
        if (effort != null) onEffort(effort);
      }),
      _BulkAction('Archive', AppIcons.archive, () async {
        if (await confirmKanban(
          context,
          title: 'Archive $selectedCount tasks?',
          confirm: 'Archive',
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
