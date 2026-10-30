import 'package:flutter/material.dart';

import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_list.dart';

/// Asks which of [options] (value and label) to use, with [current] checked.
/// Answers the picked value, or null when the dialog is closed with Done.
Future<T?> showMemoryChoice<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T current,
}) => showDialog<T>(
  context: context,
  builder: (dialog) => GroupedDialog(
    title: title,
    children: [
      RadioGroup<T>(
        groupValue: current,
        onChanged: (value) => Navigator.pop(dialog, value),
        child: GroupedSection(
          dividerIndent: GroupedChoiceRow.dividerIndent(dialog),
          children: [
            for (final (value, label) in options)
              GroupedChoiceRow<T>(value: value, title: label),
          ],
        ),
      ),
    ],
  ),
);
