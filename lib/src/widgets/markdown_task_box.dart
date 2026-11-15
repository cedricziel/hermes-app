import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A `GptMarkdown.checkboxBuilder` that draws a task-list item (`- [x] done`)
/// as a state, not a control.
///
/// The package's own box is a Material `Checkbox`, which throws when no
/// Material sits between it and the text (a Scaffold's is not enough: the
/// lookup stops at the text's inline widget) and would stay focusable and
/// hoverable in markdown that nobody can edit. This one needs no Material,
/// cannot be tapped, and reads as checked or unchecked to a screen reader.
Widget readOnlyTaskBox(
  BuildContext context,
  bool checked,
  Widget content,
  CheckboxStyle style,
) {
  final scheme = Theme.of(context).colorScheme;
  final size = MediaQuery.textScalerOf(context).scale(20);
  return MergeSemantics(
    child: Semantics(
      checked: checked,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 5, end: 8),
            child: ExcludeSemantics(
              child: Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: size,
                color: checked ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(child: content),
        ],
      ),
    ),
  );
}
