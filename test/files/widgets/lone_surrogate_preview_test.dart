import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';

import 'files_widget_harness.dart';

String _painted(WidgetTester tester) => tester
    .widgetList<SelectableText>(find.byType(SelectableText))
    .map((w) => w.textSpan?.toPlainText() ?? w.data ?? '')
    .join();

void main() {
  // Painting a string with a lone surrogate throws "string is not
  // well-formed UTF-16", which the tester reports as a failure.
  for (final text in ['head\ud800', 'head\ud800tail', '\udc00head']) {
    testWidgets('a text preview paints $text', (tester) async {
      await pumpFiles(tester, TextPreview(text: text));
      expect(tester.takeException(), isNull);
      expect(_painted(tester), contains('�'));
    });

    testWidgets('a code preview paints $text', (tester) async {
      await pumpFiles(tester, CodePreview(text: text, language: 'python'));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(_painted(tester), contains('�'));
    });
  }

  testWidgets('emoji in previews are unchanged', (tester) async {
    const emoji = 'x = "\u{1F600}"';
    await pumpFiles(tester, const TextPreview(text: emoji));
    expect(_painted(tester), emoji);
    await pumpFiles(tester, const CodePreview(text: emoji, language: 'python'));
    await tester.pump(const Duration(seconds: 1));
    expect(_painted(tester), emoji);
  });
}
