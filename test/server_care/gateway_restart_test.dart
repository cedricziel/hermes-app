import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/gateway_restart.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late DateTime clock;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late GatewayRestart gateway;
  late int delays;

  Map<String, dynamic> status({
    bool running = true,
    String state = 'running',
  }) => {
    ...statusHealthy(),
    'gateway_running': running,
    'gateway_state': state,
  };

  Map<String, dynamic> action(
    String name, {
    bool running = false,
    int? exit,
    List<String> lines = const [],
  }) => {
    'name': name,
    'running': running,
    'exit_code': exit,
    'pid': 1,
    'lines': ['=== $name started 2026-11-14 09:00:00 ===', ...lines],
  };

  GatewayRestart build({ServerCareController? care, Breadcrumbs? crumbs}) =>
      GatewayRestart(
        repository: ServerCareRepository(server.client()),
        care: care,
        telemetry: ConnectionTelemetry(
          events: (name, [attributes = const {}]) => events(name, attributes),
          tracer: tracer,
          serverAttributes: const {'hermes.version': '0.22.2'},
        ),
        breadcrumbs: crumbs ?? Breadcrumbs.none,
        now: () => clock,
        delay: (d) async {
          delays++;
          clock = clock.add(d);
        },
      );

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/gateway/restart', {
        'ok': true,
        'pid': 4321,
        'name': 'gateway-restart',
      })
      ..on('POST', '/api/gateway/start', {
        'ok': true,
        'pid': 4322,
        'name': 'gateway-start',
      })
      ..on(
        'GET',
        '/api/actions/gateway-restart/status',
        action('gateway-restart', exit: 0),
      )
      ..on(
        'GET',
        '/api/actions/gateway-start/status',
        action('gateway-start', exit: 0),
      )
      ..on('GET', '/api/status', status());
    clock = DateTime(2026, 11, 14, 9);
    events = RecordedEvents();
    tracer = RecordingTracer();
    delays = 0;
    gateway = build();
  });

  tearDown(() => gateway.dispose());

  int posts(String verb) =>
      server.requestsTo('POST', '/api/gateway/$verb').length;

  test('restart: the command exits 0, the gateway runs: done', () async {
    final phases = <GatewayPhase>[];
    gateway.addListener(() => phases.add(gateway.phase));
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
    expect(gateway.action, GatewayAction.restart);
    expect(gateway.busy, isFalse);
    expect(
      phases,
      containsAllInOrder([
        GatewayPhase.starting,
        GatewayPhase.waiting,
        GatewayPhase.returning,
        GatewayPhase.done,
      ]),
    );
    expect(posts('restart'), 1);
  });

  test(
    'a child still running at 30 s is success; then the status decides',
    () async {
      server.on(
        'GET',
        '/api/actions/gateway-restart/status',
        action('gateway-restart', running: true),
      );
      var statusReads = 0;
      server.onRequest(
        'GET',
        '/api/status',
        (_) => (
          status: 200,
          body: statusReads++ == 0
              ? status(running: false, state: 'stopped')
              : status(),
        ),
      );
      await gateway.run(GatewayAction.restart, profile: 'work');
      expect(gateway.phase, GatewayPhase.done);
      final reads = server.requestsTo(
        'GET',
        '/api/actions/gateway-restart/status',
      );
      expect(reads.first.queryParameters['lines'], 40);
    },
  );

  test('a child still running with the old gateway never seen down is slow, '
      'not done', () async {
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', running: true),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.slow);
    expect(
      clock.difference(DateTime(2026, 11, 14, 9)).inSeconds,
      inInclusiveRange(90, 93),
    );
  });

  test('a child that exits 0 after the 30 s wait counts as finished', () async {
    var reads = 0;
    server.onRequest(
      'GET',
      '/api/actions/gateway-restart/status',
      (_) => (
        status: 200,
        body: action('gateway-restart', running: reads++ < 25, exit: 0),
      ),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
  });

  test(
    'a lost answer, a running child, then a non-zero exit fails the run',
    () async {
      server.onRequest('POST', '/api/gateway/restart', (r) {
        throw DioException.connectionError(
          requestOptions: r,
          reason: 'dropped',
        );
      });
      var reads = 0;
      server.onRequest(
        'GET',
        '/api/actions/gateway-restart/status',
        (_) => (
          status: 200,
          body: reads++ == 0
              ? action('gateway-restart', running: true)
              : action('gateway-restart', exit: 1, lines: ['needs root']),
        ),
      );
      await gateway.run(GatewayAction.restart, profile: 'work');
      expect(gateway.phase, GatewayPhase.failed);
      expect(gateway.failure, GatewayFailure.exited);
      expect(gateway.message, 'needs root');
      expect(posts('restart'), 1);
    },
  );

  test('a press after the outcome starts a new run', () async {
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.busy, isFalse);
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(posts('restart'), 2);
  });

  test(
    'a start with a child still running is done once the gateway runs',
    () async {
      server.on(
        'GET',
        '/api/actions/gateway-start/status',
        action('gateway-start', running: true),
      );
      await gateway.run(GatewayAction.start, profile: 'work');
      expect(gateway.phase, GatewayPhase.done);
    },
  );

  test(
    'the status is polled until the gateway runs, degraded counts',
    () async {
      var reads = 0;
      server.onRequest('GET', '/api/status', (_) {
        reads++;
        return reads < 3
            ? (status: 200, body: status(running: false, state: 'starting'))
            : (status: 200, body: status(state: 'degraded'));
      });
      await gateway.run(GatewayAction.restart, profile: 'work');
      expect(gateway.phase, GatewayPhase.done);
      expect(reads, 3);
    },
  );

  test('a non-zero exit fails with the last lines', () async {
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', exit: 1, lines: ['a', '', 'needs root']),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.failed);
    expect(gateway.failure, GatewayFailure.exited);
    expect(gateway.message, 'a\nneeds root');
    expect(gateway.busy, isFalse);
  });

  test('a gateway that is not running after 90 s is slow', () async {
    server.on('GET', '/api/status', status(running: false, state: 'stopped'));
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.slow);
    expect(
      clock.difference(DateTime(2026, 11, 14, 9)).inSeconds,
      inInclusiveRange(90, 93),
    );
    expect(posts('restart'), 1);
    expect(tracer.spans.single.attributes['outcome'], 'slow');
  });

  for (final code in [409, 500]) {
    test(
      'HTTP $code with a detail is refused with Hermes\' text, once',
      () async {
        server.on('POST', '/api/gateway/restart', {
          'detail': 'needs "sudo hermes gateway restart" on the host',
        }, status: code);
        await gateway.run(GatewayAction.restart, profile: 'work');
        expect(gateway.phase, GatewayPhase.failed);
        expect(gateway.failure, GatewayFailure.refused);
        expect(
          gateway.message,
          'needs "sudo hermes gateway restart" on the host',
        );
        expect(posts('restart'), 1);
        expect(
          server.requestsTo('GET', '/api/actions/gateway-restart/status'),
          isEmpty,
        );
      },
    );
  }

  test('a lost answer to the POST reads, never resends, and settles when the '
      'gateway was seen down and runs again', () async {
    server.onRequest('POST', '/api/gateway/restart', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'dropped');
    });
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', running: true),
    );
    var statusReads = 0;
    server.onRequest(
      'GET',
      '/api/status',
      (_) => (
        status: 200,
        body: statusReads++ == 0
            ? status(running: false, state: 'stopped')
            : status(),
      ),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(posts('restart'), 1);
    expect(
      server.requestsTo('GET', '/api/actions/gateway-restart/status'),
      isNotEmpty,
    );
    expect(server.requestsTo('GET', '/api/status'), isNotEmpty);
    expect(gateway.phase, GatewayPhase.done);
  });

  test('a lost answer with a running child is not done while the old gateway '
      'still runs', () async {
    server.onRequest('POST', '/api/gateway/restart', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'dropped');
    });
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', running: true),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(posts('restart'), 1);
    expect(gateway.phase, GatewayPhase.slow);
  });

  test('a lost restart is not done while the old gateway still runs', () async {
    server.onRequest('POST', '/api/gateway/restart', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'dropped');
    });
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', exit: 1, lines: ['old run']),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(posts('restart'), 1);
    expect(gateway.phase, GatewayPhase.slow);
  });

  test(
    'a lost restart is done once the gateway was seen down and up',
    () async {
      server.onRequest('POST', '/api/gateway/restart', (r) {
        throw DioException.connectionError(
          requestOptions: r,
          reason: 'dropped',
        );
      });
      server.on(
        'GET',
        '/api/actions/gateway-restart/status',
        action('gateway-restart', exit: 0),
      );
      var reads = 0;
      server.onRequest(
        'GET',
        '/api/status',
        (_) => (
          status: 200,
          body: reads++ == 0
              ? status(running: false, state: 'stopped')
              : status(),
        ),
      );
      await gateway.run(GatewayAction.restart, profile: 'work');
      expect(gateway.phase, GatewayPhase.done);
      expect(posts('restart'), 1);
    },
  );

  test('a bare 504 on the POST is a lost answer, not a refusal', () async {
    server.on('POST', '/api/gateway/restart', {}, status: 504);
    server.on('GET', '/api/status', status(running: false, state: 'stopped'));
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.failure, isNull);
    expect(gateway.phase, GatewayPhase.slow);
    expect(posts('restart'), 1);
  });

  test('the run remembers its profile until dismissed', () async {
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.profile, 'work');
    gateway.dismiss();
    expect(gateway.profile, isNull);
  });

  test('a lost answer that never settles ends slow, not failed', () async {
    server.onRequest('POST', '/api/gateway/restart', (r) {
      throw DioException.connectionError(requestOptions: r, reason: 'dropped');
    });
    server.on('GET', '/api/status', status(running: false, state: 'stopped'));
    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', exit: 1, lines: ['old run']),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(posts('restart'), 1);
    expect(gateway.phase, GatewayPhase.slow);
    expect(gateway.failure, isNull);
    expect(
      clock.difference(DateTime(2026, 11, 14, 9)).inSeconds,
      inInclusiveRange(90, 93),
    );
  });

  test('Try again after slow or failed sends a new POST', () async {
    server.on('GET', '/api/status', status(running: false, state: 'stopped'));
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.slow);
    server.on('GET', '/api/status', status());
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
    expect(posts('restart'), 2);

    server.on('POST', '/api/gateway/restart', {'detail': 'no'}, status: 500);
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.failed);
    server.on('POST', '/api/gateway/restart', {
      'ok': true,
      'name': 'gateway-restart',
    });
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
    expect(posts('restart'), 4);
  });

  test('a second run while busy joins and sends one POST', () async {
    final gate = Completer<void>();
    server.onRequest('POST', '/api/gateway/restart', (_) async {
      await gate.future;
      return (status: 200, body: {'ok': true, 'name': 'gateway-restart'});
    });
    final first = gateway.run(GatewayAction.restart, profile: 'work');
    await pumpEventQueue();
    expect(gateway.busy, isTrue);
    final second = gateway.run(GatewayAction.restart, profile: 'work');
    gate.complete();
    await Future.wait([first, second]);
    expect(gateway.phase, GatewayPhase.done);
    expect(posts('restart'), 1);
  });

  test('start uses the start routes', () async {
    await gateway.run(GatewayAction.start, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
    expect(gateway.action, GatewayAction.start);
    expect(posts('start'), 1);
    expect(posts('restart'), 0);
    expect(
      server.requestsTo('GET', '/api/actions/gateway-start/status'),
      isNotEmpty,
    );
    expect(
      server.requestsTo('GET', '/api/actions/gateway-restart/status'),
      isEmpty,
    );
  });

  test(
    'profile is sent on the POST and the status read, not on the action',
    () async {
      await gateway.run(GatewayAction.restart, profile: 'work');
      expect(
        server
            .requestsTo('POST', '/api/gateway/restart')
            .single
            .queryParameters['profile'],
        'work',
      );
      for (final r in server.requestsTo('GET', '/api/status')) {
        expect(r.queryParameters['profile'], 'work');
      }
      for (final r in server.requestsTo(
        'GET',
        '/api/actions/gateway-restart/status',
      )) {
        expect(r.queryParameters.containsKey('profile'), isFalse);
      }
    },
  );

  test('care follows busy and refreshes once when a run ends', () async {
    final care = ServerCareController(
      repository: ServerCareRepository(server.client()),
      profile: 'work',
      now: () => clock,
    );
    addTearDown(care.dispose);
    gateway.dispose();
    gateway = build(care: care);
    var statusReads = 0;
    server.onRequest('GET', '/api/status', (_) {
      statusReads++;
      return (status: 200, body: status());
    });
    final busyStates = <bool>[];
    gateway.addListener(() => busyStates.add(gateway.busy));
    await gateway.run(GatewayAction.restart, profile: 'work');
    await pumpEventQueue();
    expect(busyStates.first, isTrue);
    expect(busyStates.last, isFalse);
    // One poll that found it running, plus the single refresh after the run.
    expect(statusReads, 2);
    expect(care.status, isNotNull);
  });

  test('telemetry carries only fixed names', () async {
    final crumbs = <(String, Map<String, Object>)>[];
    gateway.dispose();
    gateway = build(
      crumbs: Breadcrumbs.of(_Trail((n, a) => crumbs.add((n, a)))),
    );
    gateway.confirmed(GatewayAction.restart);
    expect(crumbs.single.$1, 'server_care.gateway.confirmed');
    expect(crumbs.single.$2, {'verb': 'restart'});

    server.on(
      'GET',
      '/api/actions/gateway-restart/status',
      action('gateway-restart', exit: 1, lines: ['secret-line']),
    );
    await gateway.run(GatewayAction.restart, profile: 'private-profile');
    final span = tracer.spans.single;
    expect(span.name, 'server_care.gateway');
    expect(span.attributes, {
      'hermes.version': '0.22.2',
      'verb': 'restart',
      'shared': false,
      'outcome': 'failed',
      'duration': '0-10s',
    });
    expect(span.ended, isTrue);
    expect(events.named('server_care.gateway_finished'), [
      {'verb': 'restart', 'outcome': 'failed'},
    ]);

    server.on('POST', '/api/gateway/start', {
      'detail': 'secret detail',
    }, status: 409);
    await gateway.run(GatewayAction.start, profile: 'private-profile');
    expect(tracer.spans.last.attributes['outcome'], 'refused');
    expect(tracer.spans.last.attributes['verb'], 'start');
    expect(tracer.spans.last.attributes.toString(), isNot(contains('secret')));
  });

  test('a broken tracer does not break a run', () async {
    gateway.dispose();
    gateway = GatewayRestart(
      repository: ServerCareRepository(server.client()),
      telemetry: ConnectionTelemetry(tracer: ThrowingTracer()),
      now: () => clock,
      delay: (d) async => clock = clock.add(d),
    );
    await gateway.run(GatewayAction.restart, profile: 'work');
    expect(gateway.phase, GatewayPhase.done);
  });

  test('dismiss goes back to idle', () async {
    server.on('POST', '/api/gateway/restart', {'detail': 'no'}, status: 500);
    await gateway.run(GatewayAction.restart, profile: 'work');
    gateway.dismiss();
    expect(gateway.phase, GatewayPhase.idle);
    expect(gateway.action, isNull);
    expect(gateway.message, isNull);
  });

  test('dispose mid-run stops polling and notifying', () async {
    server.on('GET', '/api/status', status(running: false, state: 'stopped'));
    late GatewayRestart g;
    g = GatewayRestart(
      repository: ServerCareRepository(server.client()),
      now: () => clock,
      delay: (d) async {
        clock = clock.add(d);
        if (delays++ == 3) g.dispose();
      },
    );
    final run = g.run(GatewayAction.restart, profile: 'work');
    await run;
    final reads = server.requestsTo('GET', '/api/status').length;
    await pumpEventQueue();
    expect(server.requestsTo('GET', '/api/status').length, reads);
    expect(reads, lessThan(10));
  });
}

class _Trail implements BreadcrumbTrail {
  _Trail(this._record);
  final void Function(String, Map<String, Object>) _record;

  @override
  void record(String name, [Map<String, Object>? attributes]) =>
      _record(name, attributes ?? const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
