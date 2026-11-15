import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

Finder _richHolding(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);

/// The colour a run of [text] is painted in, found by walking the spans of the
/// [RichText] that holds it.
Color markdownInkOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(_richHolding(text));
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

/// Asserts each of [texts] reads at 4.5:1 or better against the surface of the
/// theme it is drawn under.
void expectReadableOnSurface(WidgetTester tester, List<String> texts) {
  final context = tester.element(_richHolding(texts.first));
  final surface = Theme.of(context).colorScheme.surface;
  for (final text in texts) {
    final ink = markdownInkOf(tester, text);
    expect(
      contrastRatio(ink, surface),
      greaterThanOrEqualTo(4.5),
      reason: '$text: $ink on $surface',
    );
  }
}
