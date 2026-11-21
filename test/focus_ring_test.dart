import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  setUp(resetFocusRingInput);
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
        // A 10 px radius: the ring's inner edge is at radius 12, its outer
        // edge at 14, both around the corner centre of the grown shape.
        const rect = Rect.fromLTWH(10, 10, 100, 40);
        final ring = shape.ringPath(rect);
        const centre = Offset(20, 20);
        final diagonal = Offset(-1, -1) / 1.4142135623730951;
        bool inRing(double distance) =>
            ring.contains(centre + diagonal * distance);
        expect(inRing(11.5), isFalse, reason: 'inside the inner edge (12)');
        expect(inRing(13), isTrue, reason: 'on the ring');
        expect(inRing(14.5), isFalse, reason: 'outside the outer edge (14)');
      });

      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets('a ${kind.name} press takes the ring off a focused '
            'button, and the next key puts it back', (tester) async {
          // On a desktop the highlight mode stays traditional through a mouse
          // click, so the press itself must switch the ring off.
          _strategy(FocusHighlightStrategy.alwaysTraditional);
          await _pump(tester, theme, buttons());
          nodes['filled']!.requestFocus();
          await tester.pumpAndSettle();
          expect(
            _material(tester, finders['filled']!).shape,
            isA<FocusRingBorder>(),
          );

          final gesture = await tester.startGesture(
            const Offset(2, 2),
            kind: kind,
          );
          await gesture.up();
          await tester.pumpAndSettle();
          expect(nodes['filled']!.hasFocus, isTrue, reason: 'focus is held');
          expect(
            _material(tester, finders['filled']!).shape,
            isNot(isA<FocusRingBorder>()),
            reason: 'no ring after a pointer press',
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(
            _material(tester, finders['filled']!).shape,
            isA<FocusRingBorder>(),
          );
        });
      }

      testWidgets('a button pressed with Space keeps the ring', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(tester, theme, buttons());
        nodes['filled']!.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(
          _material(tester, finders['filled']!).shape,
          isA<FocusRingBorder>(),
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      });

      testWidgets('a button focused in touch mode gets the ring once the '
          'keyboard is used', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTouch);
        await _pump(tester, theme, buttons());
        nodes['text']!.requestFocus();
        await tester.pumpAndSettle();
        expect(
          _material(tester, finders['text']!).shape,
          isNot(isA<FocusRingBorder>()),
        );

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pumpAndSettle();
        expect(
          _material(tester, finders['text']!).shape,
          isA<FocusRingBorder>(),
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
        // Opened by a pointer; the arrow keys then move focus in the menu.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Two'))).requestFocus();
        await tester.pumpAndSettle();
        expect(_ringPainter, findsOneWidget);
        final painter = _painter(tester);
        expect(painter.color, link);
        final fill = tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is FocusRingFillPainter,
              ),
            )
            .painter!;
        expect((fill as FocusRingFillPainter).color, theme.hoverColor);
        final ring = tester.getRect(_ringPainter);
        expect(ring.contains(tester.getCenter(find.text('Two'))), isTrue);
        expect(ring.contains(tester.getCenter(find.text('One'))), isFalse);
      });
    });
  }

  group('grouped row ring radius', () {
    for (final (platform, section) in [
      (TargetPlatform.android, 14.0),
      (TargetPlatform.iOS, 12.0),
      (TargetPlatform.macOS, 10.0),
    ]) {
      testWidgets('follows the section radius ($section) minus the inset on '
          '$platform', (tester) async {
        _strategy(FocusHighlightStrategy.alwaysTraditional);
        await _pump(
          tester,
          buildHermesLightTheme(platform: platform),
          GroupedRow(title: 'Setting', onTap: () {}),
        );
        expect(
          GroupedMetrics.of(tester.element(find.text('Setting'))).radius,
          section,
        );
        Focus.of(tester.element(find.text('Setting'))).requestFocus();
        await tester.pumpAndSettle();
        expect(_painter(tester).radius, section - kFocusRingOffset);
      });
    }
  });

  testWidgets('a focused text field does not rebuild its ancestors when the '
      'input changes', (tester) async {
    _strategy(FocusHighlightStrategy.alwaysTraditional);
    final node = FocusNode();
    addTearDown(node.dispose);
    var builds = 0;
    await _pump(
      tester,
      buildHermesLightTheme(),
      Builder(
        builder: (context) {
          builds++;
          return SizedBox(width: 200, child: TextField(focusNode: node));
        },
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    final before = builds;

    await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    expect(builds, before, reason: 'only a focused button is marked dirty');
  });

  testWidgets('an unfocused FocusRing is not marked dirty when the input '
      'changes', (tester) async {
    _strategy(FocusHighlightStrategy.alwaysTraditional);
    await _pump(
      tester,
      buildHermesLightTheme(),
      const FocusRing(child: SizedBox(width: 40, height: 40)),
    );
    final ring = tester.element(find.byType(FocusRing));
    expect(ring.dirty, isFalse);
    // A pointer-down flips the input; no frame has run yet.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FocusRing)),
      kind: PointerDeviceKind.mouse,
    );
    expect(ring.dirty, isFalse, reason: 'nothing it paints has changed');
    await gesture.up();
  });

  testWidgets('a mouse click that opens a dialog shows no ring on its '
      'autofocused button; the next key does', (tester) async {
    // Nothing has resolved a button style yet, as on a fresh screen.
    forgetFocusRingWatchers();
    addTearDown(forgetFocusRingWatchers);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: const Text('Sure?'),
                    actions: [
                      FilledButton(
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Confirm');
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<FilledButton>()
          ?.autofocus,
      isTrue,
      reason: 'the dialog button has the focus',
    );
    expect(_material(tester, confirm).shape, isNot(isA<FocusRingBorder>()));

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(_material(tester, confirm).shape, isA<FocusRingBorder>());
  });

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
