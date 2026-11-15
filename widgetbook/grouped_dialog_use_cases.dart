import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The dialog header (title and Done) at the sizes where it has to give way:
/// the largest text steps on a 320 pt phone.
WidgetbookNode groupedDialogNode() => WidgetbookComponent(
  name: 'Grouped dialog',
  useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (_) => fill(_dialog('Appearance and display')),
    ),
    WidgetbookUseCase(
      name: 'Long title',
      builder: (_) => fill(
        _dialog('Notifications, sounds and everything else you can change'),
      ),
    ),
    for (final scale in const [2.0, 3.1])
      WidgetbookUseCase(
        name: 'Largest text x$scale (320 wide)',
        builder: (_) => fill(
          _Scaled(
            scale: scale,
            child: SizedBox(
              width: 320,
              child: _dialog('Appearance and display'),
            ),
          ),
        ),
      ),
    // Rows win: with a long list the header keeps its one-line form and the
    // title is cut with an ellipsis (long-press or hover shows it in full).
    WidgetbookUseCase(
      name: 'One-line header, title cut (x3.1, 320 wide)',
      builder: (_) => fill(
        _Scaled(
          scale: 3.1,
          child: SizedBox(
            width: 320,
            height: 568,
            child: _rowsDialog(_longTitle, rows: 12),
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Footer, title cut (x2.0, 320 wide)',
      builder: (_) => fill(
        _Scaled(
          scale: 2.0,
          child: SizedBox(
            width: 320,
            height: 568,
            child: _rowsDialog(_longTitle, rows: 6, footer: true),
          ),
        ),
      ),
    ),
    // A keyboard leaves little room: the header stays one line, the footer
    // stays whole.
    WidgetbookUseCase(
      name: 'Tight viewport with keyboard (x3.1, 320 wide)',
      builder: (_) => fill(
        _Scaled(
          scale: 3.1,
          keyboard: 260,
          child: SizedBox(
            width: 320,
            height: 568,
            child: _rowsDialog(_longTitle, rows: 3, footer: true, fields: true),
          ),
        ),
      ),
    ),
  ],
);

const _longTitle = 'Edit Research assistant for quarterly reports';

Widget _rowsDialog(
  String title, {
  required int rows,
  bool footer = false,
  bool fields = false,
}) => GroupedDialog(
  title: title,
  actions: footer
      ? [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ]
      : null,
  children: [
    for (var i = 0; i < rows; i++)
      fields
          ? TextField(decoration: InputDecoration(hintText: 'Field $i'))
          : SizedBox(height: 44, child: Center(child: Text('Row $i'))),
  ],
);

Widget _dialog(String title) => GroupedDialog(
  title: title,
  children: const [Padding(padding: EdgeInsets.all(8), child: Text('Rows'))],
);

class _Scaled extends StatelessWidget {
  const _Scaled({required this.scale, required this.child, this.keyboard = 0});

  final double scale;
  final double keyboard;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child,
    );
  }
}
