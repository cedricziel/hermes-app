import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class KanbanTaskEditFields extends StatelessWidget {
  const KanbanTaskEditFields({
    super.key,
    required this.title,
    required this.body,
  });

  final TextEditingController title;
  final TextEditingController body;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          children: [
            GroupedTextFieldRow(
              label: l10n.kanbanEditTaskTitleLabel,
              controller: title,
            ),
          ],
        ),
        GroupedSection(
          header: l10n.kanbanEditTaskDescriptionLabel,
          children: [
            GroupedTextFieldRow(
              label: l10n.kanbanEditTaskDescriptionLabel,
              controller: body,
              minLines: 3,
              maxLines: 8,
            ),
          ],
        ),
      ],
    );
  }
}
