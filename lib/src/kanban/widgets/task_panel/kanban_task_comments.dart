import 'package:flutter/material.dart';

import '../../../theme/hermes_theme.dart';

import '../../../chat/widgets/relative_time.dart';
import '../../../theme/app_icons.dart';
import '../../kanban_models.dart';
import '../../../widgets/grouped_list.dart';
import '../../../widgets/grouped_form.dart';

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
    final subtle = theme.colorScheme.onSurface.withValues(
      alpha: kHermesMutedAlpha,
    );
    return GroupedSection(
      header: 'Comments (${widget.comments.length})',
      children: [
        for (final c in widget.comments)
          Padding(
            padding: EdgeInsets.all(GroupedMetrics.of(context).rowPadding),
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
        GroupedTextFieldRow(
          label: 'Comment',
          controller: _comment,
          hint: 'Add a comment…',
          onSubmitted: (_) => _send(),
        ),
        GroupedRow(
          title: 'Send',
          chevron: false,
          leading: const AppIcon(AppIcons.send),
          onTap: _send,
        ),
      ],
    );
  }
}
