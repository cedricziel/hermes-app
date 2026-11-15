import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A `GptMarkdown.checkboxBuilder` that draws a task-list item (`- [x] done`)
/// as a state, not a control.
///
/// gpt_markdown 1.4.1 builds its `Checkbox` and `Radio` from the separate
/// `material_ui` package, whose `debugCheckHasMaterial` wants a `material_ui`
/// Material, not Flutter's: a Scaffold above the text does not satisfy it.
/// Chat works only because `FlyerMaterialScope` provides one. These builders
/// need no Material, cannot be tapped or focused, and read as checked or
/// unchecked (or selected) to a screen reader.
Widget readOnlyTaskBox(
  BuildContext context,
  bool checked,
  Widget content,
  CheckboxStyle style,
) => _stateBox(
  context,
  checked,
  content,
  checked ? Icons.check_box : Icons.check_box_outline_blank,
);

/// The `GptMarkdown.radioOptionBuilder` twin of [readOnlyTaskBox]
/// (`- ( ) option`, `(x) chosen`).
Widget readOnlyRadioOption(
  BuildContext context,
  bool selected,
  Widget content,
  CheckboxStyle style,
) => _stateBox(
  context,
  selected,
  content,
  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
);

Widget _stateBox(BuildContext context, bool on, Widget content, IconData icon) {
  final scheme = Theme.of(context).colorScheme;
  return MergeSemantics(
    child: Semantics(
      checked: on,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 5, end: 8),
            child: ExcludeSemantics(
              // The enclosing text span already scales this; an Icon ignores
              // the text scale by default.
              child: Icon(
                icon,
                size: 20,
                color: on ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(child: content),
        ],
      ),
    ),
  );
}
