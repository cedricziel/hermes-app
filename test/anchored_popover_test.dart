import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/anchored_popover.dart';

({BoxConstraints constraints, Offset offset}) _place({
  required Size window,
  required Rect anchor,
  double width = 360,
  double maxHeight = 480,
  TextDirection textDirection = TextDirection.ltr,
}) => layoutPopover(
  window: window,
  anchor: anchor,
  width: width,
  maxHeight: maxHeight,
  gap: 6,
  preferAbove: true,
  textDirection: textDirection,
  measure: (c) => c.maxHeight,
);

void main() {
  group('layoutPopover', () {
    test('keeps top inside the window when the anchor is stale', () {
      final placed = _place(
        window: const Size(1000, 800),
        anchor: const Rect.fromLTWH(100, 1000, 80, 30),
      );
      final height = placed.constraints.maxHeight;
      expect(placed.offset.dy, greaterThanOrEqualTo(8));
      expect(placed.offset.dy + height, lessThanOrEqualTo(800 - 8));
    });

    test('keeps top at 8 when the anchor is above the window', () {
      final placed = _place(
        window: const Size(1000, 800),
        anchor: const Rect.fromLTWH(100, -400, 80, 30),
      );
      expect(placed.offset.dy, greaterThanOrEqualTo(8));
    });

    for (final size in const [Size(10, 10), Size.zero, Size(5, 700)]) {
      test('does not throw in a $size window', () {
        final placed = _place(
          window: size,
          anchor: const Rect.fromLTWH(1, 1, 4, 4),
        );
        expect(placed.constraints.maxWidth, greaterThanOrEqualTo(0));
        expect(placed.constraints.maxHeight, greaterThanOrEqualTo(0));
        expect(placed.constraints.isNormalized, isTrue);
      });
    }

    test('right-to-left: the right edge sits on the anchor right edge', () {
      final placed = _place(
        window: const Size(1000, 800),
        anchor: const Rect.fromLTWH(500, 600, 100, 30),
        textDirection: TextDirection.rtl,
      );
      expect(placed.offset.dx, 600 - 360);
    });

    test('right-to-left stays inside the window', () {
      final placed = _place(
        window: const Size(1000, 800),
        anchor: const Rect.fromLTWH(10, 600, 100, 30),
        textDirection: TextDirection.rtl,
      );
      expect(placed.offset.dx, 8);
    });
  });

  testWidgets('a popover closes when the window size changes', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAnchoredPopover<void>(
              context,
              anchor: const Rect.fromLTWH(100, 600, 80, 30),
              semanticLabel: 'Popover',
              builder: (_) => const SizedBox(height: 100, child: Text('body')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 800);
    await tester.pumpAndSettle();

    expect(find.text('body'), findsNothing);
  });
}
