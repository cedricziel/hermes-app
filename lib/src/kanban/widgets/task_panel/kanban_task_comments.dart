import 'package:flutter/material.dart';

import '../../../chat/widgets/relative_time.dart';
import '../../kanban_models.dart';
import 'kanban_task_heading.dart';

/// The task's comments and a field to add one. The field is cleared once
/// [onSend] reports the comment went through.
class KanbanTaskComments extends StatefulWidget {
  const KanbanTaskComments({
    super.key,
    required this.comments,
    required this.onSend,
  });

  final List<KanbanComment> comments;
  final Future<bool> Function(String text) onSend;

  @override
  State<KanbanTaskComments> createState() => _KanbanTaskCommentsState();
}

class _KanbanTaskCommentsState extends State<KanbanTaskComments> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    if (await widget.onSend(text) && mounted) _comment.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KanbanTaskHeading('Comments (${widget.comments.length})'),
        for (final c in widget.comments)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.author}${c.createdAt == null ? '' : ' · ${relativeTime(c.createdAt!)}'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                ),
                SelectableText(c.body),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Add a comment…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: _send,
            ),
          ],
        ),
      ],
    );
  }
}
