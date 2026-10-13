import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  Future<MemoryController> opened(FakeHermesServer server) async {
    server.on('GET', '/api/learning/graph', memoryGraph);
    server.on('GET', '/api/learning/node', memoryDetail);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    controller.bind(MemoryRepository(server.client().raw), 'work');
    await pumpEventQueue();
    await controller.open(controller.entries.first);
    controller.beginEdit();
    controller.setDraft('Updated full content');
    return controller;
  }

  test('save carries exact identity and profiles then refreshes IDs', () async {
    final server = FakeHermesServer()
      ..on('PUT', '/api/learning/node', {'ok': true});
    final controller = await opened(server);
    await controller.mutate(delete: false);
    final request = server.requestsTo('PUT', '/api/learning/node').single;
    expect(jsonBody(request), {
      'id': memoryId,
      'content': 'Updated full content',
      'profile': 'work',
    });
    expect(request.queryParameters, {'profile': 'work'});
    expect(controller.selected, isNull);
    expect(controller.draft, isNull);
    expect(server.requestsTo('GET', '/api/learning/graph'), hasLength(2));
  });

  for (final body in [
    <String, Object>{},
    {'ok': true, 'message': 1},
    {'ok': false, 'message': 'rejected'},
  ]) {
    test('mutation validates success body $body', () async {
      final server = FakeHermesServer()..on('PUT', '/api/learning/node', body);
      await expectLater(
        MemoryRepository(server.client().raw)
            .mutate(memoryId, 'work', content: 'Updated'),
        throwsA(isA<MemoryWriteFailure>()),
      );
    });
  }

  test(
    'server rejection remains confirmed failure with draft preserved',
    () async {
      final server = FakeHermesServer()
        ..on('PUT', '/api/learning/node', {
          'detail': 'Memory limit reached',
        }, status: 400);
      final controller = await opened(server);
      await controller.mutate(delete: false);
      expect(controller.mutation, MemoryMutation.failed);
      expect(controller.mutationMessage, 'Memory limit reached');
      expect(controller.draft, 'Updated full content');
    },
  );

  test('stale preflight prevents permanent deletion', () async {
    final server = FakeHermesServer();
    final controller = await opened(server);
    server.on('GET', '/api/learning/node', {
      'detail': 'memory node id is stale — refresh the graph',
    }, status: 404);
    await controller.mutate(delete: true);
    expect(controller.mutation, MemoryMutation.conflict);
    expect(server.requestsTo('DELETE', '/api/learning/node'), isEmpty);
  });

  test(
    'confirmed deletion refreshes list without retaining stale detail',
    () async {
      final server = FakeHermesServer();
      final controller = await opened(server);
      server.onRequest('DELETE', '/api/learning/node', (_) {
        server.on('GET', '/api/learning/graph', {'nodes': []});
        return (status: 200, body: {'ok': true});
      });
      await controller.mutate(delete: true);
      expect(controller.entries, isEmpty);
      expect(controller.selected, isNull);
      expect(controller.detail, isNull);
      expect(controller.draft, isNull);
    },
  );

  test(
    'lost delete response reports absent entry without inferring success',
    () async {
      final server = FakeHermesServer();
      final controller = await opened(server);
      server.onRequest('DELETE', '/api/learning/node', (request) {
        server.on('GET', '/api/learning/graph', {'nodes': []});
        server.on('GET', '/api/learning/node', memoryStaleError, status: 404);
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        );
      });
      await controller.mutate(delete: true);
      expect(controller.entries, isEmpty);
      expect(controller.mutation, MemoryMutation.uncertain);
      expect(
        controller.mutationMessage,
        contains('old entry is no longer present'),
      );
      await controller.mutate(delete: true);
      expect(server.requestsTo('DELETE', '/api/learning/node'), hasLength(1));
    },
  );

  test('conflict preserves draft without issuing writes', () async {
    final server = FakeHermesServer();
    final controller = await opened(server);
    server.on('GET', '/api/learning/node', {
      ...memoryDetail,
      'content': 'Changed elsewhere',
    });
    await controller.mutate(delete: false);
    expect(controller.mutation, MemoryMutation.conflict);
    expect(controller.draft, 'Updated full content');
    expect(server.requestsTo('PUT', '/api/learning/node'), isEmpty);
  });

  test('blank saves and duplicate pending submissions never write', () async {
    final server = FakeHermesServer();
    final controller = await opened(server);
    controller.setDraft('  ');
    await controller.mutate(delete: false);
    expect(server.requestsTo('PUT', '/api/learning/node'), isEmpty);
    controller.setDraft('Updated full content');
    final pending = Completer<FakeResponse>();
    server.onRequest('PUT', '/api/learning/node', (_) => pending.future);
    final saving = controller.mutate(delete: false);
    await pumpEventQueue();
    await controller.mutate(delete: false);
    expect(server.requestsTo('PUT', '/api/learning/node'), hasLength(1));
    pending.complete((status: 200, body: {'ok': true}));
    await saving;
  });

  test('lost response remains uncertain without repeating writes', () async {
    final server = FakeHermesServer();
    final controller = await opened(server);
    server.onRequest(
      'PUT',
      '/api/learning/node',
      (request) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await controller.mutate(delete: false);
    expect(controller.mutation, MemoryMutation.uncertain);
    expect(controller.draft, 'Updated full content');
    await controller.reconcile();
    await controller.mutate(delete: false);
    expect(controller.mutation, MemoryMutation.uncertain);
    expect(server.requestsTo('PUT', '/api/learning/node'), hasLength(1));
  });

  test(
    'retiring an uncertain scope during reconciliation never reads it',
    () async {
      final server = FakeHermesServer();
      final controller = await opened(server);
      server.onRequest(
        'PUT',
        '/api/learning/node',
        (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await controller.mutate(delete: false);
      expect(controller.mutation, MemoryMutation.uncertain);
      server.requests.clear();
      controller.addListener(() {
        if (controller.loading) controller.bind(null, null);
      });
      await controller.reconcile();
      expect(server.requestsTo('GET', '/api/learning/graph'), isEmpty);
      expect(server.requestsTo('GET', '/api/learning/node'), isEmpty);
      expect(controller.draft, isNull);
    },
  );

  test(
    'scope switch clears drafts and rejects late mutation completion',
    () async {
      final server = FakeHermesServer();
      final controller = await opened(server);
      final pending = Completer<FakeResponse>();
      server.onRequest('PUT', '/api/learning/node', (_) => pending.future);
      final saving = controller.mutate(delete: false);
      await pumpEventQueue();
      controller.bind(null, null);
      pending.complete((status: 200, body: {'ok': true}));
      await saving;
      expect(controller.draft, isNull);
      expect(controller.detail, isNull);
      expect(controller.mutation, MemoryMutation.idle);
    },
  );

  test('deletion carries exact identity and requires valid success', () async {
    final server = FakeHermesServer()
      ..on('DELETE', '/api/learning/node', {
        'ok': false,
        'message': 'rejected',
      });
    final controller = await opened(server);
    await controller.mutate(delete: true);
    final request = server.requestsTo('DELETE', '/api/learning/node').single;
    expect(jsonBody(request), {'id': memoryId, 'profile': 'work'});
    expect(request.queryParameters, {'profile': 'work'});
    expect(controller.mutation, MemoryMutation.failed);
    expect(controller.draft, 'Updated full content');
  });
}
