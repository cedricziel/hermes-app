import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

final _ringPainter = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

FocusRingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_ringPainter.first).foregroundPainter!
        as FocusRingPainter;

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget body) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: body)),
      ),
    );

Material _material(WidgetTester tester, Finder control) => tester.widget(
  find.descendant(of: control, matching: find.byType(Material)).first,
);

void _strategy(FocusHighlightStrategy strategy) {
  FocusManager.instance.highlightStrategy = strategy;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

void main() {
  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    final link = theme.extension<HermesChatColors>()!.link;

    group('buttons, $name', () {
      final nodes = {
        for (final k in ['filled', 'outlined', 'text', 'icon']) k: FocusNode(),
      };
      tearDownAll(() {
        for (final n in nodes.values) {
          n.dispose();
        }
      });

      Widget buttons() => Column(
        children: [
          FilledButton(
            focusNode: nodes['filled'],
            onPressed: () {},
            child: const Text('Filled'),
          ),
          OutlinedButton(
            focusNode: nodes['outlined'],
            onPressed: () {},
            child: const Text('Outlined'),
          ),
          TextButton(
            focusNode: nodes['text'],
            onPressed: () {},
            child: const Text('Text'),
          ),
          IconButton(
            focusNode: nodes['icon'],
            onPressed: () {},
            tooltip: 'Icon',
            icon: const Icon(Icons.add),
          ),
        ],
      );

      final finders = {
        'filled': find.byType(FilledButton),
        'outlined': find.byType(OutlinedButton),
        'text': find.byType(TextButton),
        'icon': find.byType(IconButton),
      };

      for (final key in finders.keys) {
        testWidgets('$key button: a 2 px ring in the link colour, 2 px out, '
            'with the keyboard', (tester) async {
          _strategy(FocusHighlightStrategy.alwaysTraditional);
          await _pump(tester, theme, buttons());
          expect(
            _material(tester, finders[key]!).shape,
            isNot(isA<FocusRingBorder>()),
          );

          nodes[key]!.requestFocus();
          await tester.pumpAndSettle();
          final shape = _material(tester, finders[key]!).shape;
          expect(shape, isA<FocusRingBorder>());
          expect((shape as FocusRingBorder).color, link);
          expect(shape.width, 2);
          expect(shape.offset, 2);

          nodes[key]!.unfocus();
          await tester.pumpAndSettle();
          expect(
            _material(tester, finders[key]!).shape,
            isNot(isA<FocusRingBorder>()),
          );
        });

        testWidgets('$key button: no ring for touch focus', (tester) async {
          _strategy(FocusHighlightStrategy.alwaysTouch);
          await _pump(tester, theme, buttons());
          nodes[key]!.requestFocus();
          await tester.pumpAndSettle();
          expect(nodes[key]!.hasFocus, isTrue);
          expect(
            _material(tester, finders[key]!).shape,
            isNot(isA<FocusRingBorder>()),
          );
        });
      }

      testWidgets('a button grows its radius by the offset', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(tester, theme, buttons());
        nodes['filled']!.requestFocus();
        await tester.pumpAndSettle();
        final shape =
            _material(tester, finders['filled']!).shape! as FocusRingBorder;
        expect(
          shape.base,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
        const rect = Rect.fromLTWH(10, 10, 100, 40);
        final ring = Path.combine(
          PathOperation.difference,
          shape.getOuterPath(rect.inflate(4)),
          shape.getOuterPath(rect.inflate(2)),
        );
        expect(ring.getBounds(), rect.inflate(4));
      });

      testWidgets('a pointer press shows no ring', (tester) async {
        await _pump(tester, theme, buttons());
        await tester.tap(finders['filled']!, kind: PointerDeviceKind.touch);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
        expect(
          _material(tester, finders['filled']!).shape,
          isNot(isA<FocusRingBorder>()),
        );
      });
    });

    group('rows and menus, $name', () {
      testWidgets('a focused grouped row draws the ring 2 px inside', (
        tester,
      ) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(tester, theme, GroupedRow(title: 'Setting', onTap: () {}));
        expect(_ringPainter, findsNothing);
        Focus.of(tester.element(find.text('Setting'))).requestFocus();
        await tester.pumpAndSettle();
        final painter = _painter(tester);
        expect(painter.color, link);
        expect(painter.width, 2);
        expect(painter.inset, 2);
        Focus.of(tester.element(find.text('Setting'))).unfocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsNothing);
      });

      testWidgets('a grouped row gets no ring for touch focus', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTouch);
        await _pump(tester, theme, GroupedRow(title: 'Setting', onTap: () {}));
        Focus.of(tester.element(find.text('Setting'))).requestFocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsNothing);
      });

      testWidgets('a focused segment draws the ring', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          theme,
          PillSegmentedControl<int>(
            value: 0,
            segments: const {0: 'One', 1: 'Two'},
            onChanged: (_) {},
          ),
        );
        expect(_ringPainter, findsNothing);
        Focus.of(tester.element(find.text('Two'))).requestFocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsOneWidget);
        expect(_painter(tester).color, link);
      });

      testWidgets('a focused menu item draws the ring and the hover fill; '
          'only that item', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          theme,
          AdaptivePopupMenuButton<int>(
            tooltip: 'Menu',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('One')),
              PopupMenuItem(value: 2, child: Text('Two')),
            ],
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Two'))).requestFocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsOneWidget);
        final painter = _painter(tester);
        expect(painter.color, link);
        expect(painter.fill, theme.hoverColor);
        final ring = tester.getRect(_ringPainter);
        expect(ring.contains(tester.getCenter(find.text('Two'))), isTrue);
        expect(ring.contains(tester.getCenter(find.text('One'))), isFalse);
      });
    });
  }

  testWidgets('a text field keeps its own focus border, with no ring', (
    tester,
  ) async {
    _strategy(FocusHighlightStrategy.alwaysTraditional);
    final theme = buildHermesLightTheme();
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(
      tester,
      theme,
      SizedBox(
        width: 200,
        child: TextField(
          focusNode: node,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(_ringPainter, findsNothing);
    expect(
      theme.inputDecorationTheme.focusedBorder,
      isNot(isA<FocusRingBorder>()),
    );
    final decorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(decorator.isFocused, isTrue);
  });
}
