import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_provider.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_settings_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'memory_fixtures.dart';

void main() {
  MemorySettingsRepository repository(
    FakeHermesServer server, {
    ConnectionTelemetry telemetry = const ConnectionTelemetry(),
  }) => MemorySettingsRepository(server.client().raw, telemetry: telemetry);

  group('status', () {
    test('an empty active provider is the built-in store', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/memory', memoryStatus());
      final status = await repository(server).status('work');
      expect(status.state, MemoryProviderState.builtin);
      expect(status.name, isNull);
      expect(server.requestsTo('GET', '/api/memory').single.queryParameters, {
        'profile': 'work',
      });
    });

    test('a named provider takes its name and description', () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/memory',
          memoryStatus(
            active: 'honcho',
            providers: [
              memoryProviderRow('mem0', description: 'Other'),
              memoryProviderRow('honcho', description: 'Honcho memory'),
            ],
          ),
        );
      final status = await repository(server).status('work');
      expect(status.state, MemoryProviderState.ready);
      expect(status.name, 'honcho');
      expect(status.description, 'Honcho memory');
    });

    for (final (wire, state) in [
      ('missing', MemoryProviderState.missing),
      ('needs_config', MemoryProviderState.needsConfig),
      ('unavailable', MemoryProviderState.unavailable),
    ]) {
      test('$wire is reported', () async {
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/memory',
            memoryStatus(
              active: 'gone',
              providers: [memoryProviderRow('gone', status: wire)],
            ),
          );
        expect((await repository(server).status('work')).state, state);
      });
    }

    test('a malformed answer is unreadable', () async {
      for (final body in [
        <Object?>[],
        {'providers': <Object?>[]},
        {'active': 3, 'providers': <Object?>[]},
        {'active': '', 'providers': 'x'},
      ]) {
        final server = FakeHermesServer()..on('GET', '/api/memory', body);
        await expectLater(
          repository(server).status('work'),
          throwsA(MemoryFailure.malformed),
        );
      }
    });

    test('is traced with the kind of provider and nothing else', () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/memory',
          memoryStatus(
            active: 'private-name',
            providers: [memoryProviderRow('private-name', status: 'missing')],
          ),
        );
      final tracer = RecordingTracer();
      await repository(
        server,
        telemetry: ConnectionTelemetry(tracer: tracer),
      ).status('work');
      final span = tracer.spans.single;
      expect(span.name, 'memory.status.fetch');
      expect(span.attributes['provider_status'], 'missing');
      expect(span.attributes['outcome'], 'success');
      expect(span.attributes.toString(), isNot(contains('private-name')));
    });
  });

  group('reset', () {
    Map<String, Object?> body(FakeHermesServer server) => jsonDecode(
      server.requestsTo('POST', '/api/memory/reset').single.data as String,
    ) as Map<String, Object?>;

    for (final target in MemoryResetTarget.values) {
      test('${target.wire} sends its body and the explicit profile', () async {
        final server = FakeHermesServer()
          ..on('POST', '/api/memory/reset', {
            'ok': true,
            'deleted': ['USER.md'],
          });
        final deleted = await repository(server).reset('work', target);
        expect(deleted, 1);
        expect(body(server), {'target': target.wire});
        expect(
          server
              .requestsTo('POST', '/api/memory/reset')
              .single
              .queryParameters['profile'],
          'work',
        );
      });
    }

    test('a refusal carries the server detail', () async {
      final server = FakeHermesServer()
        ..on('POST', '/api/memory/reset', {
          'detail': 'pick a profile',
        }, status: 400);
      await expectLater(
        repository(server).reset('work', MemoryResetTarget.both),
        throwsA(
          isA<MemoryWriteFailure>()
              .having((e) => e.uncertain, 'uncertain', isFalse)
              .having((e) => e.message, 'message', 'pick a profile'),
        ),
      );
    });

    test('ok: false is a refusal', () async {
      final server = FakeHermesServer()
        ..on('POST', '/api/memory/reset', {'ok': false});
      await expectLater(
        repository(server).reset('work', MemoryResetTarget.both),
        throwsA(
          isA<MemoryWriteFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            isFalse,
          ),
        ),
      );
    });

    test('a lost answer is uncertain and is not sent again', () async {
      final server = FakeHermesServer()
        ..onRequest(
          'POST',
          '/api/memory/reset',
          (request) => throw DioException.connectionError(
            requestOptions: request,
            reason: 'closed',
          ),
        );
      await expectLater(
        repository(server).reset('work', MemoryResetTarget.both),
        throwsA(
          isA<MemoryWriteFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            isTrue,
          ),
        ),
      );
      expect(server.requestsTo('POST', '/api/memory/reset'), hasLength(1));
    });

    test('a malformed answer is uncertain', () async {
      final server = FakeHermesServer()
        ..on('POST', '/api/memory/reset', {'deleted': <Object?>[]});
      await expectLater(
        repository(server).reset('work', MemoryResetTarget.both),
        throwsA(
          isA<MemoryWriteFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            isTrue,
          ),
        ),
      );
    });

    test('is traced and logged with the target and the count only', () async {
      final server = FakeHermesServer()
        ..on('POST', '/api/memory/reset', {
          'ok': true,
          'deleted': ['MEMORY.md', 'USER.md'],
        });
      final tracer = RecordingTracer();
      final events = <String>[];
      await repository(
        server,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
      ).reset('private-profile', MemoryResetTarget.both);
      final span = tracer.spans.single;
      expect(span.name, 'memory.reset');
      expect(span.attributes['target'], 'all');
      expect(span.attributes['outcome'], 'reset');
      expect(events.single, contains('memory.reset_outcome'));
      expect(events.single, contains('target: all'));
      expect(events.single, contains('outcome: reset'));
      expect(events.single, contains('deleted: 2'));
      final exported = [span.attributes.toString(), ...events].join();
      expect(exported, isNot(contains('private-profile')));
      expect(exported, isNot(contains('USER.md')));
    });
  });
}
