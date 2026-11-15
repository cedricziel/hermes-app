import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Everything here is invented.

const _python = '''def moisture(readings):
    # the mean, in percent
    return sum(readings) / len(readings)
''';

const _json = '''{
  "plot": "A",
  "moisture": 14.2,
  "valid": true,
  "readings": [14.2, 11.8, null]
}
''';

final _longLine =
    'const readings = [${List.generate(60, (i) => '${i + 10}.5').join(', ')}];';

/// A fenced block of a chat reply under the app's own `material_ui` scope, as
/// the app builds it, so the panel takes the theme's surface in both themes.
Widget _block(
  String name,
  String code, {
  bool highlight = true,
  double textScale = 1,
  double maxWidth = 560,
}) => MaterialUiThemeScope(
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: frame(
        HermesCodeBlock(
          name: name,
          codes: code,
          style: const CodeBlockStyle(),
          highlightCode: highlight,
          scalesItsOwnText: true,
        ),
        maxWidth: maxWidth,
      ),
    ),
  ),
);

WidgetbookComponent codeBlockComponent() => WidgetbookComponent(
  name: 'HermesCodeBlock',
  useCases: [
    WidgetbookUseCase(
      name: 'Python',
      builder: (_) => _block('python', _python),
    ),
    WidgetbookUseCase(name: 'JSON', builder: (_) => _block('json', _json)),
    WidgetbookUseCase(
      name: 'No language',
      builder: (_) => _block('', 'plain text, no language\nsecond line'),
    ),
    WidgetbookUseCase(
      name: 'Long line scrolls sideways',
      builder: (_) => _block('javascript', _longLine, maxWidth: 360),
    ),
    WidgetbookUseCase(
      name: 'Over the colouring budget (plain)',
      builder: (_) => _block('python', _python, highlight: false),
    ),
    WidgetbookUseCase(
      name: 'Largest text',
      builder: (_) => _block('python', _python, textScale: 3, maxWidth: 360),
    ),
  ],
);
