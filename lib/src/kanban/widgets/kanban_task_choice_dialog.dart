import 'package:flutter/material.dart';

import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/grouped_choice_row.dart';

class KanbanTaskChoiceDialog<T> extends StatelessWidget {
  const KanbanTaskChoiceDialog({
    super.key,
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onPicked,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onPicked;

  @override
  Widget build(BuildContext context) => GroupedDialog(
    title: title,
    children: [
      RadioGroup<T>(
        groupValue: selected,
        onChanged: (value) {
          if (value != null) onPicked(value);
        },
        child: GroupedSection(
          dividerIndent: GroupedChoiceRow.dividerIndent(context),
          children: [
            for (final option in options)
              GroupedChoiceRow<T>(
                value: option,
                title: labelOf(option),
                titleMaxLines: null,
              ),
          ],
        ),
      ),
    ],
  );
}
