import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';

import 'files_widget_harness.dart';

const _tasks = '# Plan\n\n- [ ] item\n- [x] done\n';

/// The ticked state of each task box, in order.
List<bool> _values(WidgetTester tester) => tester
    .widgetList<Icon>(
      find.descendant(
        of: find.byType(MarkdownPreview),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.check_box ||
                  w.icon == Icons.check_box_outline_blank),
        ),
      ),
    )
    .map((i) => i.icon == Icons.check_box)
    .toList();

void main() {
  for (final brightness in Brightness.values) {
    for (final (name, size, scale) in [
      ('phone', const Size(390, 844), 1.0),
      ('desktop', const Size(1280, 800), 1.0),
      ('largest text', const Size(390, 844), 3.0),
    ]) {
      testWidgets('task list renders, read-only ($name, ${brightness.name})', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpFiles(
          tester,
          const MarkdownPreview(text: _tasks),
          brightness: brightness,
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('item', findRichText: true), findsOneWidget);
        expect(find.textContaining('done', findRichText: true), findsOneWidget);
        expect(_values(tester), [false, true]);

        // Read-only: no control to focus or tap, and the state is announced.
        expect(find.byType(Checkbox), findsNothing);
        expect(
          tester.getSemantics(find.textContaining('item', findRichText: true)),
          isSemantics(isChecked: false, hasCheckedState: true),
        );
        expect(
          tester.getSemantics(find.textContaining('done', findRichText: true)),
          isSemantics(isChecked: true, hasCheckedState: true),
        );
        await tester.tap(find.textContaining('item', findRichText: true));
        await tester.pump();
        expect(_values(tester), [false, true]);
        handle.dispose();
      });
    }
  }
}
