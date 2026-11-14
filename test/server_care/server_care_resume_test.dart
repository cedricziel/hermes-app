import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/gateway_restart.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

/// Dart timers stop while iOS suspends the app, so a poll that is waiting for
/// its timer reads again at once when the app returns. Nothing is resent, and
/// nothing is read while App Lock covers the app.
void main() {
  late FakeHermesServer server;
  late DateTime clock;
  late bool covered;

  /// A delay that never fires by itself: the suspended app's timer.
  Future<void> suspended(Duration d) => Completer<void>().future;

  Map<String, dynamic> action(String name) => {
    'name': name,
    'running': true,
    'exit_code': null,
    'pid': 1,
    'lines': ['=== $name started 2026-11-14 09:00:00 ==='],
  };

  DioException lost(RequestOptions o) =>
      DioException.connectionError(requestOptions: o, reason: 'lost');

  setUp(() {
    clock = DateTime(2026, 11, 14, 9);
    covered = false;
    server = FakeHermesServer();
  });

  group('a gateway restart', () {
    late GatewayRestart gateway;

    void serve({bool lostAnswer = false}) {
      server
        ..onRequest('POST', '/api/gateway/restart', (o) {
          if (lostAnswer) throw lost(o);
          return (
            status: 200,
            body: {'ok': true, 'pid': 1, 'name': 'gateway-restart'},
          );
        })
        ..on(
          'GET',
          '/api/actions/gateway-restart/status',
          action('gateway-restart'),
        )
        ..on('GET', '/api/status', {
          ...statusHealthy(),
          'gateway_running': true,
          'gateway_state': 'running',
        });
    }

    setUp(() {
      gateway = GatewayRestart(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: suspended,
        covered: () => covered,
      );
    });

    tearDown(() {
      if (!gateway.disposed) gateway.dispose();
    });

    int statusReads() => server.requestsTo('GET', '/api/status').length;
    int posts() => server.requestsTo('POST', '/api/gateway/restart').length;

    test('polls again at once on resume and never resends', () async {
      serve();
      unawaited(gateway.run(GatewayAction.restart, profile: 'work'));
      await pumpEventQueue();
      final before = statusReads();
      expect(before, greaterThanOrEqualTo(1));
      gateway.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
    });

    test('after a lost answer a resume reads, it does not resend', () async {
      serve(lostAnswer: true);
      unawaited(gateway.run(GatewayAction.restart, profile: 'work'));
      await pumpEventQueue();
      final before = statusReads();
      gateway.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
      expect(gateway.busy, isTrue);
    });

    test('reads nothing while App Lock covers the app, and once it '
        'lifts', () async {
      serve();
      unawaited(gateway.run(GatewayAction.restart, profile: 'work'));
      await pumpEventQueue();
      final before = statusReads();
      covered = true;
      gateway.appResumed();
      await pumpEventQueue();
      expect(statusReads(), before);
      covered = false;
      gateway.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
    });

    test('a resume with no run does nothing', () async {
      serve();
      gateway.appResumed();
      await pumpEventQueue();
      expect(statusReads(), 0);
    });

    test('disposing frees a waiting run', () async {
      serve();
      final run = gateway.run(GatewayAction.restart, profile: 'work');
      await pumpEventQueue();
      gateway.dispose();
      await run.timeout(const Duration(seconds: 2));
    });
  });

  group('a Hermes update', () {
    late HermesUpdateRun update;

    void serve({bool lostAnswer = false}) {
      server
        ..onRequest('POST', '/api/hermes/update', (o) {
          if (lostAnswer) throw lost(o);
          return (status: 200, body: updateStarted());
        })
        ..on('GET', '/api/health', {
          'ok': true,
          'version': '0.22.2',
          'commit': 'old1111',
          'auth_required': true,
        })
        ..on(
          'GET',
          '/api/actions/hermes-update/status',
          action('hermes-update'),
        );
    }

    setUp(() {
      update = HermesUpdateRun(
        repository: ServerCareRepository(server.client()),
        probeConnection: () async {},
        now: () => clock,
        delay: suspended,
        covered: () => covered,
      );
    });

    tearDown(() {
      if (!update.disposed) update.dispose();
    });

    int statusReads() =>
        server.requestsTo('GET', '/api/actions/hermes-update/status').length;
    int posts() => server.requestsTo('POST', '/api/hermes/update').length;

    test('polls again at once on resume and never resends', () async {
      serve();
      unawaited(update.start());
      await pumpEventQueue();
      final before = statusReads();
      expect(before, greaterThanOrEqualTo(1));
      update.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
    });

    test('after a lost answer a resume reads, it does not resend', () async {
      serve(lostAnswer: true);
      unawaited(update.start());
      await pumpEventQueue();
      final before = statusReads();
      update.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
    });

    test('reads nothing while App Lock covers the app, and once it '
        'lifts', () async {
      serve();
      unawaited(update.start());
      await pumpEventQueue();
      final before = statusReads();
      covered = true;
      update.appResumed();
      await pumpEventQueue();
      expect(statusReads(), before);
      covered = false;
      update.appResumed();
      await pumpEventQueue();
      expect(statusReads(), greaterThan(before));
      expect(posts(), 1);
    });

    test('a resume with no run does nothing', () async {
      serve();
      update.appResumed();
      await pumpEventQueue();
      expect(statusReads(), 0);
    });
  });
}
