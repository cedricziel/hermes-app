import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

const _html = '<html><body>Bad gateway</body></html>';
const _old = 'old1111';
const _fresh = 'new2222';

void main() {
  late FakeHermesServer server;
  late DateTime t0;
  late DateTime clock;
  late HermesUpdateRun run;
  late int probes;
  late RecordedEvents events;
  late RecordingTracer tracer;

  /// Seconds since the test began, on the fake clock.
  int now() => clock.difference(t0).inSeconds;

  Map<String, dynamic> health(String commit, {String version = '0.22.2'}) => {
    'ok': true,
    'version': version,
    'commit': commit,
    'auth_required': true,
  };

  Map<String, dynamic> action({
    bool running = false,
    int? exit,
    String? id,
    List<String> lines = const [],
  }) => {
    'name': 'hermes-update',
    'running': running,
    'exit_code': exit,
    'pid': 1,
    'action_id': ?id,
    'lines': ['=== hermes-update started 2026-11-14 09:00:00 ===', ...lines],
  };

  DioException down(RequestOptions o) =>
      DioException.connectionError(requestOptions: o, reason: 'down');

  /// The dashboard answers with the old commit until [downAt], does not
  /// answer until [upAt] and answers with a new commit after.
  void timeline({int downAt = 5, int upAt = 30, bool proxy = false}) {
    server.onRequest('GET', '/api/health', (o) {
      final t = now();
      if (t < downAt) return (status: 200, body: health(_old));
      if (t < upAt) {
        if (proxy) return (status: 502, body: _html);
        throw down(o);
      }
      return (status: 200, body: health(_fresh, version: '0.23.0'));
    });
    server.onRequest('GET', '/api/actions/hermes-update/status', (o) {
      final t = now();
      if (t < downAt) {
        return (status: 200, body: action(running: true, lines: ['pulling']));
      }
      if (t < upAt) {
        if (proxy) return (status: 502, body: _html);
        throw down(o);
      }
      return (status: 200, body: action());
    });
  }

  HermesUpdateRun build({
    Future<void> Function(Duration)? onDelay,
    Breadcrumbs crumbs = Breadcrumbs.none,
    ConnectionTelemetry? telemetry,
  }) => HermesUpdateRun(
    repository: ServerCareRepository(server.client()),
    probeConnection: () async => probes++,
    breadcrumbs: crumbs,
    telemetry:
        telemetry ??
        ConnectionTelemetry(
          events: (name, [attributes = const {}]) => events(name, attributes),
          tracer: tracer,
          serverAttributes: const {'hermes.version': '0.22.2'},
        ),
    now: () => clock,
    delay: (d) async {
      clock = clock.add(d);
      await onDelay?.call(d);
    },
  );

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/hermes/update', updateStarted())
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess());
    t0 = DateTime(2026, 11, 14, 9);
    clock = t0;
    probes = 0;
    events = RecordedEvents();
    tracer = RecordingTracer();
    timeline();
    run = build();
  });

  tearDown(() {
    if (!run.disposed) run.dispose();
  });

  int posts() => server.requestsTo('POST', '/api/hermes/update').length;

  test('success: every phase, one POST, the receipt decides', () async {
    final phases = <UpdatePhase>[];
    run.addListener(() {
      if (phases.isEmpty || phases.last != run.phase) phases.add(run.phase);
    });
    await run.start();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.success);
    expect(run.postVersion, '0.23.0');
    expect(run.versionBefore, '0.22.2');
    expect(run.versionNow, '0.23.0');
    expect(
      phases,
      containsAllInOrder([
        UpdatePhase.starting,
        UpdatePhase.updating,
        UpdatePhase.restarting,
        UpdatePhase.verifying,
        UpdatePhase.finished,
      ]),
    );
    expect(posts(), 1);
    expect(run.busy, isFalse);
    expect(run.showsBanner, isFalse);
    await pumpEventQueue();
    expect(probes, 1);
  });

  test('while restarting /api/health is the only call', () async {
    await run.start();
    final paths = [for (final r in server.requests) r.path];
    final lastAction = paths.lastIndexOf('/api/actions/hermes-update/status');
    final receipt = paths.indexOf('/api/hermes/update/receipt');
    final between = paths.sublist(lastAction + 1, receipt);
    expect(between, isNotEmpty);
    expect(between.toSet(), {'/api/health'});
  });

  test('the banner shows while restarting and verifying only', () async {
    final banner = <UpdatePhase, bool>{};
    run.addListener(() => banner[run.phase] = run.showsBanner);
    await run.start();
    expect(banner[UpdatePhase.updating], isFalse);
    expect(banner[UpdatePhase.restarting], isTrue);
    expect(banner[UpdatePhase.verifying], isTrue);
    expect(banner[UpdatePhase.finished], isFalse);
  });

  test('partial: shows what is left to do', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'summary': {
        'outcome': 'partial',
        'action_id': 'a' * 32,
        'post_version': '0.23.0',
        'followups': [
          {'step': 'restart', 'reason': 'Restart the dashboard by hand.'},
        ],
        'user_action': {
          'step': 'migrate',
          'reason': "Run 'hermes config migrate'.",
        },
      },
    });
    await run.start();
    expect(run.result, UpdateResult.partial);
    expect(run.reasons, ["Run 'hermes config migrate'."]);
  });

  test('partial without a user action lists each follow-up', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'summary': {
        'outcome': 'partial',
        'action_id': 'a' * 32,
        'followups': [
          {'step': 'one', 'reason': 'First.'},
          {'step': 'two', 'reason': 'Second.'},
        ],
      },
    });
    await run.start();
    expect(run.reasons, ['First.', 'Second.']);
  });

  test('failed before the restart: exit 1, the receipt says failed', () async {
    server
      ..on('GET', '/api/health', health(_old))
      ..on(
        'GET',
        '/api/actions/hermes-update/status',
        action(exit: 1, lines: ['git pull failed']),
      )
      ..on('GET', '/api/hermes/update/receipt', {
        'summary': {'outcome': 'failed', 'action_id': 'a' * 32},
      });
    await run.start();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.failed);
    expect(run.lines, ['git pull failed']);
    expect(run.versionNow, '0.22.2');
    // It never went through a restart.
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(1),
    );
  });

  test('failed before the restart with no receipt is still failed', () async {
    server
      ..on('GET', '/api/health', health(_old))
      ..on('GET', '/api/actions/hermes-update/status', action(exit: 2))
      ..on('GET', '/api/hermes/update/receipt', {
        'detail': 'No update receipt found.',
      }, status: 404);
    await run.start();
    expect(run.result, UpdateResult.failed);
  });

  test('interrupted: the receipt after the restart says so', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'summary': {'outcome': 'interrupted', 'action_id': 'a' * 32},
    });
    await run.start();
    expect(run.result, UpdateResult.interrupted);
    expect(run.phase, UpdatePhase.finished);
  });

  test('refused by the server: nothing is followed', () async {
    server.on('POST', '/api/hermes/update', updateRefused());
    await run.start();
    expect(run.phase, UpdatePhase.refused);
    expect(run.refusalMessage, 'Update the container image instead.');
    expect(run.refusalCommand, 'docker compose pull');
    expect(
      server.requestsTo('GET', '/api/actions/hermes-update/status'),
      isEmpty,
    );
    await pumpEventQueue();
    expect(probes, 1);
  });

  test('forgetText drops Hermes\' own words and keeps the outcome', () async {
    server.on('POST', '/api/hermes/update', updateRefused());
    await run.start();
    expect(run.refusalMessage, isNotNull);
    var notified = 0;
    run.addListener(() => notified++);
    run.forgetText();
    expect(run.phase, UpdatePhase.refused);
    expect(run.refusalMessage, isNull);
    expect(run.refusalCommand, isNull);
    expect(run.lines, isEmpty);
    expect(run.reasons, isEmpty);
    expect(notified, 1);
    run.forgetText();
    expect(notified, 1);
  });

  test('refused with an HTTP error carries Hermes\' detail', () async {
    server.on('POST', '/api/hermes/update', {'detail': 'busy'}, status: 409);
    await run.start();
    expect(run.phase, UpdatePhase.refused);
    expect(run.refusalMessage, 'busy');
  });

  test('already running: the run follows that action as its own', () async {
    server
      ..on('POST', '/api/hermes/update', {
        'ok': true,
        'pid': 7,
        'name': 'hermes-update',
        'already_running': true,
        'action_id': 'b' * 32,
      })
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess(actionId: 'b'));
    await run.start();
    expect(run.result, UpdateResult.success);
  });

  test('a receipt for another action is not credited: unknown', () async {
    server.on(
      'GET',
      '/api/hermes/update/receipt',
      receiptSuccess(actionId: 'c'),
    );
    await run.start();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.unknown);
    expect(run.versionNow, '0.23.0');
    // Retried for about a minute, not forever.
    final reads = server.requestsTo('GET', '/api/hermes/update/receipt').length;
    expect(reads, inInclusiveRange(20, 40));
  });

  test('a receipt that is still running is waited for', () async {
    var reads = 0;
    server.onRequest(
      'GET',
      '/api/hermes/update/receipt',
      (_) => (
        status: 200,
        body: reads++ < 3
            ? {
                'summary': {'outcome': 'running', 'action_id': 'a' * 32},
              }
            : receiptSuccess(),
      ),
    );
    await run.start();
    expect(run.result, UpdateResult.success);
    expect(reads, 4);
  });

  test('no receipt (404) for a minute: unknown', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'detail': 'No update receipt found.',
    }, status: 404);
    await run.start();
    expect(run.result, UpdateResult.unknown);
  });

  test('not back after 15 minutes: notBack, then Keep waiting', () async {
    timeline(upAt: 60 * 60);
    await run.start();
    expect(run.phase, UpdatePhase.notBack);
    expect(run.showsBanner, isFalse);
    expect(now(), greaterThanOrEqualTo(15 * 60));
    expect(now(), lessThan(15 * 60 + 30));
    expect(posts(), 1);

    // Hermes comes back during the next wait.
    timeline(downAt: 5, upAt: now() + 120);
    await run.keepWaiting();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.success);
    expect(posts(), 1);
  });

  test('Keep waiting is another full window', () async {
    timeline(upAt: 60 * 60);
    await run.start();
    final first = now();
    await run.keepWaiting();
    expect(run.phase, UpdatePhase.notBack);
    expect(now() - first, greaterThanOrEqualTo(15 * 60));
  });

  test('Dismiss from notBack ends the run', () async {
    timeline(upAt: 60 * 60);
    await run.start();
    run.dismiss();
    expect(run.phase, UpdatePhase.idle);
    expect(run.versionBefore, isNull);
  });

  test('a lost answer to the POST is never resent', () async {
    server.onRequest('POST', '/api/hermes/update', (o) => throw down(o));
    server.onRequest('GET', '/api/actions/hermes-update/status', (o) {
      final t = now();
      if (t < 5) return (status: 200, body: action(running: true));
      if (t < 30) throw down(o);
      return (status: 200, body: action(id: 'a' * 32));
    });
    await run.start();
    expect(posts(), 1);
    // The action id was adopted from the finished run's status.
    expect(run.result, UpdateResult.success);
  });

  test('a lost answer and a child never seen running: unknown', () async {
    server
      ..on('POST', '/api/hermes/update', {'detail': ''}, status: 502)
      ..on('GET', '/api/health', health(_old))
      ..on(
        'GET',
        '/api/actions/hermes-update/status',
        action(exit: 0, id: 'z' * 32),
      );
    await run.start();
    expect(posts(), 1);
    expect(run.result, UpdateResult.unknown);
    expect(run.phase, UpdatePhase.finished);
  });

  test('a second start while running joins and sends nothing', () async {
    final first = run.start();
    final second = run.start();
    await Future.wait([first, second]);
    expect(posts(), 1);
  });

  test('after a run ended, start sends a new POST', () async {
    await run.start();
    timeline(downAt: 5, upAt: now() + 30);
    await run.start();
    expect(posts(), 2);
  });

  for (final status in [502, 503, 504]) {
    test('a proxy answering $status (HTML) stays in restarting', () async {
      timeline(proxy: true);
      final seen = <UpdatePhase>[];
      run.addListener(() => seen.add(run.phase));
      await run.start();
      expect(seen, contains(UpdatePhase.restarting));
      expect(run.result, UpdateResult.success);
    });
  }

  test('only a 200 JSON ok: true moves on from restarting', () async {
    var reads = 0;
    server.onRequest('GET', '/api/health', (o) {
      final t = now();
      if (t < 5) return (status: 200, body: health(_old));
      return switch (reads++) {
        0 => (status: 502, body: _html),
        1 => (status: 503, body: _html),
        2 => (status: 504, body: _html),
        3 => (status: 200, body: _html),
        4 => (status: 200, body: {'ok': false}),
        _ => (status: 200, body: health(_fresh, version: '0.23.0')),
      };
    });
    server.onRequest(
      'GET',
      '/api/actions/hermes-update/status',
      (o) => now() < 5
          ? (status: 200, body: action(running: true))
          : throw down(o),
    );
    await run.start();
    expect(reads, 6);
    expect(run.result, UpdateResult.success);
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(1),
    );
  });

  test('exit 0, the old commit and a success receipt: staleServer', () async {
    server
      ..on('GET', '/api/health', health(_old))
      ..on('GET', '/api/actions/hermes-update/status', action(exit: 0));
    await run.start();
    expect(run.phase, UpdatePhase.staleServer);
    expect(run.result, isNull);
    expect(run.showsBanner, isFalse);
    expect(run.versionBefore, '0.22.2');
    expect(run.postVersion, '0.23.0');

    // Still the old commit: nothing changes.
    await run.checkAgain();
    expect(run.phase, UpdatePhase.staleServer);

    // Restarted by hand: a new commit moves to finished.
    server.on('GET', '/api/health', health(_fresh, version: '0.23.0'));
    await run.checkAgain();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.success);
    expect(posts(), 1);
  });

  test('stale with a partial receipt finishes as partial', () async {
    server
      ..on('GET', '/api/health', health(_old))
      ..on('GET', '/api/actions/hermes-update/status', action(exit: 0))
      ..on('GET', '/api/hermes/update/receipt', {
        'summary': {
          'outcome': 'partial',
          'action_id': 'a' * 32,
          'post_version': '0.23.0',
          'user_action': {'step': 'x', 'reason': 'Restart Hermes.'},
        },
      });
    await run.start();
    expect(run.phase, UpdatePhase.staleServer);
    expect(run.reasons, ['Restart Hermes.']);
    server.on('GET', '/api/health', health(_fresh, version: '0.23.0'));
    await run.checkAgain();
    expect(run.result, UpdateResult.partial);
  });

  test('a restart missed between two polls is verified by the receipt', () async {
    // The status already says stopped when the dashboard answers with new code.
    var reads = 0;
    server
      ..onRequest(
        'GET',
        '/api/health',
        (_) => (
          status: 200,
          body: reads++ == 0 ? health(_old) : health(_fresh, version: '0.23.0'),
        ),
      )
      ..on('GET', '/api/actions/hermes-update/status', action());
    await run.start();
    expect(run.result, UpdateResult.success);
  });

  test('the same commit answering while the child still runs goes back to updating', () async {
    var statusReads = 0;
    server.onRequest('GET', '/api/health', (o) {
      final t = now();
      // One blip at t=4, then the old commit again until the child ends.
      if (t == 4) throw down(o);
      return (
        status: 200,
        body: t < 12 ? health(_old) : health(_fresh, version: '0.23.0'),
      );
    });
    server.onRequest('GET', '/api/actions/hermes-update/status', (o) {
      statusReads++;
      final t = now();
      if (t == 4) throw down(o);
      return (status: 200, body: action(running: t < 12));
    });
    final seen = <UpdatePhase>[];
    run.addListener(() {
      if (seen.isEmpty || seen.last != run.phase) seen.add(run.phase);
    });
    await run.start();
    expect(
      seen,
      containsAllInOrder([
        UpdatePhase.updating,
        UpdatePhase.restarting,
        UpdatePhase.updating,
        UpdatePhase.verifying,
        UpdatePhase.finished,
      ]),
    );
    expect(run.result, UpdateResult.success);
    expect(statusReads, greaterThan(3));
  });

  test('a 20 minute suspension while still down lands in notBack', () async {
    timeline(upAt: 60 * 60);
    var suspended = false;
    run.dispose();
    run = build(
      onDelay: (d) async {
        // The app is suspended once, in the middle of the restart.
        if (!suspended && now() > 10) {
          suspended = true;
          clock = clock.add(const Duration(minutes: 20));
        }
      },
    );
    await run.start();
    expect(run.phase, UpdatePhase.notBack);
    expect(run.result, isNull);
    expect(server.requestsTo('GET', '/api/hermes/update/receipt'), isEmpty);
  });

  test('one more health read follows a suspension before notBack', () async {
    timeline(upAt: 60 * 60);
    var suspended = false;
    run.dispose();
    run = build(
      onDelay: (d) async {
        if (!suspended && now() > 10) {
          suspended = true;
          clock = clock.add(const Duration(minutes: 20));
          // Hermes came back while the app slept: the next read sees it, and
          // only the receipt then decides.
          timeline(upAt: 0);
        }
      },
    );
    await run.start();
    expect(run.phase, UpdatePhase.finished);
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(1),
    );
  });

  test('the receipt read repeats on the wall clock, not by count', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'detail': 'No update receipt found.',
    }, status: 404);
    var suspended = false;
    run.dispose();
    run = build(
      onDelay: (d) async {
        if (!suspended && run.phase == UpdatePhase.verifying) {
          suspended = true;
          clock = clock.add(const Duration(minutes: 20));
        }
      },
    );
    await run.start();
    expect(run.result, UpdateResult.unknown);
    // One read before the suspension, one after; not a minute of polls.
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(2),
    );
  });

  test('a second 401 on the receipt is unauthorized, not failed', () async {
    server.on('GET', '/api/hermes/update/receipt', {
      'detail': 'nope',
    }, status: 401);
    await run.start();
    expect(run.phase, UpdatePhase.unauthorized);
    expect(run.result, isNull);

    server.on('GET', '/api/hermes/update/receipt', receiptSuccess());
    await run.checkAgain();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.success);
    expect(posts(), 1);
  });

  test('confirming sends nothing; dismiss goes back to idle', () async {
    run.beginConfirmation();
    expect(run.phase, UpdatePhase.confirming);
    expect(server.requests, isEmpty);
    run.dismiss();
    expect(run.phase, UpdatePhase.idle);
  });

  test('reset mid-run stops polling and sends nothing more', () async {
    var polls = 0;
    run.dispose();
    run = build(
      onDelay: (d) async {
        if (polls++ == 1) unawaited(run.reset());
      },
    );
    await run.start();
    final reads = server.requests.length;
    await pumpEventQueue();
    expect(server.requests.length, reads);
    expect(run.phase, UpdatePhase.idle);
    expect(posts(), 1);
  });

  test('dispose mid-run stops polling', () async {
    var polls = 0;
    run.dispose();
    run = build(
      onDelay: (d) async {
        if (polls++ == 1) run.dispose();
      },
    );
    await run.start();
    final reads = server.requests.length;
    await pumpEventQueue();
    expect(server.requests.length, reads);
  });

  group('receipt route that keeps failing', () {
    final failures = <String, FakeResponse>{
      '500 with detail': (status: 500, body: {'detail': 'boom'}),
      '400 with detail': (status: 400, body: {'detail': 'bad'}),
      '502 page': (status: 502, body: _html),
      '504 page': (status: 504, body: _html),
      '200 without a summary': (status: 200, body: {'x': 1}),
    };
    for (final MapEntry(:key, :value) in failures.entries) {
      test('$key on a healthy server ends in unknown, bounded', () async {
        server.onRequest('GET', '/api/hermes/update/receipt', (_) => value);
        final seen = <UpdatePhase>[];
        run.addListener(() => seen.add(run.phase));
        await run.start();
        expect(run.phase, UpdatePhase.finished);
        expect(run.result, UpdateResult.unknown);
        expect(server.requests.length, lessThan(200));
        // It did not bounce back to restarting once Hermes answered.
        final firstVerify = seen.indexOf(UpdatePhase.verifying);
        expect(seen.skip(firstVerify), isNot(contains(UpdatePhase.restarting)));
      });
    }

    test('with health failing too it ends, with delays', () async {
      var healthReads = 0;
      server.onRequest('GET', '/api/health', (o) {
        final t = now();
        if (t < 5) return (status: 200, body: health(_old));
        if (t < 30) throw down(o);
        // Answers, then drops again, forever.
        return healthReads++ % 2 == 0
            ? (status: 200, body: health(_fresh, version: '0.23.0'))
            : throw down(o);
      });
      server.on('GET', '/api/hermes/update/receipt', {
        'detail': 'boom',
      }, status: 500);
      await run.start();
      expect(run.phase, anyOf(UpdatePhase.finished, UpdatePhase.notBack));
      expect(server.requests.length, lessThan(400));
    });
  });

  group('staleness is judged from evidence', () {
    test('one failed action poll then the old commit: staleServer', () async {
      server
        ..on('GET', '/api/health', health(_old))
        ..on('GET', '/api/actions/hermes-update/status', {
          'detail': 'x',
        }, status: 502);
      await run.start();
      expect(run.phase, UpdatePhase.staleServer);
      expect(tracer.spans.single.attributes['came_back'], false);
    });

    test('the old commit stays stale though health failed once', () async {
      var reads = 0;
      server.onRequest('GET', '/api/health', (o) {
        final n = reads++;
        if (n == 0) return (status: 200, body: health('d923a5e0000'));
        if (n == 1) throw down(o);
        return (status: 200, body: health('d923a5e0000'));
      });
      server.on('GET', '/api/actions/hermes-update/status', action(exit: 0));
      await run.start();
      expect(run.phase, UpdatePhase.staleServer);
    });

    test('a full health sha matching a short post_sha is not stale', () async {
      server
        ..on('GET', '/api/health', health('0a1b2c3deadbeef'))
        ..on('GET', '/api/actions/hermes-update/status', action(exit: 0));
      // The commit before was read as the first health answer: make it old.
      var reads = 0;
      server.onRequest(
        'GET',
        '/api/health',
        (_) => (
          status: 200,
          body: reads++ == 0 ? health(_old) : health('0a1b2c3deadbeef'),
        ),
      );
      await run.start();
      expect(run.phase, UpdatePhase.finished);
      expect(run.result, UpdateResult.success);
    });
  });

  group('lost answer and relaunch', () {
    test('a failed POST answer is not resent and is followed', () async {
      server.on('POST', '/api/hermes/update', '<html>spa</html>');
      await run.start();
      expect(posts(), 1);
      expect(run.phase, UpdatePhase.finished);
    });
  });

  group('app lock', () {
    test('covered: no text is stored', () async {
      var covered = true;
      run.dispose();
      run = HermesUpdateRun(
        repository: ServerCareRepository(server.client()),
        covered: () => covered,
        now: () => clock,
        delay: (d) async => clock = clock.add(d),
      );
      server.on('POST', '/api/hermes/update', updateRefused());
      await run.start();
      expect(run.phase, UpdatePhase.refused);
      expect(run.refusalMessage, isNull);
      expect(run.refusalCommand, isNull);

      server
        ..on('POST', '/api/hermes/update', updateStarted())
        ..on('GET', '/api/health', health(_old))
        ..on(
          'GET',
          '/api/actions/hermes-update/status',
          action(exit: 1, lines: ['secret line']),
        )
        ..on('GET', '/api/hermes/update/receipt', {
          'summary': {'outcome': 'failed', 'action_id': 'a' * 32},
        });
      await run.start();
      expect(run.lines, isEmpty);

      server.on('GET', '/api/hermes/update/receipt', {
        'summary': {
          'outcome': 'partial',
          'action_id': 'a' * 32,
          'user_action': {'step': 'x', 'reason': 'Do it.'},
        },
      });
      server.on('GET', '/api/actions/hermes-update/status', action(exit: 0));
      var reads = 0;
      server.onRequest(
        'GET',
        '/api/health',
        (_) => (
          status: 200,
          body: reads++ == 0 ? health(_old) : health(_fresh, version: '0.23.0'),
        ),
      );
      await run.start();
      expect(run.result, UpdateResult.partial);
      expect(run.reasons, isEmpty);

      covered = false;
      reads = 0;
      await run.start();
      expect(run.reasons, ['Do it.']);
    });
  });

  group('spans are never left open', () {
    test('reset mid-run ends it as interrupted', () async {
      var polls = 0;
      run.dispose();
      run = build(
        onDelay: (d) async {
          if (polls++ == 1) unawaited(run.reset());
        },
      );
      await run.start();
      final span = tracer.spans.single;
      expect(span.ended, isTrue);
      expect(span.attributes['outcome'], 'interrupted');
    });

    test('dispose mid-run ends it', () async {
      var polls = 0;
      run.dispose();
      run = build(
        onDelay: (d) async {
          if (polls++ == 1) run.dispose();
        },
      );
      await run.start();
      expect(tracer.spans.single.ended, isTrue);
      expect(tracer.spans.single.attributes['outcome'], 'interrupted');
    });

    test('reset before anything was sent is cancelled', () async {
      server.onRequest('GET', '/api/health', (_) {
        unawaited(run.reset());
        return (status: 200, body: health(_old));
      });
      await run.start();
      expect(tracer.spans.single.ended, isTrue);
      expect(tracer.spans.single.attributes['outcome'], 'cancelled');
      expect(posts(), 0);
    });

    test('a settled run leaves none open for the next confirmation', () async {
      await run.start();
      run.beginConfirmation();
      expect(tracer.spans.every((s) => s.ended), isTrue);
      expect(events.named('server_care.update_finished'), hasLength(1));
    });
  });

  group('the update request is refused for lack of access', () {
    test('nothing started: Check again reads and sends nothing', () async {
      server.on('POST', '/api/hermes/update', {'detail': 'no'}, status: 401);
      await run.start();
      expect(run.phase, UpdatePhase.unauthorized);
      expect(run.nothingStarted, isTrue);
      final before = server.requests.length;
      await run.checkAgain();
      expect(run.phase, UpdatePhase.unauthorized);
      expect(server.requests.length, before);
      expect(posts(), 1);
    });

    test('a 401 on the receipt is a started update', () async {
      server.on('GET', '/api/hermes/update/receipt', {
        'detail': 'no',
      }, status: 401);
      await run.start();
      expect(run.nothingStarted, isFalse);
    });
  });

  test('a double tap on Check again finishes once', () async {
    server
      ..on('GET', '/api/health', health(_old))
      ..on('GET', '/api/actions/hermes-update/status', action(exit: 0));
    await run.start();
    expect(run.phase, UpdatePhase.staleServer);
    server.on('GET', '/api/health', health(_fresh, version: '0.23.0'));
    await Future.wait([run.checkAgain(), run.checkAgain()]);
    expect(run.phase, UpdatePhase.finished);
    // The stale report and one for the finish.
    expect(events.named('server_care.update_finished'), hasLength(2));
  });

  group('clock set backwards', () {
    test('restarting ends in notBack instead of polling forever', () async {
      // Down for good, whatever the clock says.
      server
        ..onRequest('GET', '/api/health', (o) => throw down(o))
        ..onRequest(
          'GET',
          '/api/actions/hermes-update/status',
          (o) => throw down(o),
        );
      var jumped = false;
      run.dispose();
      run = build(
        onDelay: (d) async {
          if (!jumped && run.phase == UpdatePhase.restarting && now() > 10) {
            jumped = true;
            clock = clock.subtract(const Duration(hours: 2));
          }
        },
      );
      await run.start();
      expect(run.phase, UpdatePhase.notBack);
      expect(server.requests.length, lessThan(100));
    });

    test('verifying ends in unknown instead of reading forever', () async {
      server.on('GET', '/api/hermes/update/receipt', {
        'detail': 'No update receipt found.',
      }, status: 404);
      var jumped = false;
      run.dispose();
      run = build(
        onDelay: (d) async {
          if (!jumped && run.phase == UpdatePhase.verifying) {
            jumped = true;
            clock = clock.subtract(const Duration(hours: 2));
          }
        },
      );
      await run.start();
      expect(run.result, UpdateResult.unknown);
    });

    test('updating ends in stillRunning', () async {
      server
        ..on('GET', '/api/health', health(_old))
        ..on('GET', '/api/actions/hermes-update/status', action(running: true));
      var jumped = false;
      run.dispose();
      run = build(
        onDelay: (d) async {
          if (!jumped && now() > 10) {
            jumped = true;
            clock = clock.subtract(const Duration(hours: 2));
          }
        },
      );
      await run.start();
      expect(run.phase, UpdatePhase.stillRunning);
    });
  });

  group('a long update', () {
    setUp(() {
      server
        ..on('GET', '/api/health', health(_old))
        ..on(
          'GET',
          '/api/actions/hermes-update/status',
          action(running: true, lines: ['still pulling']),
        );
    });

    test(
      'says nothing is confirmed after 30 minutes, keeping the record',
      () async {
        await run.start();
        expect(run.phase, UpdatePhase.stillRunning);
        expect(run.result, isNull);
        expect(run.busy, isFalse);
        expect(run.showsBanner, isFalse);
        expect(now(), inInclusiveRange(30 * 60, 30 * 60 + 5));
        expect(server.requests.length, lessThan(1000));
        expect(posts(), 1);
        expect(tracer.spans.single.attributes['outcome'], 'not_confirmed');
        expect(server.requestsTo('GET', '/api/hermes/update/receipt'), isEmpty);
      },
    );

    test('Check again continues and reads the result', () async {
      await run.start();
      var reads = 0;
      server
        ..onRequest(
          'GET',
          '/api/health',
          (_) => (status: 200, body: health(_fresh, version: '0.23.0')),
        )
        ..on('GET', '/api/actions/hermes-update/status', action());
      reads = server.requests.length;
      await run.checkAgain();
      expect(server.requests.length, greaterThan(reads));
      expect(run.phase, UpdatePhase.finished);
      expect(run.result, UpdateResult.success);
      expect(posts(), 1);
    });

    test('Check again while it still runs waits another window', () async {
      await run.start();
      final first = now();
      await run.checkAgain();
      expect(run.phase, UpdatePhase.stillRunning);
      expect(now() - first, greaterThanOrEqualTo(30 * 60));
    });

    test('Dismiss ends it', () async {
      await run.start();
      run.dismiss();
      expect(run.phase, UpdatePhase.idle);
    });
  });

  test('a flapping proxy cannot spin restarting and updating', () async {
    var n = 0;
    server
      ..on('GET', '/api/health', health(_old))
      ..onRequest(
        'GET',
        '/api/actions/hermes-update/status',
        (_) => n++ % 2 == 0
            ? (status: 502, body: _html)
            : (status: 200, body: action(running: true)),
      );
    await run.start();
    expect(run.phase, UpdatePhase.stillRunning);
    // About one cycle per poll interval over 30 minutes, three calls each.
    expect(server.requests.length, lessThan(30 * 60 ~/ 2 * 4));
  });

  test('a 4xx without a detail answering the POST is a lost answer', () async {
    for (final status in [408, 429]) {
      server.on('POST', '/api/hermes/update', _html, status: status);
      await run.start();
      expect(run.phase, isNot(UpdatePhase.refused), reason: '$status');
      expect(run.nothingStarted, isFalse);
    }
    expect(posts(), 2);
  });

  test('a 4xx with a detail is still a refusal', () async {
    server.on('POST', '/api/hermes/update', {'detail': 'busy'}, status: 429);
    await run.start();
    expect(run.phase, UpdatePhase.refused);
    expect(run.refusalMessage, 'busy');
  });

  group('telemetry', () {
    test('a success after minutes carries buckets and nothing else', () async {
      final crumbs = <(String, Map<String, Object>)>[];
      run.dispose();
      run = build(crumbs: Breadcrumbs.of(_Trail((n, a) => crumbs.add((n, a)))));
      timeline(upAt: 4 * 60);
      run.confirmed();
      expect(crumbs.single.$1, 'server_care.update.confirmed');
      expect(crumbs.single.$2, isEmpty);

      await run.start();
      expect(run.result, UpdateResult.success);
      final span = tracer.spans.single;
      expect(span.name, 'server_care.update');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'resumed_after_launch': false,
        'outcome': 'success',
        'phase_reached': 'verifying',
        'came_back': true,
        'duration': '3-10m',
      });
      expect(span.ended, isTrue);
      expect(events.named('server_care.update_finished'), [
        {'outcome': 'success', 'came_back': true, 'duration': '3-10m'},
      ]);
    });

    test('no version, commit, action id, command or text leaks', () async {
      server
        ..on('GET', '/api/health', health('secretcommit', version: '9.9.9'))
        ..on(
          'GET',
          '/api/actions/hermes-update/status',
          action(exit: 1, lines: ['secret-line']),
        )
        ..on('GET', '/api/hermes/update/receipt', {
          'summary': {'outcome': 'failed', 'action_id': 'a' * 32},
        });
      await run.start();
      server.on('POST', '/api/hermes/update', {
        'ok': false,
        'error': 'docker_update_unsupported',
        'message': 'secret message',
        'update_command': 'secret command',
      });
      await run.start();
      final all = [
        for (final s in tracer.spans) s.attributes.toString(),
        for (final e in events.named('server_care.update_finished'))
          e.toString(),
      ].join();
      for (final secret in [
        'secretcommit',
        '9.9.9',
        'secret',
        'aaaaaaaa',
        'work',
      ]) {
        expect(all, isNot(contains(secret)));
      }
      expect(tracer.spans.map((s) => s.attributes['outcome']), [
        'failed',
        'refused',
      ]);
    });

    test('stale, not back and unknown have their own outcomes', () async {
      server
        ..on('GET', '/api/health', health(_old))
        ..on('GET', '/api/actions/hermes-update/status', action(exit: 0));
      await run.start();
      expect(tracer.spans.last.attributes['outcome'], 'stale_server');
      expect(tracer.spans.last.attributes['came_back'], false);

      timeline(upAt: 60 * 60);
      await run.start();
      expect(tracer.spans.last.attributes['outcome'], 'not_back');
      expect(tracer.spans.last.attributes['duration'], '>10m');

      timeline(downAt: now() + 5, upAt: now() + 30);
      server.on('GET', '/api/hermes/update/receipt', {
        'detail': 'No update receipt found.',
      }, status: 404);
      run.dismiss();
      await run.start();
      expect(tracer.spans.last.attributes['outcome'], 'unknown');
    });

    test('a broken tracer does not break a run', () async {
      run.dispose();
      run = build(
        telemetry: ConnectionTelemetry(
          tracer: ThrowingTracer(),
          events: (name, [attributes = const {}]) => throw StateError('x'),
        ),
      );
      await run.start();
      expect(run.result, UpdateResult.success);
    });
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
