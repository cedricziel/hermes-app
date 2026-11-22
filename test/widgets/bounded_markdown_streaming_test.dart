import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

/// The code budget of a reply that streams under [AppMarkdownTheme]: every
/// block is asked about on every build, so the coloured characters stay within
/// the document limit after each delta.

int _colouredChars(WidgetTester tester) => tester
    .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
    .where((b) => b.highlightCode)
    .fold(0, (sum, b) => sum + b.codes.length);

Widget _app(String text) => MaterialApp(
  theme: buildHermesLightTheme(),
  builder: (context, child) => AppThemeScopes(child: child!),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AppMarkdownTheme(child: BoundedMarkdown(text)),
    ),
  ),
);

String _line(int i) => 'const v$i = $i + 1;' * 5;

void main() {
  testWidgets('a streamed reply never colours more than the document limit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var text = '';
    await tester.pumpWidget(_app(text));
    var peak = 0;
    for (var f = 0; f < 8; f++) {
      final body = List.generate(30, (i) => _line(f * 100 + i)).join('\n');
      for (final piece in ['Para $f text.\n\n', '```js\n', body, '\n```\n\n']) {
        text += piece;
        await tester.pumpWidget(_app(text));
        final chars = _colouredChars(tester);
        expect(chars, lessThanOrEqualTo(kHighlightMaxDocument));
        if (chars > peak) peak = chars;
      }
    }
    expect(peak, greaterThan(0), reason: 'the first fences are coloured');
  });
}
