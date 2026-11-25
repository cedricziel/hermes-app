import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';
import '../kanban_models.dart';

class KanbanWorkerLog extends StatelessWidget {
  const KanbanWorkerLog({super.key, this.log, this.failed = false});

  final KanbanTaskLog? log;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = log;
    final text = result == null
        ? (failed ? l10n.kanbanLogLoadFailed : l10n.kanbanLogLoading)
        : !result.exists
        ? l10n.kanbanLogNone
        : result.content.isEmpty
        ? l10n.kanbanLogEmpty
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
                    ? '${l10n.kanbanLogCut}\n$text'
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
