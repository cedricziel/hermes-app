import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        children: [GroupedTextFieldRow(label: 'Title', controller: title)],
      ),
      GroupedSection(
        header: 'Description',
        children: [
          GroupedTextFieldRow(
            label: 'Description',
            controller: body,
            minLines: 3,
            maxLines: 8,
          ),
        ],
      ),
    ],
  );
}
