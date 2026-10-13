import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/navigation/workers_navigation_resolver.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesRepositories repositories;
  const target = WorkersNavigationTarget(boardSlug: 'ops');

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on('GET', '/api/plugins/kanban/boards', {
        'boards': [
          {'slug': 'ops', 'name': 'Operations'},
        ],
      })
      ..on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    repositories = HermesRepositories(server.client());
  });

  testWidgets('reconstructs workers for same board using reads only', (
    tester,
  ) async {
    final route = await tester.runAsync(
      () => resolveWorkersNavigation(target, repositories, () => true),
    );
    expect(route, isNotNull);
    await tester.pumpWidget(MaterialApp(home: const Scaffold()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(route!);
    await tester.pumpAndSettle();
    expect(find.text('No workers are running'), findsOneWidget);
    expect(server.requests.map((r) => r.method).toSet(), {'GET'});
    expect(
      server.requests
          .where((r) => r.path.endsWith('/workers/active'))
          .single
          .queryParameters['board'],
      'ops',
    );
  });

  test('removed board does not reconstruct another board', () async {
    server.on('GET', '/api/plugins/kanban/boards', {
      'boards': [
        {'slug': 'other'},
      ],
    });
    expect(
      await resolveWorkersNavigation(target, repositories, () => true),
      isNull,
    );
  });

  test('unavailable plugin does not read workers', () async {
    server.on('GET', '/api/dashboard/plugins', []);
    expect(
      await resolveWorkersNavigation(target, repositories, () => true),
      isNull,
    );
    expect(server.requests.map((r) => r.path), ['/api/dashboard/plugins']);
  });

  test('closed gate makes no availability requests', () async {
    expect(
      await resolveWorkersNavigation(target, repositories, () => false),
      isNull,
    );
    expect(server.requests, isEmpty);
  });
}
