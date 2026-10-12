import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';
import '../kanban_models.dart';

class KanbanWorkerLog extends StatelessWidget {
  const KanbanWorkerLog({super.key, this.log, this.failed = false});

  final KanbanTaskLog? log;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final result = log;
    final text = result == null
        ? (failed ? 'Could not load the log.' : 'Loading…')
        : !result.exists
        ? 'No worker has run this task yet.'
        : result.content.isEmpty
        ? '(empty)'
        : result.content;
    return GroupedSection(
      children: [
        Padding(
          padding: EdgeInsets.all(GroupedMetrics.of(context).rowPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                result?.truncated == true
                    ? '… (earlier output cut)\n$text'
                    : text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
