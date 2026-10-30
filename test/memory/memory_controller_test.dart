import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

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

  group('per file', () {
    Map<String, Object?> graphOf(List<(String, String?, String)> rows) => {
      'nodes': [
        for (final (id, source, text) in rows)
          {'id': id, 'kind': 'memory', 'label': text, 'memorySource': ?source},
      ],
      'memory': [
        for (final (_, source, text) in rows)
          memoryCard(source ?? 'memory', text),
      ],
    };

    Future<MemoryController> loaded(
      FakeHermesServer server,
      List<(String, String?, String)> rows, {
      Breadcrumbs breadcrumbs = Breadcrumbs.none,
    }) async {
      server
        ..on('GET', '/api/learning/graph', graphOf(rows))
        ..on(
          'GET',
          '/api/config',
          memoryConfig(memoryLimit: 2200, userLimit: 1375),
        );
      final controller = MemoryController(breadcrumbs: breadcrumbs);
      addTearDown(controller.dispose);
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      return controller;
    }

    test('entries are split by source and unknown ones are notes', () async {
      final controller = await loaded(FakeHermesServer(), [
        ('a', 'profile', 'Likes metric units'),
        ('b', 'memory', 'Repo uses melos'),
        ('c', null, 'No source'),
        ('d', 'profile', 'Lives in Berlin'),
      ]);
      expect(controller.tab, MemoryTab.aboutYou);
      expect(controller.entriesIn(MemoryTab.aboutYou).map((e) => e.id), [
        'a',
        'd',
      ]);
      expect(controller.entriesIn(MemoryTab.agentNotes).map((e) => e.id), [
        'b',
        'c',
      ]);
    });

    test('usage per file uses the config limits', () async {
      final controller = await loaded(FakeHermesServer(), [
        ('a', 'profile', 'a' * 10),
        ('d', 'profile', 'b' * 10),
        ('b', 'memory', 'c' * 5),
      ]);
      final about = controller.usageOf(MemoryTab.aboutYou);
      expect((about.used, about.entries, about.limit), (23, 2, 1375));
      expect(controller.usageOf(MemoryTab.agentNotes).limit, 2200);
    });

    test('limits stay unknown when the config cannot be read', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/graph', graphOf([('a', 'profile', 'Hi')]))
        ..on('GET', '/api/config', {}, status: 500);
      final controller = MemoryController();
      addTearDown(controller.dispose);
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      expect(controller.failure, isNull);
      expect(controller.entries, hasLength(1));
      expect(controller.usageOf(MemoryTab.aboutYou).limit, isNull);
    });

    test('an open entry knows its place in its file', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/node', {
          ...memoryDetail,
          'id': 'd',
          'content': 'b' * 10,
        });
      final controller = await loaded(server, [
        ('a', 'profile', 'a' * 10),
        ('b', 'memory', 'c' * 5),
        ('d', 'profile', 'b' * 10),
      ]);
      await controller.open(controller.entriesIn(MemoryTab.aboutYou).last);
      expect(controller.position, (index: 2, count: 2));
      controller.beginEdit();
      controller.setDraft('b' * 20);
      expect(controller.leftWithDraft, 1375 - 33);
    });

    test('switching tab leaves an open entry and records the tab', () async {
      final trail = BreadcrumbTrail();
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/node', {...memoryDetail, 'id': 'a'});
      final controller = await loaded(server, [
        ('a', 'profile', 'Hi'),
      ], breadcrumbs: Breadcrumbs.of(trail));
      await controller.open(controller.entries.first);
      controller.selectTab(MemoryTab.agentNotes);
      expect(controller.tab, MemoryTab.agentNotes);
      expect(controller.detail, isNull);
      final crumb = trail.recent.singleWhere((c) => c.name == 'memory.tab');
      expect(crumb.attributes, {'tab': 'agent_notes'});
    });

    test('binding another scope returns to About you', () async {
      final controller = await loaded(FakeHermesServer(), [
        ('a', 'profile', 'Hi'),
      ]);
      controller.selectTab(MemoryTab.agentNotes);
      controller.bind(null, null);
      expect(controller.tab, MemoryTab.aboutYou);
      expect(controller.usageOf(MemoryTab.aboutYou).limit, isNull);
    });
  });
}
