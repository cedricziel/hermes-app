import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/middle_ellipsis.dart';

Future<String> _drawn(
  WidgetTester tester,
  String text, {
  required double width,
  MiddleTail tail = MiddleTail.balanced,
  int maxLines = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MiddleEllipsisText(text, tail: tail, maxLines: maxLines),
          ),
        ),
      ),
    ),
  );
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  const a = 'acme-lm-large-2025-0914-long-context-instruct';
  const b = 'acme-lm-large-2025-0914-long-context-preview';

  testWidgets('a balanced tail keeps the end of ids that share a prefix', (
    tester,
  ) async {
    final first = await _drawn(tester, a, width: 200);
    final second = await _drawn(tester, b, width: 200);

    expect(first, contains('…'));
    expect(first, isNot(second));
    expect(first, endsWith('instruct'));
    expect(second, endsWith('preview'));
    expect(first, startsWith('acme-'));
  });

  testWidgets('a balanced tail has at least 8 characters, and a dot is not '
      'an extension', (tester) async {
    const id = 'vendor/some-long-model-name-with-a-version-5.1';
    final balanced = await _drawn(tester, id, width: 150);
    final asFile = await _drawn(
      tester,
      id,
      width: 150,
      tail: MiddleTail.extension,
    );

    expect(balanced, contains('…'));
    expect(balanced.split('…').last.length, greaterThanOrEqualTo(8));
    // The file-name mode keeps ".1" and three characters before it.
    expect(asFile.split('…').last, 'n-5.1');
  });

  testWidgets('a text that fits stays whole, and the full text is what '
      'assistive technology reads', (tester) async {
    final handle = tester.ensureSemantics();
    expect(await _drawn(tester, 'short-id', width: 300), 'short-id');
    final cut = await _drawn(tester, a, width: 120);

    expect(cut, contains('…'));
    expect(find.bySemanticsLabel(a), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a placeholder is never split by the cut', (tester) async {
    final cut = await _drawn(
      tester,
      'evil\u202Emodel-with-a-long-name-that-needs-cutting\u202Eend',
      width: 120,
    );

    expect(
      RegExp(r'<U\+').allMatches(cut).length,
      RegExp(r'<U\+[0-9A-F]{4}>').allMatches(cut).length,
    );
  });
}
