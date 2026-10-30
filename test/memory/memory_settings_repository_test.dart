import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_settings.dart';
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

  group('read', () {
    test('takes the five keys of the profile', () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/config',
          memorySettingsConfig(
            userProfile: false,
            agentNotes: false,
            writeApproval: true,
            interval: 5,
            updates: 'verbose',
          ),
        );
      final settings = await repository(server).read('work');
      expect(settings.userProfile, isFalse);
      expect(settings.agentNotes, isFalse);
      expect(settings.writeApproval, isTrue);
      expect(settings.reviewInterval, 5);
      expect(settings.updatesInChat, 'verbose');
      final request = server.requestsTo('GET', '/api/config').single;
      expect(request.queryParameters['profile'], 'work');
      expect(request.queryParameters['include_defaults'], isNot(false));
    });

    test('a missing or ill-typed key shows the server default', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/config', {
          'memory': {
            'memory_enabled': 'yes',
            'write_approval': 1,
            'nudge_interval': -3,
          },
          'display': {'memory_notifications': 4},
        });
      expect(await repository(server).read('work'), MemorySettings.defaults);
    });

    test('an answer that is not an object is unreadable', () async {
      final server = FakeHermesServer()..on('GET', '/api/config', ['no']);
      await expectLater(
        repository(server).read('work'),
        throwsA(MemoryFailure.malformed),
      );
    });

    test('a failed request is a transport failure', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/config', {'detail': 'boom'}, status: 500);
      await expectLater(
        repository(server).read('work'),
        throwsA(MemoryFailure.transport),
      );
    });
  });

  group('write', () {
    Map<String, Object?> sent(FakeHermesServer server) => jsonDecode(
      server.requestsTo('PUT', '/api/config').single.data as String,
    ) as Map<String, Object?>;

    test('sends only the changed leaf and the profile', () async {
      final server = FakeHermesServer()..on('PUT', '/api/config', {'ok': true});
      await repository(server).write('work', MemorySetting.writeApproval, true);
      expect(
        server
            .requestsTo('PUT', '/api/config')
            .single
            .queryParameters['profile'],
        'work',
      );
      expect(sent(server), {
        'config': {
          'memory': {'write_approval': true},
        },
        'profile': 'work',
      });
    });

    test('the in-chat reports go under display', () async {
      final server = FakeHermesServer()..on('PUT', '/api/config', {'ok': true});
      await repository(server)
          .write('work', MemorySetting.updatesInChat, 'verbose');
      expect(sent(server), {
        'config': {
          'display': {'memory_notifications': 'verbose'},
        },
        'profile': 'work',
      });
    });

    test('a refusal and a lost answer are told apart', () async {
      final refusing = FakeHermesServer()
        ..on('PUT', '/api/config', {'detail': 'nope'}, status: 400);
      await expectLater(
        repository(refusing).write('work', MemorySetting.agentNotes, false),
        throwsA(
          isA<MemoryWriteFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            isFalse,
          ),
        ),
      );
      final lost = FakeHermesServer()
        ..onRequest(
          'PUT',
          '/api/config',
          (request) => throw DioException.connectionError(
            requestOptions: request,
            reason: 'closed',
          ),
        );
      await expectLater(
        repository(lost).write('work', MemorySetting.agentNotes, false),
        throwsA(
          isA<MemoryWriteFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            isTrue,
          ),
        ),
      );
    });

    test('traces and logs fixed values only', () async {
      final server = FakeHermesServer()..on('PUT', '/api/config', {'ok': true});
      final tracer = RecordingTracer();
      final events = <String>[];
      await repository(
        server,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
      ).write('private-profile', MemorySetting.reviewInterval, 5);
      final span = tracer.spans.single;
      expect(span.name, 'memory.settings.write');
      expect(span.attributes['key'], 'nudge_interval');
      expect(span.attributes['outcome'], 'saved');
      expect(span.ended, isTrue);
      expect(events.single, contains('memory.setting_changed'));
      expect(events.single, contains('saved'));
      expect(
        [span.attributes.toString(), ...events].join(),
        isNot(contains('private-profile')),
      );
    });
  });

  test('a read is traced with its outcome', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/config', memorySettingsConfig());
    final tracer = RecordingTracer();
    await repository(
      server,
      telemetry: ConnectionTelemetry(tracer: tracer),
    ).read('work');
    expect(tracer.spans.single.name, 'memory.settings.fetch');
    expect(tracer.spans.single.attributes['outcome'], 'success');
  });
}
