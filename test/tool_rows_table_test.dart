import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/rows_result.dart';
import 'package:hermes_app/src/chat/widgets/code_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/tool_rows_table.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

const _header = ValueKey('rows-table-header');
ValueKey<String> _row(int i) => ValueKey('rows-table-row-$i');

List<Map<String, Object?>> _matches(int count) => [
  for (var i = 0; i < count; i++)
    {'path': 'lib/src/file_$i.dart', 'line': 1 + i * 11, 'content': 'row $i'},
];

Future<void> _pump(
  WidgetTester tester,
  ToolRowsTable table, {
  double width = 480,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: table),
        ),
      ),
    ),
  ),
);

ToolRowsTable _table(
  List<Map<String, Object?>> rows, {
  List<String>? columns,
  int moreColumns = 0,
  int? total,
  bool lowerBound = false,
  RowsUnit unit = RowsUnit.matches,
}) => ToolRowsTable(
  columns: columns ?? ['path', 'line', 'content'],
  rows: rows,
  moreColumns: moreColumns,
  total: total,
  totalIsLowerBound: lowerBound,
  unit: unit,
  summary: '${rows.length} matches',
);

Finder get _verticalList => find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Finder get _sideways => find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
);

String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('the header stays while the rows scroll', (tester) async {
    await _pump(tester, _table(_matches(50)));

    final headerAt = tester.getTopLeft(find.byKey(_header));
    final firstRowAt = tester.getTopLeft(find.byKey(_row(0)));

    await tester.drag(_verticalList, const Offset(0, -300));
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(_header)), headerAt);
    expect(find.byKey(_header), findsOneWidget);
    expect(find.byKey(_row(0)), findsNothing);
    expect(firstRowAt.dy, greaterThan(headerAt.dy));
    expect(find.text('path'), findsOneWidget);
  });

  testWidgets('a column name with a lone surrogate does not throw', (
    tester,
  ) async {
    final key = 'bad\uD800key';
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _table(
        [
          {key: 1},
        ],
        columns: [key],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(_row(0)), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(_row(0))).label,
      'Row 1 of 1, bad\uFFFDkey 1',
    );
    handle.dispose();
  });

  testWidgets('the row list never takes the route\'s primary scroll', (
    tester,
  ) async {
    final primary = ScrollController();
    addTearDown(primary.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: PrimaryScrollController(
          controller: primary,
          child: Scaffold(body: _table(_matches(50))),
        ),
      ),
    );
    expect(primary.hasClients, isFalse);
  });

  testWidgets('numbers sit at the right edge of their column', (tester) async {
    await _pump(
      tester,
      _table([
        {'path': 'a.dart', 'line': 7, 'content': 'x'},
        {'path': 'b.dart', 'line': 1234, 'content': 'y'},
      ]),
    );

    expect(
      tester.getTopRight(find.text('7')).dx,
      tester.getTopRight(find.text('1234')).dx,
    );
    expect(
      tester.getTopLeft(find.text('a.dart')).dx,
      tester.getTopLeft(find.text('b.dart')).dx,
    );
  });

  testWidgets('null is a dash read as empty, booleans are words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _table(
        [
          {'ok': true, 'note': null, 'n': 3.5},
        ],
        columns: ['ok', 'note', 'n'],
      ),
    );

    expect(find.text('true'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('3.5'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(_row(0))).label,
      contains('note empty'),
    );
    handle.dispose();
  });

  testWidgets('a screen reader gets row and column names', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _table(_matches(12)));

    expect(
      tester.getSemantics(find.byKey(_row(2))).label,
      'Row 3 of 12, path lib/src/file_2.dart, line 23, content row 2',
    );
    handle.dispose();
  });

  testWidgets('a long cell ends in an ellipsis and a cell has no line break', (
    tester,
  ) async {
    await _pump(
      tester,
      _table([
        {'path': 'a.dart', 'line': 1, 'content': 'x' * 400},
        {'path': 'b.dart', 'line': 2, 'content': 'first\nsecond'},
      ]),
    );

    expect(tester.takeException(), isNull);
    final long = tester.widget<Text>(find.text('x' * 400));
    expect(long.maxLines, 1);
    expect(long.overflow, TextOverflow.ellipsis);
    expect(find.textContaining('first<U+000A>second'), findsOneWidget);
  });

  group('fitting', () {
    testWidgets('it fits on a desktop and does not scroll sideways', (
      tester,
    ) async {
      await _pump(tester, _table(_matches(3)), width: 900);
      expect(_sideways, findsNothing);
    });

    testWidgets('it scrolls sideways on a phone when it is wider', (
      tester,
    ) async {
      final wide = [
        {for (var i = 0; i < 8; i++) 'column_$i': 'a value of some length $i'},
      ];
      await _pump(
        tester,
        _table(wide, columns: [for (var i = 0; i < 8; i++) 'column_$i']),
        width: 320,
      );
      expect(_sideways, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it holds at the largest text size', (tester) async {
      await _pump(tester, _table(_matches(5)), width: 320, textScale: 3);
      expect(tester.takeException(), isNull);
      expect(find.byKey(_row(0)), findsOneWidget);
    });

    testWidgets('columns past the eighth are counted', (tester) async {
      await _pump(tester, _table(_matches(2), moreColumns: 3));
      expect(find.text('+3 more columns'), findsOneWidget);
    });
  });

  group('paging', () {
    testWidgets('50 rows show and Show 50 more adds 50', (tester) async {
      await _pump(tester, _table(_matches(120)));

      expect(find.text('Showing 50 of 120 matches'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(_row(49)),
        500,
        scrollable: _verticalList,
      );
      expect(find.byKey(_row(49)), findsOneWidget);
      expect(find.byKey(_row(50)), findsNothing);

      await tester.tap(find.text('Show 50 more'));
      await tester.pump();
      expect(find.text('Showing 100 of 120 matches'), findsOneWidget);

      await tester.tap(find.text('Show 20 more'));
      await tester.pump();
      expect(find.textContaining('Show'), findsNothing);
      expect(find.textContaining('Showing'), findsNothing);
    });

    testWidgets('it stops at 500 and says how many there are', (tester) async {
      await _pump(tester, _table(_matches(620)));
      for (var i = 0; i < 9; i++) {
        await tester.tap(find.textContaining('Show 50 more'));
        await tester.pump();
      }
      expect(find.text('Showing the first 500 of 620'), findsOneWidget);
      expect(find.textContaining('more'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(_row(499)),
        1000,
        scrollable: _verticalList,
      );
      expect(find.byKey(_row(499)), findsOneWidget);
      expect(find.byKey(_row(500)), findsNothing);
    });

    testWidgets('a total above the rows is said, with no button', (
      tester,
    ) async {
      await _pump(tester, _table(_matches(30), total: 212));
      expect(find.text('Showing 30 of 212 matches'), findsOneWidget);
      expect(find.textContaining('Show 50'), findsNothing);
    });

    testWidgets('a lower bound stays one when the cap is reached', (
      tester,
    ) async {
      await _pump(tester, _table(_matches(620), total: 700, lowerBound: true));
      for (var i = 0; i < 9; i++) {
        await tester.tap(find.textContaining('Show 50 more'));
        await tester.pump();
      }
      expect(find.text('Showing 500 of at least 700 matches'), findsOneWidget);
    });

    testWidgets('only matches say at least at the cap', (tester) async {
      await _pump(
        tester,
        _table(
          _matches(620),
          total: 700,
          lowerBound: true,
          unit: RowsUnit.rows,
        ),
      );
      for (var i = 0; i < 9; i++) {
        await tester.tap(find.textContaining('Show 50 more'));
        await tester.pump();
      }
      expect(find.text('Showing the first 500 of 700'), findsOneWidget);
    });

    testWidgets('a lower bound is not an exact total', (tester) async {
      await _pump(tester, _table(_matches(30), total: 212, lowerBound: true));
      expect(find.text('Showing 30 of at least 212 matches'), findsOneWidget);
    });

    testWidgets('the button is a full-size target', (tester) async {
      await _pump(tester, _table(_matches(120)));
      expect(
        tester.getSize(find.byKey(const ValueKey('rows-table-more'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('Copy row', () {
    testWidgets('a long press offers it and copies the row as JSON', (
      tester,
    ) async {
      _mockClipboard(tester);
      final rows = _matches(3)..[1]['content'] = 'quote " and \\ slash';
      await _pump(tester, _table(rows));

      await tester.longPress(find.byKey(_row(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy row'));
      await tester.pumpAndSettle();

      expect(jsonDecode(_clipboard!), rows[1]);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('a secondary click offers it', (tester) async {
      _mockClipboard(tester);
      final rows = _matches(2);
      await _pump(tester, _table(rows));

      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(tester.getCenter(find.byKey(_row(0))));
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy row'));
      await tester.pumpAndSettle();

      expect(jsonDecode(_clipboard!), rows[0]);
    });

    testWidgets('it copies a key the table does not show', (tester) async {
      _mockClipboard(tester);
      final rows = [
        {'a': 1, 'hidden': 'kept'},
      ];
      await _pump(tester, _table(rows, columns: ['a'], moreColumns: 1));

      await tester.longPress(find.byKey(_row(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy row'));
      await tester.pumpAndSettle();

      expect(jsonDecode(_clipboard!), rows.single);
    });

    testWidgets('the keyboard reaches it: Tab to a row, Enter opens it', (
      tester,
    ) async {
      _mockClipboard(tester);
      final rows = _matches(2);
      await _pump(tester, _table(rows));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy row'));
      await tester.pumpAndSettle();

      expect(jsonDecode(_clipboard!), rows[0]);
    });

    testWidgets(
      'picking it after the table is gone does nothing and does not throw',
      (tester) async {
        _mockClipboard(tester);
        final shown = ValueNotifier(true);
        addTearDown(shown.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesLightTheme(),
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: shown,
                builder: (_, show, _) =>
                    show ? _table(_matches(2)) : const SizedBox(),
              ),
            ),
          ),
        );

        await tester.longPress(find.byKey(_row(0)));
        await tester.pumpAndSettle();
        shown.value = false;
        await tester.pump();
        await tester.tap(find.text('Copy row'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(_clipboard, isNull);
      },
    );

    testWidgets('a screen reader gets it as an action on the row', (
      tester,
    ) async {
      _mockClipboard(tester);
      final handle = tester.ensureSemantics();
      final rows = _matches(2);
      await _pump(tester, _table(rows));

      final node = tester.getSemantics(find.byKey(_row(1)));
      final id = node.getSemanticsData().customSemanticsActionIds!.single;
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp(r"^Row 2 of 2")),
        SemanticsAction.customAction,
        args: id,
      );
      await tester.pump();

      expect(jsonDecode(_clipboard!), rows[1]);
      handle.dispose();
    });
  });

  group('states', () {
    testWidgets('running says so and shows no rows', (tester) async {
      await _pump(
        tester,
        const ToolRowsTable(
          state: ToolRowsState.running,
          statusLabel: 'Searching…',
        ),
      );
      expect(find.text('Searching…'), findsOneWidget);
      expect(find.byKey(_header), findsNothing);
    });

    testWidgets('empty is a line, not a blank card', (tester) async {
      await _pump(tester, const ToolRowsTable(emptyLabel: 'No matches'));
      expect(find.text('No matches'), findsOneWidget);
      expect(find.byKey(_header), findsNothing);
    });

    testWidgets('a note has an icon and a word', (tester) async {
      await _pump(
        tester,
        ToolRowsTable(
          columns: const ['a'],
          rows: const [
            {'a': 1},
          ],
          notes: const [
            CodeNote(
              CodeNoteTone.warning,
              'The search stopped early.',
              detail: 'match limit',
            ),
          ],
        ),
      );
      expect(find.text('The search stopped early.'), findsOneWidget);
      expect(find.text('match limit'), findsOneWidget);
      expect(find.byType(AppIcon), findsWidgets);
    });
  });
}
