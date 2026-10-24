import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onOpenMemory}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryActivityCard(
              reviewNotes: const ['Memory updated'],
              initiallyOpen: true,
              onOpenMemory: onOpenMemory,
            ),
          ),
        ),
      );

  testWidgets('the review section links to Memory when it can open it', (
    tester,
  ) async {
    var opened = 0;
    await pumpCard(tester, onOpenMemory: () => opened++);
    await tester.tap(find.text('Memory'));
    expect(opened, 1);
  });

  testWidgets('without a way to open it there is no link', (tester) async {
    await pumpCard(tester);
    expect(find.text('Memory'), findsNothing);
  });
}
