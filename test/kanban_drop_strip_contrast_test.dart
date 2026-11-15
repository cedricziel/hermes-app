import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_drop_strip.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/screenshot_recorder.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

const _task = KanbanTask(id: 't1', title: 'Card', status: 'todo');

Future<TestGesture> _dragOverStrip(
  WidgetTester tester,
  ScreenshotRecorder shots, {
  required bool dark,
}) async {
  await shots.start(tester, const Size(390, 300));
  await tester.pumpWidget(
    shots.frame(
      MaterialApp(
        theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
        home: Scaffold(
          body: Column(
            children: [
              KanbanDropStrip(onDrop: (_, _) {}),
              const Draggable<KanbanTask>(
                data: _task,
                feedback: SizedBox(width: 20, height: 20),
                child: SizedBox(width: 80, height: 40, child: Text('card')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  final g = await tester.startGesture(tester.getCenter(find.text('card')));
  await tester.pump();
  await g.moveTo(tester.getCenter(find.text('Blocked')));
  await tester.pump();
  return g;
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('hovered drop strip chip label is readable in $mode', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('kanban-drop-strip-$mode');
      final g = await _dragOverStrip(tester, shots, dark: dark);
      final chip = tester.widget<Chip>(
        find.ancestor(of: find.text('Blocked'), matching: find.byType(Chip)),
      );
      final fill = chip.backgroundColor!;
      final ink = DefaultTextStyle.of(tester.element(find.text('Blocked')))
          .style
          .color!;
      await shots.capture(tester, 'hovered');
      final ratio = _contrast(ink, fill);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$ink on $fill');
      await g.up();
    });
  }
}
