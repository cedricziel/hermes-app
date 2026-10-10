import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  final calls = <String>[];

  setUp(calls.clear);

  Widget target(
    String name, {
    Widget? child,
    bool save = true,
    bool show = true,
  }) => QuickLookTarget(
    onOpen: () => calls.add('open $name'),
    onToggle: () => calls.add('toggle $name'),
    onShow: show ? () => calls.add('show $name') : null,
    onSave: save ? () => calls.add('save $name') : null,
    child:
        child ??
        SizedBox(width: 200, height: 48, child: Center(child: Text(name))),
  );

  Future<void> pump(
    WidgetTester tester,
    List<Widget> children, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> click(WidgetTester tester, Finder finder) => tester.tap(
    finder,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );

  Future<void> secondaryClick(WidgetTester tester, Finder finder) => tester.tap(
    finder,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );

  Future<void> doubleClick(WidgetTester tester, Finder finder) async {
    await click(tester, finder);
    await tester.pump(const Duration(milliseconds: 60));
    await click(tester, finder);
  }

  bool selected(WidgetTester tester, String name) => tester
      .widget<QuickLookSelectionFrame>(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(QuickLookSelectionFrame),
        ),
      )
      .selected;

  group('selecting', () {
    testWidgets('a click selects and does not open', (tester) async {
      await pump(tester, [target('a')]);
      expect(selected(tester, 'a'), isFalse);

      await click(tester, find.text('a'));
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester, 'a'), isTrue);
      expect(calls, isEmpty);
    });

    testWidgets('a double-click opens', (tester) async {
      await pump(tester, [target('a')]);

      await doubleClick(tester, find.text('a'));

      expect(calls, ['open a']);
      expect(selected(tester, 'a'), isTrue);
    });

    testWidgets('a slow second click only selects', (tester) async {
      await pump(tester, [target('a')]);

      await click(tester, find.text('a'));
      await tester.pump(const Duration(milliseconds: 500));
      await click(tester, find.text('a'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(calls, isEmpty);
      expect(selected(tester, 'a'), isTrue);
    });

    testWidgets('hovering selects nothing and Space does nothing', (
      tester,
    ) async {
      await pump(tester, [target('a')]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(find.text('a')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(selected(tester, 'a'), isFalse);
      expect(calls, isEmpty);
    });

    testWidgets('only the last one clicked is selected', (tester) async {
      await pump(tester, [target('a'), target('b')]);

      await click(tester, find.text('a'));
      await tester.pump();
      await click(tester, find.text('b'));
      await tester.pump();

      expect(selected(tester, 'a'), isFalse);
      expect(selected(tester, 'b'), isTrue);
    });

    testWidgets('a click outside clears the selection', (tester) async {
      await pump(tester, [target('a')]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.tapAt(const Offset(600, 600), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(selected(tester, 'a'), isFalse);
      expect(calls, isEmpty);
    });

    testWidgets('focus moving to a text field clears it', (tester) async {
      await pump(tester, [target('a'), const TextField()]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(selected(tester, 'a'), isFalse);
    });

    testWidgets('Tab selects it', (tester) async {
      await pump(tester, [target('a'), target('b')]);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(selected(tester, 'a'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(selected(tester, 'a'), isFalse);
      expect(selected(tester, 'b'), isTrue);
    });
  });

  group('dragging', () {
    testWidgets('a drag is not a click, nor the half of a double-click', (
      tester,
    ) async {
      await pump(tester, [target('a')]);
      final start = tester.getCenter(find.text('a'));

      // What a drag out of the app leaves in the pointer stream: moves past
      // the slop, then a release somewhere else, from the synthetic mouse up.
      Future<void> drag() async {
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(20, 0));
        await gesture.up();
      }

      await drag();
      await tester.pump(const Duration(milliseconds: 60));
      await click(tester, find.text('a'));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, isEmpty);
      expect(selected(tester, 'a'), isTrue, reason: 'dragging selects');
    });
  });

  group('keys', () {
    testWidgets('Space on the selected one toggles it once', (tester) async {
      await pump(tester, [target('a')]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

      expect(calls, ['toggle a']);
    });

    testWidgets('Space with Command held does nothing', (tester) async {
      await pump(tester, [target('a')]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);

      expect(calls, isEmpty);
    });

    testWidgets('Space is left alone when there is nothing to preview', (
      tester,
    ) async {
      await pump(tester, [
        QuickLookTarget(
          onOpen: () => calls.add('open'),
          child: const SizedBox(width: 100, height: 40, child: Text('a')),
        ),
      ]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(calls, isEmpty);
    });

    testWidgets('Space in a text field is not taken', (tester) async {
      await pump(tester, [target('a'), const TextField()]);
      await click(tester, find.text('a'));
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(calls, isEmpty);
    });

    testWidgets('Enter opens the selected one, also on the keypad', (
      tester,
    ) async {
      await pump(tester, [target('a')]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);

      expect(calls, ['open a', 'open a']);
    });

    testWidgets('Escape does nothing', (tester) async {
      await pump(tester, [target('a')]);
      await click(tester, find.text('a'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(calls, isEmpty);
      expect(selected(tester, 'a'), isTrue);
    });

    testWidgets('a button inside keeps Space for itself', (tester) async {
      await pump(tester, [
        target(
          'a',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('a'),
              TextButton(
                onPressed: () => calls.add('button'),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ]);
      Focus.of(tester.element(find.text('Save'))).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(calls, ['button']);
    });
  });

  group('inner controls', () {
    testWidgets('clicks on a button are not clicks on the target', (
      tester,
    ) async {
      await pump(tester, [
        target(
          'a',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 100, child: Text('a')),
              TextButton(
                onPressed: () => calls.add('button'),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ]);

      await click(tester, find.text('Save'));
      await tester.pump(const Duration(milliseconds: 60));
      await click(tester, find.text('Save'));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, ['button', 'button']);
    });

    testWidgets('a click on a button is not the first half of a double-click', (
      tester,
    ) async {
      await pump(tester, [
        target(
          'a',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 100, child: Text('a')),
              TextButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      ]);

      await click(tester, find.text('Save'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(
        tester.getCenter(find.text('a')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(calls, isEmpty);
    });
  });

  group('context menu', () {
    testWidgets('a secondary click selects and offers three actions', (
      tester,
    ) async {
      await pump(tester, [target('a')]);

      await secondaryClick(tester, find.text('a'));
      await tester.pumpAndSettle();

      expect(selected(tester, 'a'), isTrue);
      expect(find.text('Quick Look'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Save…'), findsOneWidget);
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(Overlay).last,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => ['Quick Look', 'Open', 'Save…'].contains(t))
          .toList();
      expect(labels, ['Quick Look', 'Open', 'Save…']);
    });

    testWidgets('Quick Look shows and keeps the selection', (tester) async {
      await pump(tester, [target('a')]);
      await secondaryClick(tester, find.text('a'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Look'));
      await tester.pumpAndSettle();

      expect(calls, ['show a']);
      expect(selected(tester, 'a'), isTrue);
    });

    testWidgets('Open and Save… run their actions', (tester) async {
      await pump(tester, [target('a')]);
      await secondaryClick(tester, find.text('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await secondaryClick(tester, find.text('a'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save…'));
      await tester.pumpAndSettle();

      expect(calls, ['open a', 'save a']);
    });

    testWidgets('an action that cannot run is disabled', (tester) async {
      await pump(tester, [target('a', save: false, show: false)]);
      await secondaryClick(tester, find.text('a'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Look'));
      await tester.tap(find.text('Save…'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('off macOS', () {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets('is its child on $platform', (tester) async {
        await pump(tester, [
          QuickLookTarget(
            onOpen: () => calls.add('open'),
            onToggle: () => calls.add('toggle'),
            child: TextButton(
              onPressed: () => calls.add('tap'),
              child: const Text('a'),
            ),
          ),
        ], platform: platform);

        expect(find.byType(QuickLookSelectionFrame), findsNothing);
        await tester.tap(find.text('a'));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);

        expect(calls, ['tap']);
      });
    }
  });
}
