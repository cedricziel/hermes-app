import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/on_screen.dart';

void main() {
  final reports = <bool>[];

  setUp(reports.clear);

  Widget probe(Widget child) => OnScreen(onChanged: reports.add, child: child);

  Future<void> pumpList(
    WidgetTester tester,
    Widget child, {
    required double before,
    ScrollController? controller,
  }) => tester.pumpWidget(
    MaterialApp(
      home: ListView(
        controller: controller,
        scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
        children: [
          SizedBox(height: before),
          // A column that shrinks its children, as a group header's does.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [probe(child)],
          ),
          const SizedBox(height: 3000),
        ],
      ),
    ),
  );

  testWidgets('outside a scrollable a laid out child is on screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: probe(const SizedBox(width: 10, height: 10))),
    );
    await tester.pump();

    expect(reports, [true]);
  });

  testWidgets('a child inside the viewport is on screen, one below it is not '
      'even though the list built it', (tester) async {
    await pumpList(tester, const SizedBox(height: 50), before: 100);
    await tester.pump();
    expect(reports, [true]);

    reports.clear();
    await pumpList(tester, const SizedBox(height: 50), before: 2000);
    await tester.pump();
    expect(find.byType(OnScreen, skipOffstage: false), findsOne);
    expect(reports, [false]);
  });

  testWidgets('a child with no area counts by its top edge', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpList(
      tester,
      const SizedBox.shrink(),
      before: 100,
      controller: controller,
    );
    await tester.pump();
    expect(reports, [true]);

    controller.jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(reports, [true, false]);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(reports, [true, false, true]);
  });

  testWidgets('it reports changes only and stops with the widget', (
    tester,
  ) async {
    await pumpList(tester, const SizedBox(height: 50), before: 100);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(reports, [true]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump();
    expect(reports, [true]);
  });
}
