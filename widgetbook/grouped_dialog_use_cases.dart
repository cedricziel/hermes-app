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
  ],
);

Widget _dialog(String title) => GroupedDialog(
  title: title,
  children: const [Padding(padding: EdgeInsets.all(8), child: Text('Rows'))],
);

class _Scaled extends StatelessWidget {
  const _Scaled({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  );
}
