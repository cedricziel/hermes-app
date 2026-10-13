import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';

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
    expect(rows.first.sourceLabel, 'Memory');
    expect(rows.last.sourceLabel, 'User profile');
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
}
