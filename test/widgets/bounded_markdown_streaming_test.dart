import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

/// The code budget of a reply that streams. Under [AppMarkdownTheme] the
/// renderer keeps its finished segments and builds only the changed tail on a
/// delta, so a block must find its place in the document, not in the order of
/// the questions of one pass.

/// Which blocks of the document on screen are coloured, in document order.
List<bool> _coloured(WidgetTester tester) => [
  for (final b in tester.widgetList<HermesCodeBlock>(
    find.byType(HermesCodeBlock),
  ))
    b.highlightCode,
];

int _colouredChars(WidgetTester tester) => tester
    .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
    .where((b) => b.highlightCode)
    .fold(0, (sum, b) => sum + b.codes.length);

Widget _app(String text, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? buildHermesLightTheme(),
  builder: (context, child) => AppThemeScopes(child: child!),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AppMarkdownTheme(child: BoundedMarkdown(text)),
    ),
  ),
);

/// The document as a reply that arrives in [pieces], one pump each.
Future<List<bool>> _streamed(
  WidgetTester tester,
  List<String> pieces, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var text = '';
  await tester.pumpWidget(_app(text, theme: theme));
  for (final piece in pieces) {
    text += piece;
    await tester.pumpWidget(_app(text, theme: theme));
  }
  return _coloured(tester);
}

/// The same document, mounted whole: every block is built in order, as on a
/// renderer that keeps nothing.
Future<List<bool>> _whole(WidgetTester tester, String text) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(_app(text));
  return _coloured(tester);
}

String _line(int i) => 'const v$i = $i + 1;' * 5;

List<String> _fence(String lang, String body, {String lead = ''}) => [
  '$lead\n\n',
  '```$lang\n',
  body,
  '\n```\n\n',
];

void main() {
  testWidgets('streamed fences of different bodies colour the first ones', (
    tester,
  ) async {
    final pieces = [
      for (var f = 0; f < 8; f++)
        ..._fence(
          'js',
          List.generate(30, (i) => _line(f * 100 + i)).join('\n'),
          lead: 'Para $f text.',
        ),
    ];
    final streamed = await _streamed(tester, pieces);
    expect(_colouredChars(tester), lessThanOrEqualTo(kHighlightMaxDocument));
    expect(streamed.first, isTrue);
    expect(streamed.last, isFalse);
    expect(streamed, await _whole(tester, pieces.join()));
  });

  testWidgets('a second fence of 6,000 characters is charged for the first', (
    tester,
  ) async {
    String block(String c) => List.filled(60, c * 99).join('\n');
    final pieces = [
      '```js\n',
      block('a'),
      '\n```\n\n',
      '```js\n',
      block('b'),
      '\n```\n\n',
    ];
    final streamed = await _streamed(tester, pieces);
    expect(streamed, [true, false]);
    expect(_colouredChars(tester), lessThanOrEqualTo(kHighlightMaxDocument));
  });

  testWidgets('a fence that grows replaces only its own charge', (
    tester,
  ) async {
    String block(String c, int lines) => List.filled(lines, c * 99).join('\n');
    final first = '```js\n${block('a', 60)}\n```\n\n';
    // 3,000 characters after the first's 6,000 fit; 4,500 do not.
    await _streamed(tester, [first, '```js\n${block('b', 30)}']);
    expect(_coloured(tester), [true, true]);
    await tester.pumpWidget(_app('$first```js\n${block('b', 45)}'));
    expect(_coloured(tester), [true, false]);
    // Back within it, the first keeps its charge and the second takes its own.
    await tester.pumpWidget(_app('$first```js\n${block('b', 31)}'));
    expect(_coloured(tester), [true, true]);
  });

  testWidgets('a rebuild after the stream leaves every decision as it was', (
    tester,
  ) async {
    final body = List.generate(30, _line).join('\n');
    final pieces = [
      for (var f = 0; f < 8; f++) ..._fence('js', body, lead: 'Para $f text.'),
    ];
    final streamed = await _streamed(tester, pieces);
    // The renderer settles its reveal a moment after the last delta, and drops
    // what it kept when the theme changes.
    await tester.pump(const Duration(seconds: 1));
    expect(_coloured(tester), streamed);
    await tester.pumpWidget(_app(pieces.join(), theme: buildHermesDarkTheme()));
    await tester.pumpAndSettle();
    expect(_coloured(tester), streamed);
  });
}
