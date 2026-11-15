import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/output_lines_tile.dart';

Widget _host(
  Widget child, {
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: buildHermesLightTheme(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _tall({bool capHeight = true, TargetPlatform? platform}) => _host(
  OutputLinesTile(
    label: 'Show output',
    lines: [for (var i = 1; i <= 200; i++) 'line $i'],
    initiallyOpen: true,
    selectable: false,
    capHeight: capHeight,
  ),
  platform: platform ?? TargetPlatform.iOS,
);

double _boxHeight(WidgetTester tester) =>
    tester.getSize(find.byType(SingleChildScrollView).last).height;

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

    testWidgets('the earlier-lines note is its own muted, non-code line', (
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
      final note = tester.widget<Text>(find.text('7 earlier lines not shown'));
      final lines = tester.widget<Text>(find.textContaining('line 6\n'));
      expect(note.style!.fontFamily, isNot('monospace'));
      expect(lines.style!.fontFamily, 'monospace');
      expect(note.style!.color, isNot(lines.style!.color));
      expect(lines.data, isNot(contains('earlier')));
      expect(
        tester.getTopLeft(find.text('7 earlier lines not shown')).dy,
        lessThan(tester.getTopLeft(find.textContaining('line 6\n')).dy),
      );
    });

    testWidgets('blank mode leaves no note and no line text', (tester) async {
      await tester.pumpWidget(
        _host(
          OutputLinesTile(
            label: 'Show output',
            lines: [for (var i = 1; i <= 35; i++) 'line $i'],
            initiallyOpen: true,
            blank: true,
            blankNote: 'Hidden',
            maxLines: 30,
            earlierLabel: (n) => '$n earlier lines not shown',
          ),
        ),
      );
      expect(find.textContaining('earlier'), findsNothing);
      expect(find.textContaining('line 6'), findsNothing);
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

    testWidgets('the cap is 40 percent of a short window', (tester) async {
      _window(tester, const Size(600, 500));
      await tester.pumpWidget(_tall());
      expect(_boxHeight(tester), closeTo(200, 0.5));
    });

    testWidgets('the cap stops at 320 pt in a tall window', (tester) async {
      _window(tester, const Size(600, 2000));
      await tester.pumpWidget(_tall());
      expect(_boxHeight(tester), closeTo(320, 0.5));
    });

    testWidgets('a tiny window gives a tiny box', (tester) async {
      _window(tester, const Size(600, 100));
      await tester.pumpWidget(_tall());
      expect(_boxHeight(tester), closeTo(40, 0.5));
    });

    testWidgets('without capHeight the box grows with its lines', (
      tester,
    ) async {
      _window(tester, const Size(600, 500));
      await tester.pumpWidget(_tall(capHeight: false));
      expect(find.byType(Scrollbar), findsNothing);
      final text = tester.getSize(find.textContaining('line 1\n'));
      expect(text.height, greaterThan(1000));
    });

    testWidgets('the capped box shows its scrollbar on desktop only', (
      tester,
    ) async {
      _window(tester, const Size(600, 800));
      bool anyAlwaysVisible() => tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .any((s) => s.thumbVisibility == true);
      await tester.pumpWidget(_tall(platform: TargetPlatform.macOS));
      expect(anyAlwaysVisible(), isTrue);
      await tester.pumpWidget(_tall(platform: TargetPlatform.iOS));
      expect(anyAlwaysVisible(), isFalse);
    });

    testWidgets('plain lines stay unselectable under a SelectionArea', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SelectionArea(
            child: Column(
              children: const [
                Text('control'),
                OutputLinesTile(
                  label: 'Show output',
                  lines: lines,
                  initiallyOpen: true,
                  selectable: false,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        SelectionContainer.maybeOf(tester.element(find.text('control'))),
        isNotNull,
      );
      expect(
        SelectionContainer.maybeOf(
          tester.element(find.text('first line\nsecond line')),
        ),
        isNull,
      );
    });

    testWidgets('lines run left to right even in a right-to-left app', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: OutputLinesTile(
              label: 'Show output',
              lines: lines,
              initiallyOpen: true,
              selectable: false,
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('first line\nsecond line')).textDirection,
        TextDirection.ltr,
      );
    });

    test('dropped lines need a label and a cap cannot be negative', () {
      expect(
        () => OutputLinesTile(label: 'x', lines: const [], maxLines: 3),
        throwsAssertionError,
      );
      expect(
        () => OutputLinesTile(label: 'x', lines: const [], earlierLines: 2),
        throwsAssertionError,
      );
      expect(
        () => OutputLinesTile(
          label: 'x',
          lines: const [],
          maxLines: -1,
          earlierLabel: (n) => '$n',
        ),
        throwsAssertionError,
      );
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
