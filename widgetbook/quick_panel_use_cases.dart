import 'package:flutter/material.dart';
import 'package:hermes_app/src/quick_panel/widgets/shortcut_recorder_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode quickPanelNode() => WidgetbookFolder(
  name: 'Quick panel',
  children: [
    WidgetbookComponent(
      name: 'ShortcutRecorderRow',
      useCases: [
        WidgetbookUseCase(
          name: 'No shortcut',
          builder: (_) => _row(chord: null),
        ),
        WidgetbookUseCase(
          name: 'Shortcut set',
          builder: (_) => _row(chord: '⌥Space'),
        ),
        WidgetbookUseCase(
          name: 'Narrow width',
          builder: (_) => _row(chord: '⌃⌥⌘K', maxWidth: 320),
        ),
      ],
    ),
  ],
);

/// The setting only exists on a Mac.
Widget _row({required String? chord, double maxWidth = 460}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: frame(
      GroupedSection(
        children: [
          ShortcutRecorderRow(
            isSet: chord != null,
            recorder: RecorderStandIn(chord: chord),
          ),
        ],
      ),
      maxWidth: maxWidth,
    ),
  ),
);

/// Looks like the native recorder (a search field with the chord, or its
/// placeholder), which only exists in the Mac app.
class RecorderStandIn extends StatelessWidget {
  const RecorderStandIn({super.key, required this.chord});

  final String? chord;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          chord ?? 'Record Shortcut',
          style: TextStyle(
            fontSize: 12,
            color: chord == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
