import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  testWidgets('blank editor disables Save and deletion cancel never writes', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      await controller.open(controller.entries.first);
    });
    await tester.pumpWidget(
      MaterialApp(home: MemoryScreen(controller: controller)),
    );
    await tester.ensureVisible(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Permanently delete this memory?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.requestsTo('DELETE', '/api/learning/node'), isEmpty);
    await tester.ensureVisible(find.text('All memories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All memories'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this memory?'), findsOneWidget);
    await tester.tap(find.text('Keep draft'));
    await tester.pumpAndSettle();
    expect(controller.draft, '  ');
    await tester.ensureVisible(find.text('All memories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All memories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard and leave'));
    await tester.pumpAndSettle();
    expect(controller.detail, isNull);
    expect(controller.draft, isNull);
  });
}
