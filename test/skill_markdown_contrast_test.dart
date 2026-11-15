import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/widgets/skill_markdown_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/screenshot_recorder.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// The colour a run of [text] is painted in, found by walking the spans of the
/// [RichText] that holds it.
Color _inkOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(text),
    ),
  );
  Color? found;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is TextSpan) {
      if (span.text != null && span.text!.contains(text)) found = style.color;
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  visit(
    rich.text,
    DefaultTextStyle.of(tester.element(find.byWidget(rich))).style,
  );
  return found!;
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('skill markdown headings are readable in $mode', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('skill-markdown-$mode');
      await shots.start(tester, const Size(390, 500));
      final theme = dark ? buildHermesDarkTheme() : buildHermesLightTheme();
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SkillMarkdownPanel(
                  text: '# Web scraper\n\nFetch pages.\n\n## When to use it\n\nOften.',
                ),
              ),
            ),
          ),
        ),
      );
      await shots.capture(tester, 'headings');
      final background = theme.scaffoldBackgroundColor;
      for (final heading in ['Web scraper', 'When to use it']) {
        final ink = _inkOf(tester, heading);
        expect(
          _contrast(ink, background),
          greaterThanOrEqualTo(4.5),
          reason: '$heading: $ink on $background',
        );
      }
    });
  }
}
