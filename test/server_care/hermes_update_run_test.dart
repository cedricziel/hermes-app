import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';

import '../support/fake_hermes_server.dart';
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

  HermesUpdateRun build({Future<void> Function(Duration)? onDelay}) =>
      HermesUpdateRun(
        repository: ServerCareRepository(server.client()),
        probeConnection: () async => probes++,
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

  test('a 20 minute suspension while restarting lands in notBack', () async {
    timeline(upAt: 60 * 60);
    var suspended = false;
    run.dispose();
    run = build(
      onDelay: (d) async {
        // The app is suspended once, in the middle of the restart.
        if (!suspended && now() > 10) {
          suspended = true;
          clock = clock.add(const Duration(minutes: 20));
          // Hermes came back meanwhile; nothing the app read says so.
          timeline(upAt: 0);
        }
      },
    );
    await run.start();
    expect(run.phase, UpdatePhase.notBack);
    expect(run.result, isNull);
    expect(server.requestsTo('GET', '/api/hermes/update/receipt'), isEmpty);
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
        if (polls++ == 1) run.reset();
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
}
