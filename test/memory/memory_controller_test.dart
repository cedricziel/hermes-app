import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  test('profile change rejects a late list and clears old content', () async {
    final server = FakeHermesServer();
    final held = Completer<FakeResponse>();
    server.onRequest(
      'GET',
      '/api/learning/graph',
      (_) => held.future,
      query: {'profile': 'old'},
    );
    server.on(
      'GET',
      '/api/learning/graph',
      {'nodes': []},
      query: {'profile': 'new'},
    );
    final repository = MemoryRepository(server.client().raw);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    controller.bind(repository, 'old');
    controller.bind(repository, 'new');
    await pumpEventQueue();
    held.complete((status: 200, body: memoryGraph));
    await pumpEventQueue();
    expect(controller.entries, isEmpty);
    expect(controller.profile, 'new');
  });

  test('sign-out rejects late detail and clears memory state', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph);
    final held = Completer<FakeResponse>();
    server.onRequest('GET', '/api/learning/node', (_) => held.future);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    controller.bind(MemoryRepository(server.client().raw), 'work');
    await pumpEventQueue();
    final opening = controller.open(controller.entries.first);
    controller.bind(null, null);
    held.complete((status: 200, body: memoryDetail));
    await opening;
    expect(controller.entries, isEmpty);
    expect(controller.detail, isNull);
    expect(controller.selected, isNull);
  });

  test('return to list rejects late detail', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph);
    final held = Completer<FakeResponse>();
    server.onRequest('GET', '/api/learning/node', (_) => held.future);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    controller.bind(MemoryRepository(server.client().raw), 'work');
    await pumpEventQueue();
    final opening = controller.open(controller.entries.first);
    controller.showList();
    held.complete((status: 200, body: memoryDetail));
    await opening;
    expect(controller.detail, isNull);
    expect(controller.selected, isNull);
    expect(controller.entries, hasLength(2));
  });
}
