import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../memory_usage.dart';

/// The controls under an open entry: the field while it is edited with its
/// character budget in the file, a note that a change only reaches new chats,
/// and the actions.
class MemoryEntryEditor extends StatelessWidget {
  const MemoryEntryEditor({
    super.key,
    required this.tab,
    required this.editing,
    this.draft,
    this.fieldKey,
    this.left,
    this.message,
    this.pending = false,
    this.blocked = false,
    this.canSave = false,
    this.uncertain = false,
    required this.onChanged,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
    required this.onCheck,
  });

  final MemoryTab tab;
  final bool editing;

  /// The text the field starts with while [editing]; its length is the
  /// count shown under it.
  final String? draft;
  final Object? fieldKey;

  /// What is left in the file with the draft in place; null when the file's
  /// limit is unknown.
  final int? left;
  final String? message;
  final bool pending, blocked, canSave, uncertain;
  final ValueChanged<String> onChanged;
  final VoidCallback onEdit, onSave, onCancel, onDelete, onCheck;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final muted = TextStyle(color: colors.subtleText, fontSize: 13);
    final left = this.left;
    final over = left != null && left < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editing) ...[
          TextFormField(
            key: ValueKey(fieldKey),
            initialValue: draft,
            enabled: !pending,
            minLines: 4,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Full memory content',
              border: OutlineInputBorder(),
            ),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text('${characterCount(draft ?? '')} characters', style: muted),
                const Spacer(),
                if (left != null)
                  Text(
                    over
                        ? '${groupThousands(-left)} over the limit in ${tab.label}'
                        : '${groupThousands(left)} left in ${tab.label}',
                    style: over ? muted.copyWith(color: colors.warning) : muted,
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Used from the next chat. Chats that are already open keep the '
            'memory they started with.',
            style: muted,
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(message!),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!editing)
              TextButton(
                onPressed: blocked ? null : onEdit,
                child: const Text('Edit'),
              ),
            if (editing)
              FilledButton(
                onPressed: canSave ? onSave : null,
                child: Text(pending ? 'Saving...' : 'Save'),
              ),
            if (editing)
              TextButton(
                onPressed: pending ? null : onCancel,
                child: const Text('Cancel edit'),
              ),
            TextButton(
              onPressed: blocked ? null : onDelete,
              child: const Text('Delete entry'),
            ),
            if (uncertain)
              TextButton(
                onPressed: onCheck,
                child: const Text('Check current memories'),
              ),
          ],
        ),
        if (pending) const LinearProgressIndicator(),
      ],
    );
  }
}
