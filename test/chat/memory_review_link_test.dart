import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:provider/provider.dart';

import '../memory/memory_fixtures.dart';
import '../support/fake_hermes_server.dart';

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

  testWidgets('Memory opens on the profile it is given', (tester) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work'), profileRow(name: 'other')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/learning/graph', memoryGraph);
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: HermesRepositories(server.client()),
        child: const MaterialApp(home: MemoryDestination(profile: 'other')),
      ),
    );
    await tester.runAsync(() async => pumpEventQueue());
    await tester.pumpAndSettle();
    expect(
      server.requestsTo('GET', '/api/learning/graph').single.queryParameters,
      {'profile': 'other'},
    );
  });
}
