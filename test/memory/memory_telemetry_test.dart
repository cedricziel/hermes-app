import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'memory_fixtures.dart';

void main() {
  test(
    'memory telemetry records fixed outcomes without content or identity',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/graph', memoryGraph)
        ..on('GET', '/api/learning/node', memoryDetail);
      final tracer = RecordingTracer();
      final events = <String>[];
      final trail = BreadcrumbTrail();
      final repository = MemoryRepository(
        server.client().raw,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          serverAttributes: const {'hermes.version': 'test'},
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
      );
      final controller = MemoryController(breadcrumbs: Breadcrumbs.of(trail));
      addTearDown(controller.dispose);
      controller.bind(repository, 'private-profile');
      await pumpEventQueue();
      await controller.open(controller.entries.first);
      server.on('GET', '/api/learning/node', {
        'detail': fullMemory,
      }, status: 500);
      await controller.open(controller.entries.first);
      final exported = [
        ...tracer.spans.map((span) => '${span.name} ${span.attributes}'),
        ...events,
        ...trail.recent.map((entry) => '${entry.name} ${entry.attributes}'),
      ].join(' ');
      expect(tracer.spans, hasLength(3));
      expect(tracer.spans.every((span) => span.ended), isTrue);
      expect(exported, contains('memory.fetch_failed'));
      expect(exported, contains('memory.open'));
      expect(exported, isNot(contains('private-profile')));
      expect(exported, isNot(contains(memoryId)));
      expect(exported, isNot(contains('Long memory')));
      expect(exported, isNot(contains('https://example.invalid')));
    },
  );

  test(
    'mutation telemetry excludes drafts, identity and backend errors',
    () async {
      final server = FakeHermesServer()
        ..on('PUT', '/api/learning/node', {
          'ok': false,
          'message': 'private server reason',
        });
      final tracer = RecordingTracer();
      final events = <String>[];
      final repository = MemoryRepository(
        server.client().raw,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
      );
      await expectLater(
        repository.mutate(memoryId, 'private-profile', content: fullMemory),
        throwsA(isA<MemoryWriteFailure>()),
      );
      final exported = [
        ...tracer.spans.map((span) => '${span.name} ${span.attributes}'),
        ...events,
      ].join(' ');
      expect(exported, contains('memory.mutation_outcome'));
      expect(exported, contains('failed'));
      expect(exported, isNot(contains('private-profile')));
      expect(exported, isNot(contains(memoryId)));
      expect(exported, isNot(contains('private server reason')));
      expect(exported, isNot(contains('https://example.invalid')));
      expect(tracer.spans.single.ended, isTrue);
      server.on('PUT', '/api/learning/node', {'ok': true});
      await MemoryRepository(
        server.client().raw,
        telemetry: ConnectionTelemetry(
          tracer: ThrowingTracer(),
          events: (_, [attributes = const {}]) => throw StateError('telemetry'),
        ),
      ).mutate(memoryId, 'private-profile', content: fullMemory);
    },
  );

  test('throwing telemetry cannot fail a memory read', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph);
    final repository = MemoryRepository(
      server.client().raw,
      telemetry: ConnectionTelemetry(
        tracer: ThrowingTracer(),
        events: (_, [attributes = const {}]) => throw StateError('telemetry'),
      ),
    );
    expect(await repository.load('private-profile'), hasLength(2));
    server.on('GET', '/api/learning/graph', {}, status: 500);
    await expectLater(
      repository.load('private-profile'),
      throwsA(MemoryFailure.transport),
    );
  });
}
