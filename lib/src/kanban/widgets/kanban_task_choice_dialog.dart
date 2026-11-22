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
    this.footer,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;

  /// The checked row, or null when none is: a choice with no current value,
  /// such as one made for several tasks at once.
  final T? selected;
  final ValueChanged<T> onPicked;

  /// A note under the rows, such as what the pick applies to.
  final String? footer;

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
          footer: footer,
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
