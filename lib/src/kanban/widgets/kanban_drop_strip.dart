import 'package:flutter/material.dart';

import '../kanban_models.dart';
import '../kanban_repository.dart';

/// The statuses a card dragged on a phone can be dropped on. The chip row
/// scrolls and would hide most of them, so they are laid out all at once,
/// over the top of the list while a drag lasts.
class KanbanDropStrip extends StatelessWidget {
  const KanbanDropStrip({super.key, required this.onDrop});

  final void Function(KanbanTask task, String status) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in kanbanSettableStatuses)
              DragTarget<KanbanTask>(
                onWillAcceptWithDetails: (d) => d.data.status != status,
                onAcceptWithDetails: (d) => onDrop(d.data, status),
                builder: (context, over, rejected) => KanbanDropStripChip(
                  label: kanbanStatusLabel(status),
                  active: over.isNotEmpty,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One status in [KanbanDropStrip]. [active] is a card hovering over it.
class KanbanDropStripChip extends StatelessWidget {
  const KanbanDropStripChip({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Chip(
      label: Text(label),
      // The theme defines no container roles, so primaryContainer falls back
      // to primary and the default label colour vanished on it. Pair the fill
      // with onPrimary.
      backgroundColor: active ? scheme.primary : null,
      labelStyle: active
          ? theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimary)
          : null,
      side: BorderSide(color: active ? scheme.primary : scheme.outline),
    );
  }
}
