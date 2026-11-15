import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/output_lines_tile.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  const lines = ['first line', 'second line'];

  testWidgets('is closed by default and opens on tap', (tester) async {
    await tester.pumpWidget(
      _host(const OutputLinesTile(label: 'Show output', lines: lines)),
    );
    expect(find.text('Show output'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('Show output'));
    await tester.pumpAndSettle();
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, 'first line\nsecond line');
    expect(text.style!.fontFamily, 'monospace');
  });

  testWidgets('initiallyOpen shows the lines at once', (tester) async {
    await tester.pumpWidget(
      _host(
        const OutputLinesTile(
          label: 'Show output',
          lines: lines,
          initiallyOpen: true,
        ),
      ),
    );
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('long lines and the largest text do not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OutputLinesTile(
          label: 'Show output',
          lines: [List.filled(40, 'verylongword').join(' ')],
          initiallyOpen: true,
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty lines open to an empty box', (tester) async {
    await tester.pumpWidget(
      _host(
        const OutputLinesTile(
          label: 'Show output',
          lines: [],
          initiallyOpen: true,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  group('curator options', () {
    testWidgets('selectable false draws plain text', (tester) async {
      await tester.pumpWidget(
        _host(
          const OutputLinesTile(
            label: 'Show output',
            lines: lines,
            initiallyOpen: true,
            selectable: false,
          ),
        ),
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('first line\nsecond line'), findsOneWidget);
    });

    testWidgets('keeps the last lines and counts the earlier ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          OutputLinesTile(
            label: 'Show output',
            lines: [for (var i = 1; i <= 35; i++) 'line $i'],
            initiallyOpen: true,
            selectable: false,
            maxLines: 30,
            earlierLines: 2,
            earlierLabel: (n) => '$n earlier lines not shown',
          ),
        ),
      );
      expect(find.textContaining('7 earlier lines not shown'), findsOneWidget);
      expect(find.textContaining('line 5\n'), findsNothing);
      expect(find.textContaining('line 6\n'), findsOneWidget);
    });

    testWidgets('a footnote sits under the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const OutputLinesTile(
            label: 'Show output',
            lines: lines,
            initiallyOpen: true,
            footnote: 'One log for every profile.',
          ),
        ),
      );
      expect(find.text('One log for every profile.'), findsOneWidget);
    });

    testWidgets('blank mode holds the note and no lines', (tester) async {
      await tester.pumpWidget(
        _host(
          const OutputLinesTile(
            label: 'Show output',
            lines: lines,
            initiallyOpen: true,
            blank: true,
            blankNote: 'Hidden while locked',
          ),
        ),
      );
      expect(find.text('Hidden while locked'), findsOneWidget);
      expect(find.textContaining('first line'), findsNothing);
    });

    testWidgets('a tall box is capped at 40 percent of the window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          OutputLinesTile(
            label: 'Show output',
            lines: [for (var i = 1; i <= 200; i++) 'line $i'],
            initiallyOpen: true,
            selectable: false,
          ),
        ),
      );
      final box = tester.getSize(find.byType(SingleChildScrollView).last);
      expect(box.height, lessThanOrEqualTo(200));
    });

    testWidgets('semanticsLabel names the tile', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const OutputLinesTile(
            label: 'Show output',
            lines: lines,
            semanticsLabel: 'Show output, 2 lines',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Show output, 2 lines')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
