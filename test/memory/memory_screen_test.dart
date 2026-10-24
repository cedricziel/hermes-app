import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/memory_settings_controller.dart';
import 'package:hermes_app/src/memory/memory_settings_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  Future<MemoryController> pumped(WidgetTester tester) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', {
        ...memoryDetail,
        'id': 'memory:profile:1:other',
      })
      ..on(
        'GET',
        '/api/config',
        memoryConfig(memoryLimit: 2200, userLimit: 1375),
      );
    final controller = MemoryController();
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
    });
    await tester.pumpWidget(
      MaterialApp(home: MemoryScreen(controller: controller)),
    );
    return controller;
  }

  testWidgets('opens on About you with the other file one tab away', (
    tester,
  ) async {
    final controller = await pumped(tester);
    expect(controller.tab, MemoryTab.aboutYou);
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Agent notes'), findsOneWidget);
    expect(find.text('User preference'), findsOneWidget);
    expect(find.text('Long memory'), findsNothing);
    expect(find.text('15 of 1,375 characters'), findsOneWidget);
    await tester.tap(find.text('Agent notes'));
    await tester.pumpAndSettle();
    expect(controller.tab, MemoryTab.agentNotes);
    expect(find.text('Long memory'), findsOneWidget);
    expect(find.text('User preference'), findsNothing);
    expect(find.text('11 of 2,200 characters'), findsOneWidget);
  });

  testWidgets('an unsaved draft is kept when the tab change is declined', (
    tester,
  ) async {
    final controller = await pumped(tester);
    await tester.runAsync(() async {
      await controller.open(controller.entriesIn(MemoryTab.aboutYou).single);
    });
    controller.beginEdit();
    controller.setDraft('Changed');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agent notes'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this memory?'), findsOneWidget);
    await tester.tap(find.text('Keep draft'));
    await tester.pumpAndSettle();
    expect(controller.tab, MemoryTab.aboutYou);
    expect(controller.draft, 'Changed');
  });

  testWidgets(
    'the Learning section shows below the entries and saves a switch',
    (tester) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/graph', memoryGraph)
        ..on('GET', '/api/config', {
          ...memoryConfig(memoryLimit: 2200, userLimit: 1375),
          ...memorySettingsConfig(writeApproval: true, interval: 5),
        })
        ..on('PUT', '/api/config', {'ok': true});
      final controller = MemoryController();
      final settings = MemorySettingsController();
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      await tester.runAsync(() async {
        controller.bind(MemoryRepository(server.client().raw), 'work');
        settings.bind(MemorySettingsRepository(server.client().raw), 'work');
        await pumpEventQueue();
        await settings.whenIdle;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryScreen(controller: controller, settings: settings),
        ),
      );
      await tester.scrollUntilVisible(find.text('Learning'), 300);
      expect(find.text('After every 5 messages'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Keep agent notes'), 100);
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      expect(settings.settings!.agentNotes, isFalse);
      final put = server.requestsTo('PUT', '/api/config').single;
      expect(put.queryParameters['profile'], 'work');
    },
  );
}
