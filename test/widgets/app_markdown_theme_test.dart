import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

import '../support/markdown_contrast.dart';

const _finished = '[first](https://example.com/a)\n\nA finished paragraph.\n\n';

/// Mounts [text] as a streaming reply does: the same widgets, rebuilt with a
/// longer string. [onLink] runs each time a link's spans are built.
Widget _app(String text, {required ThemeData theme, void Function()? onLink}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: AppMarkdownTheme(
        child: BoundedMarkdown(
          text,
          linkBuilder: (_, span, _, _) {
            onLink?.call();
            return Text.rich(span);
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a delta builds the finished blocks of a reply only once', (
    tester,
  ) async {
    var linkBuilds = 0;
    final theme = buildHermesLightTheme();
    var text = _finished;
    await tester.pumpWidget(
      _app(text, theme: theme, onLink: () => linkBuilds++),
    );
    expect(linkBuilds, greaterThan(0));
    final afterMount = linkBuilds;

    for (var i = 0; i < 5; i++) {
      text += 'word$i ';
      await tester.pumpWidget(
        _app(text, theme: theme, onLink: () => linkBuilds++),
      );
    }

    expect(find.textContaining('word4', findRichText: true), findsOneWidget);
    expect(
      linkBuilds,
      afterMount,
      reason: 'the link in the finished first block was built again',
    );
  });

  testWidgets('switching to dark reaches the headings and links', (
    tester,
  ) async {
    const text = '## Heading\n\nSee [the link](https://example.com).';
    await tester.pumpWidget(_app(text, theme: buildHermesLightTheme()));
    final lightHeading = markdownInkOf(tester, 'Heading');
    final lightLink = markdownInkOf(tester, 'the link');

    await tester.pumpWidget(_app(text, theme: buildHermesDarkTheme()));
    await tester.pumpAndSettle();
    expect(markdownInkOf(tester, 'Heading'), isNot(lightHeading));
    expect(markdownInkOf(tester, 'the link'), isNot(lightLink));
    final dark = buildHermesDarkTheme();
    expect(markdownInkOf(tester, 'Heading'), dark.colorScheme.onSurface);
  });
}
