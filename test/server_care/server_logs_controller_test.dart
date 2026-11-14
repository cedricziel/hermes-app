import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/care_result.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/server_logs_controller.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late ServerLogsController controller;
  var unsupported = 0;
  var covered = false;

  late RecordingTracer tracer;
  late RecordedEvents events;

  ServerLogsController build({String? profile = 'default'}) =>
      ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: profile,
        telemetry: ConnectionTelemetry(
          events: (name, [attributes = const {}]) => events(name, attributes),
          tracer: tracer,
          serverAttributes: const {'hermes.version': '0.22.2'},
        ),
        covered: () => covered,
        onUnsupported: () => unsupported++,
      );

  setUp(() {
    unsupported = 0;
    covered = false;
    tracer = RecordingTracer();
    events = RecordedEvents();
    server = FakeHermesServer()
      ..on('GET', '/api/logs', {'file': 'errors', 'lines': logsErrors});
    controller = build();
  });

  tearDown(() => controller.dispose());

  List<Map<String, dynamic>> reads() => server
      .requestsTo('GET', '/api/logs')
      .map((r) => r.queryParameters)
      .toList();

  test('reads the errors file, 200 lines, for the explicit profile', () async {
    await controller.load();
    expect(reads().single, {
      'file': 'errors',
      'lines': 200,
      'profile': 'default',
    });
    expect(controller.loading, isFalse);
    expect(controller.failure, isNull);
  });

  test(
    'entries are newest first and a traceback stays with its entry',
    () async {
      await controller.load();
      final entries = controller.entries;
      expect(entries.map((e) => e.level?.name), ['warning', 'error']);
      expect(entries.last.continuation, hasLength(3));
    },
  );

  test('nothing is read without a profile', () async {
    controller.dispose();
    controller = build(profile: null);
    await controller.load();
    expect(reads(), isEmpty);
    controller.setProfile('work');
    await pumpEventQueue();
    expect(reads().single['profile'], 'work');
  });

  test('a file or level change reads again with them and 200 lines', () async {
    await controller.load();
    controller.setFile(CareLogFile.agent);
    await pumpEventQueue();
    controller.setLevel(LogLevelFilter.warnings);
    await pumpEventQueue();
    expect(reads().last, {
      'file': 'agent',
      'level': 'WARNING',
      'lines': 200,
      'profile': 'default',
    });
    controller.setLevel(LogLevelFilter.errors);
    await pumpEventQueue();
    expect(reads().last['level'], 'ERROR');
    controller.setLevel(LogLevelFilter.all);
    await pumpEventQueue();
    expect(reads().last.containsKey('level'), isFalse);
  });

  test('Show older asks for 500 lines and keeps the filters', () async {
    server.on('GET', '/api/logs', {
      'lines': [
        for (var i = 0; i < 200; i++)
          '2026-11-14 09:12:03,114 INFO a.b: line $i',
      ],
    });
    controller.setFile(CareLogFile.gateway);
    await pumpEventQueue();
    expect(controller.canShowOlder, isTrue);
    await controller.showOlder();
    expect(reads().last, {
      'file': 'gateway',
      'lines': 500,
      'profile': 'default',
    });
    expect(controller.canShowOlder, isFalse);
    // A change of filter starts at 200 again.
    controller.setFile(CareLogFile.agent);
    await pumpEventQueue();
    expect(reads().last['lines'], 200);
  });

  test('a short answer offers no older lines', () async {
    await controller.load();
    expect(controller.canShowOlder, isFalse);
  });

  group('search', () {
    test('is sent once, 400 ms after typing stops', () {
      fakeAsync((async) {
        controller.setSearch('t');
        async.elapse(const Duration(milliseconds: 300));
        controller.setSearch('time');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
        expect(reads(), isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(reads().single['search'], 'time');
        expect(reads(), hasLength(1));
      });
    });

    test('an empty search is not sent', () async {
      controller.dispose();
      controller = ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: 'default',
        debounce: Duration.zero,
      );
      controller.setSearch('   ');
      await pumpEventQueue();
      expect(reads().single.containsKey('search'), isFalse);
    });

    test('only the latest answer is kept', () async {
      final slow = Completer<void>();
      server.onRequest('GET', '/api/logs', (request) async {
        if (request.queryParameters['search'] == 'old') await slow.future;
        return (
          status: 200,
          body: {
            'lines': [
              '2026-11-14 09:12:03,114 INFO a.b: ${request.queryParameters['search']}',
            ],
          },
        );
      });
      controller.dispose();
      controller = ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: 'default',
        debounce: Duration.zero,
      );
      controller.setSearch('old');
      await pumpEventQueue();
      controller.setSearch('new');
      await pumpEventQueue();
      slow.complete();
      await pumpEventQueue();
      expect(controller.entries.single.message, 'new');
    });

    test('clearing the filters reads the plain file', () async {
      controller.dispose();
      controller = ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: 'default',
        debounce: Duration.zero,
      );
      controller.setLevel(LogLevelFilter.errors);
      controller.setSearch('x');
      await pumpEventQueue();
      expect(controller.filtered, isTrue);
      controller.clearFilters();
      await pumpEventQueue();
      expect(controller.filtered, isFalse);
      expect(reads().last.containsKey('level'), isFalse);
      expect(reads().last.containsKey('search'), isFalse);
    });
  });

  test(
    'a profile switch drops the lines and a late answer for the old one',
    () async {
      final slow = Completer<void>();
      server.onRequest('GET', '/api/logs', (request) async {
        if (request.queryParameters['profile'] == 'default') {
          await slow.future;
          return (status: 200, body: {'lines': []});
        }
        return (status: 200, body: {'lines': logsErrors});
      });
      final first = controller.load();
      controller.setProfile('work');
      await pumpEventQueue();
      expect(controller.entries, hasLength(2));
      slow.complete();
      await first;
      await pumpEventQueue();
      expect(controller.entries, hasLength(2));
      expect(reads().last['profile'], 'work');
    },
  );

  test('empty answer, refused, offline and missing route', () async {
    server.on('GET', '/api/logs', {'lines': []});
    await controller.load();
    expect(controller.entries, isEmpty);
    expect(controller.failure, isNull);

    server.on('GET', '/api/logs', {'detail': 'bad file'}, status: 400);
    await controller.load();
    expect(controller.failure, CareFailureKind.refused);
    expect(controller.failureMessage, 'bad file');

    server.on('GET', '/api/logs', {'detail': 'Not Found'}, status: 404);
    await controller.load();
    expect(controller.unsupported, isTrue);
    expect(unsupported, 1);
  });

  test('a failed refresh drops the old lines', () async {
    await controller.load();
    server.on('GET', '/api/logs', {'detail': 'nope'}, status: 400);
    await controller.load();
    expect(controller.entries, isEmpty);
  });

  group('privacy', () {
    test('cover drops the lines and unreads nothing while covered', () async {
      await controller.load();
      covered = true;
      controller.cover();
      expect(controller.entries, isEmpty);
      await controller.load();
      expect(reads(), hasLength(1));
      controller.setFile(CareLogFile.agent);
      await pumpEventQueue();
      expect(reads(), hasLength(1));
      expect(controller.entries, isEmpty);
    });

    test('an answer that arrives while covered is dropped', () async {
      final slow = Completer<void>();
      server.onRequest('GET', '/api/logs', (_) async {
        await slow.future;
        return (status: 200, body: {'lines': logsErrors});
      });
      final read = controller.load();
      covered = true;
      controller.cover();
      slow.complete();
      await read;
      expect(controller.entries, isEmpty);
      expect(controller.loading, isFalse);
    });

    test('uncover reads again, with the chosen file', () async {
      controller.setFile(CareLogFile.gateway);
      await pumpEventQueue();
      covered = true;
      controller.cover();
      covered = false;
      controller.uncover();
      await pumpEventQueue();
      expect(reads().last['file'], 'gateway');
      expect(controller.entries, hasLength(2));
    });

    test('uncover without a cover reads nothing', () async {
      await controller.load();
      controller.uncover();
      await pumpEventQueue();
      expect(reads(), hasLength(1));
    });

    test('dispose drops the lines', () async {
      await controller.load();
      controller.dispose();
      expect(controller.entries, isEmpty);
      controller = build();
    });

    test('nothing is written to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      await controller.load();
      controller.setSearch('secret');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });
  });

  group('telemetry', () {
    test('a read is one span with only fixed attributes', () async {
      await controller.load();
      final span = tracer.spans.single;
      expect(span.name, 'server_care.logs.fetch');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'file': 'errors',
        'level': 'all',
        'filtered': false,
        'lines': '1-50',
        'outcome': 'success',
      });
      expect(span.ended, isTrue);
    });

    test('a search is only a flag, never its text', () async {
      controller.dispose();
      controller = ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: 'secret-profile',
        debounce: Duration.zero,
        telemetry: ConnectionTelemetry(tracer: tracer, events: events.call),
      );
      controller.setFile(CareLogFile.gateway);
      controller.setLevel(LogLevelFilter.errors);
      controller.setSearch('my-secret-search');
      await pumpEventQueue();
      final span = tracer.spans.last;
      expect(span.attributes['filtered'], isTrue);
      expect(span.attributes['file'], 'gateway');
      expect(span.attributes['level'], 'error');
      for (final s in tracer.spans) {
        expect(s.attributes.values.join(' '), isNot(contains('secret')));
      }
      expect(events.named('server_care.logs.fetch'), isEmpty);
    });

    test('lines are counted in buckets, tracebacks included', () async {
      for (final (count, bucket) in [
        (0, '0'),
        (1, '1-50'),
        (50, '1-50'),
        (51, '51-200'),
        (200, '51-200'),
        (201, '>200'),
      ]) {
        server.on('GET', '/api/logs', {
          'lines': [
            for (var i = 0; i < count; i++)
              '2026-11-14 09:12:03,114 INFO a.b: line $i',
          ],
        });
        await controller.load();
        expect(tracer.spans.last.attributes['lines'], bucket, reason: '$count');
      }
    });

    test('the outcome is the kind of failure, or unsupported', () async {
      server.on('GET', '/api/logs', {'detail': 'x'}, status: 400);
      await controller.load();
      expect(tracer.spans.last.attributes['outcome'], 'refused');
      expect(tracer.spans.last.attributes['lines'], '0');
      server.on('GET', '/api/logs', {'detail': 'Not Found'}, status: 404);
      await controller.load();
      expect(tracer.spans.last.attributes['outcome'], 'unsupported');
    });

    test('an answer that was replaced ends its span as obsolete', () async {
      final slow = Completer<void>();
      server.onRequest('GET', '/api/logs', (_) async {
        await slow.future;
        return (status: 200, body: {'lines': logsErrors});
      });
      final first = controller.load();
      controller.cover();
      slow.complete();
      await first;
      expect(tracer.spans.single.attributes['outcome'], 'obsolete');
      expect(tracer.spans.single.ended, isTrue);
    });

    test('a failing tracer never breaks a read', () async {
      controller.dispose();
      controller = ServerLogsController(
        repository: ServerCareRepository(server.client()),
        profile: 'default',
        telemetry: ConnectionTelemetry(tracer: ThrowingTracer()),
      );
      await controller.load();
      expect(controller.entries, hasLength(2));
    });
  });
}
