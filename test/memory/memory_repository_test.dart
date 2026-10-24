import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late MemoryRepository repository;
  setUp(() {
    server = FakeHermesServer();
    repository = MemoryRepository(server.client().raw);
  });

  test('reads memory nodes with explicit profile and filters skills', () async {
    server.on('GET', '/api/learning/graph', memoryGraph);
    final rows = await repository.load('private-profile');
    expect(rows.map((entry) => entry.id), [memoryId, 'memory:profile:1:other']);
    expect(rows.map((entry) => entry.text), ['Long memory', 'User preference']);
    expect(rows.map((entry) => entry.tab), [
      MemoryTab.agentNotes,
      MemoryTab.aboutYou,
    ]);
    expect(server.requests.single.queryParameters, {
      'profile': 'private-profile',
    });
  });

  test('detail preserves full text and exact identity', () async {
    server.on('GET', '/api/learning/node', memoryDetail);
    final detail = await repository.detail(memoryId, 'private-profile');
    expect(detail.content, fullMemory);
    expect(server.requests.single.queryParameters, {
      'profile': 'private-profile',
      'id': memoryId,
    });
  });

  test('malformed memory rows fail rather than appear empty', () async {
    server.on('GET', '/api/learning/graph', {
      'nodes': [
        {'kind': 'memory'},
      ],
    });
    await expectLater(
      repository.load('work'),
      throwsA(MemoryFailure.malformed),
    );
  });

  test('wrong detail identity is rejected', () async {
    server.on('GET', '/api/learning/node', {...memoryDetail, 'id': 'other'});
    await expectLater(
      repository.detail(memoryId, 'work'),
      throwsA(MemoryFailure.malformed),
    );
  });

  test('missing graph route differs from missing profile', () async {
    server.on('GET', '/api/learning/graph', {
      'detail': 'Not Found',
    }, status: 404);
    await expectLater(
      repository.load('work'),
      throwsA(MemoryFailure.unsupported),
    );
    server.on('GET', '/api/learning/graph', {
      'detail': "Profile 'work' does not exist.",
    }, status: 404);
    await expectLater(
      repository.load('work'),
      throwsA(MemoryFailure.profileUnavailable),
    );
  });

  test('stale detail is recoverable missing state', () async {
    server.on('GET', '/api/learning/node', {
      'detail': 'memory node id is stale — refresh the graph',
    }, status: 404);
    await expectLater(
      repository.detail(memoryId, 'work'),
      throwsA(MemoryFailure.missing),
    );
  });

  test('authentication and transient failures remain distinct', () async {
    server.on('GET', '/api/learning/graph', {}, status: 401);
    await expectLater(
      repository.load('work'),
      throwsA(MemoryFailure.unauthorized),
    );
    server.on('GET', '/api/learning/graph', {}, status: 500);
    await expectLater(
      repository.load('work'),
      throwsA(MemoryFailure.transport),
    );
  });

  group('entry text', () {
    Map<String, Object?> graph(List<(String, String)> entries) => {
      'nodes': [
        for (final (i, (source, text)) in entries.indexed)
          {
            'id': 'memory:$source:$i:digest',
            'kind': 'memory',
            'label': text.split('\n').first,
            'memorySource': source,
          },
      ],
      'memory': [
        for (final (source, text) in entries) memoryCard(source, text),
      ],
    };

    test('comes from the card without a detail request', () async {
      server.on(
        'GET',
        '/api/learning/graph',
        graph([('profile', 'Metric units')]),
      );
      final rows = await repository.load('work');
      expect(rows.single.text, 'Metric units');
      expect(rows.single.truncated, isFalse);
      expect(server.requestsTo('GET', '/api/learning/node'), isEmpty);
    });

    test('a body of 1200 characters is completed from the detail', () async {
      final text = 'x' * 1500;
      server
        ..on('GET', '/api/learning/graph', graph([('memory', text)]))
        ..on('GET', '/api/learning/node', {
          ...memoryDetail,
          'id': 'memory:memory:0:digest',
          'content': text,
        });
      final rows = await repository.load('work');
      expect(rows.single.text, text);
      expect(rows.single.truncated, isFalse);
      expect(server.requestsTo('GET', '/api/learning/node'), hasLength(1));
    });

    test('a body of 1199 characters is complete', () async {
      server.on('GET', '/api/learning/graph', graph([('memory', 'x' * 1199)]));
      final rows = await repository.load('work');
      expect(rows.single.text, hasLength(1199));
      expect(server.requestsTo('GET', '/api/learning/node'), isEmpty);
    });

    test('a node without a matching card is read from the detail', () async {
      server
        ..on('GET', '/api/learning/graph', {
          ...graph([('memory', 'Short')]),
          'memory': [],
        })
        ..on('GET', '/api/learning/node', {
          ...memoryDetail,
          'id': 'memory:memory:0:digest',
          'content': 'Short and complete',
        });
      final rows = await repository.load('work');
      expect(rows.single.text, 'Short and complete');
    });

    test('a failing detail marks the entry as cut short', () async {
      final text = 'x' * 1500;
      server
        ..on('GET', '/api/learning/graph', graph([('memory', text)]))
        ..on('GET', '/api/learning/node', {}, status: 500);
      final rows = await repository.load('work');
      expect(rows.single.text, hasLength(1200));
      expect(rows.single.truncated, isTrue);
    });
  });

  group('limits', () {
    test('are read from the profile config when positive integers', () async {
      server.on(
        'GET',
        '/api/config',
        memoryConfig(memoryLimit: 3000, userLimit: 2000),
      );
      final limits = await repository.limits('work');
      expect(limits.agentNotes, 3000);
      expect(limits.aboutYou, 2000);
      expect(server.requests.single.queryParameters['profile'], 'work');
    });

    test('a missing or invalid limit stays unknown', () async {
      server.on('GET', '/api/config', {
        'memory': {'memory_char_limit': 0, 'user_char_limit': '1375'},
      });
      final limits = await repository.limits('work');
      expect(limits.agentNotes, isNull);
      expect(limits.aboutYou, isNull);
    });

    test('a failing config read is a transport failure', () async {
      server.on('GET', '/api/config', {}, status: 500);
      await expectLater(
        repository.limits('work'),
        throwsA(MemoryFailure.transport),
      );
    });
  });
}
