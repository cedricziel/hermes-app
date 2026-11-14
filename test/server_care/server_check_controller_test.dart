import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/server_check_controller.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late DateTime clock;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late ServerCheckController check;
  late List<Duration> waits;
  late List<(String, Map<String, Object>)> crumbs;

  const header = '=== doctor started 2026-11-14 09:00:00 ===';

  Map<String, dynamic> action({
    bool running = false,
    int? exit,
    List<String> lines = const [],
    String head = header,
  }) => {
    'name': 'doctor',
    'running': running,
    'exit_code': exit,
    'pid': 1,
    'lines': [head, ...lines],
  };

  /// An earlier run has finished, then a new one goes on and on: the status
  /// read before the request sees the first, the polls the second.
  void goesOn(List<String> lines) {
    var reads = 0;
    server.onRequest(
      'GET',
      '/api/actions/doctor/status',
      (_) => (
        status: 200,
        body: reads++ == 0
            ? action(exit: 0, lines: const ['◆ Old', '  ✓ old'])
            : action(
                running: true,
                head: '=== doctor started 2026-11-14 09:05:00 ===',
                lines: lines,
              ),
      ),
    );
  }

  var covered = false;

  ServerCheckController build() => ServerCheckController(
    covered: () => covered,
    repository: ServerCareRepository(server.client()),
    telemetry: ConnectionTelemetry(
      events: (name, [attributes = const {}]) => events(name, attributes),
      tracer: tracer,
      serverAttributes: const {'hermes.version': '0.22.2'},
    ),
    breadcrumbs: Breadcrumbs.of(_Trail((n, a) => crumbs.add((n, a)))),
    now: () => clock,
    delay: (d) async {
      waits.add(d);
      clock = clock.add(d);
    },
  );

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/ops/doctor', {
        'ok': true,
        'pid': 4321,
        'name': 'doctor',
      })
      ..on(
        'GET',
        '/api/actions/doctor/status',
        action(exit: 1, lines: doctorProblems),
      );
    clock = DateTime(2026, 11, 14, 9);
    events = RecordedEvents();
    tracer = RecordingTracer();
    waits = [];
    crumbs = [];
    covered = false;
    check = build();
  });

  tearDown(() => check.dispose());

  int posts() => server.requestsTo('POST', '/api/ops/doctor').length;

  test('a run reads the report and keeps it', () async {
    final phases = <CheckPhase>[];
    check.addListener(() => phases.add(check.phase));
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
    expect(
      phases,
      containsAllInOrder([
        CheckPhase.starting,
        CheckPhase.running,
        CheckPhase.finished,
      ]),
    );
    final report = check.report!;
    expect(report.problems, 1);
    expect(report.warnings, 1);
    expect(report.fixes, hasLength(2));
    expect(check.profile, 'work');
    expect(check.finishedAt, clock);
    expect(check.busy, isFalse);
    expect(posts(), 1);
  });

  test('no check starts while App Lock covers the app', () async {
    covered = true;
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.idle);
    expect(check.report, isNull);
    expect(posts(), 0);
    covered = false;
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
  });

  test('every call that can names the profile', () async {
    await check.run(profile: 'work');
    expect(
      server.requestsTo('POST', '/api/ops/doctor').single.queryParameters,
      {'profile': 'work'},
    );
  });

  test('only the latest run is read when the log keeps earlier ones', () async {
    server.on('GET', '/api/actions/doctor/status', actionStatusAfterTwoRuns());
    await check.run(profile: 'work');
    expect(check.lines, isNot(contains('old run line')));
    expect(check.report!.problems, 1);
  });

  test('all passed', () async {
    server.on('GET', '/api/actions/doctor/status', {
      'name': 'doctor',
      'running': false,
      'exit_code': 0,
      'lines': doctorAllPassed,
    });
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
    expect(check.report!.allPassed, isTrue);
    expect(check.report!.problems, 0);
  });

  test('lines no rule matched are kept as they were written', () async {
    await check.run(profile: 'work');
    final other = [for (final s in check.report!.sections) ...s.other];
    expect(other, ['something unexpected']);
    server.on('GET', '/api/actions/doctor/status', {
      'name': 'doctor',
      'running': false,
      'exit_code': 0,
      'lines': [header, 'a new kind of output', 'on two lines'],
    });
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
    expect(check.report!.sections, isEmpty);
    expect(check.lines, ['a new kind of output', 'on two lines']);
  });

  test('follows the action status every 1.5 s while it runs', () async {
    var reads = 0;
    server.onRequest('GET', '/api/actions/doctor/status', (_) {
      final done = ++reads > 3;
      return (
        status: 200,
        body: action(
          running: !done,
          exit: done ? 1 : null,
          lines: done ? doctorProblems : doctorProblems.take(2).toList(),
        ),
      );
    });
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
    expect(waits, everyElement(const Duration(milliseconds: 1500)));
    // The baseline read before the run is one of the reads.
    expect(
      server.requestsTo('GET', '/api/actions/doctor/status').length,
      greaterThanOrEqualTo(4),
    );
    expect(
      server
          .requestsTo('GET', '/api/actions/doctor/status')
          .last
          .queryParameters['lines'],
      greaterThan(60),
    );
  });

  test('says how many checks came in while it runs', () async {
    var reads = 0;
    final counts = <int>[];
    server.onRequest('GET', '/api/actions/doctor/status', (_) {
      reads++;
      if (reads == 3) counts.add(check.progress);
      final done = reads > 3;
      return (
        status: 200,
        body: action(
          running: !done,
          exit: done ? 1 : null,
          lines: done ? doctorProblems : ['◆ A', '  ✓ one', '  ✓ two'],
        ),
      );
    });
    await check.run(profile: 'work');
    // Read 3 happens after the first running answer (read 2) was counted.
    expect(counts, [2]);
  });

  test('one run at a time: a second call joins and sends nothing', () async {
    final first = check.run(profile: 'work');
    final second = check.run(profile: 'work');
    await Future.wait([first, second]);
    expect(posts(), 1);
  });

  test('after a result a new run sends a new request', () async {
    await check.run(profile: 'work');
    await check.run(profile: 'work');
    expect(posts(), 2);
  });

  test('not finished after 3 minutes: timed out, nothing resent', () async {
    goesOn(const ['◆ A', '  ✓ one']);
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.timedOut);
    expect(
      clock.difference(DateTime(2026, 11, 14, 9)).inSeconds,
      inInclusiveRange(180, 182),
    );
    expect(posts(), 1);
    // The state offers no second run.
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.timedOut);
    expect(posts(), 1);
    expect(tracer.spans.single.attributes['outcome'], 'timeout');
  });

  test('keep waiting follows the same run for another 3 minutes', () async {
    goesOn(const ['◆ A', '  ✓ one']);
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.timedOut);
    final before = clock;
    var reads = 0;
    server.onRequest('GET', '/api/actions/doctor/status', (_) {
      final done = ++reads > 5;
      return (
        status: 200,
        body: action(
          running: !done,
          exit: done ? 1 : null,
          lines: doctorProblems,
        ),
      );
    });
    final waiting = check.keepWaiting();
    expect(check.phase, CheckPhase.running);
    await waiting;
    expect(check.phase, CheckPhase.finished);
    expect(clock.isAfter(before), isTrue);
    expect(posts(), 1);
  });

  test('keep waiting ends in a timeout again, still without a run', () async {
    goesOn(const ['◆ A']);
    await check.run(profile: 'work');
    await check.keepWaiting();
    expect(check.phase, CheckPhase.timedOut);
    expect(posts(), 1);
  });

  test('keep waiting does nothing outside a timeout', () async {
    await check.keepWaiting();
    expect(check.phase, CheckPhase.idle);
    await check.run(profile: 'work');
    await check.keepWaiting();
    expect(check.phase, CheckPhase.finished);
  });

  test('a poll that fails is tried again until the window ends', () async {
    var reads = 0;
    server.onRequest('GET', '/api/actions/doctor/status', (r) {
      // The first read is the baseline before the run.
      if (reads++ == 0) return (status: 200, body: action(exit: 0));
      if (reads < 4) {
        throw DioException.connectionError(requestOptions: r, reason: 'x');
      }
      return (status: 200, body: action(exit: 1, lines: doctorProblems));
    });
    await check.run(profile: 'work');
    expect(check.phase, CheckPhase.finished);
  });

  group('a lost answer to the request', () {
    setUp(() {
      server.onRequest('POST', '/api/ops/doctor', (r) {
        throw DioException.connectionError(requestOptions: r, reason: 'drop');
      });
    });

    test('is followed and never sent again', () async {
      var reads = 0;
      server.onRequest('GET', '/api/actions/doctor/status', (_) {
        reads++;
        // The baseline is the finished earlier run; then the new one runs and
        // ends.
        if (reads == 1) {
          return (
            status: 200,
            body: action(exit: 0, lines: const ['◆ Old', '  ✓ old']),
          );
        }
        if (reads == 2) {
          return (
            status: 200,
            body: action(
              running: true,
              head: '=== doctor started 2026-11-14 09:05:00 ===',
              lines: const ['◆ A'],
            ),
          );
        }
        return (
          status: 200,
          body: action(
            exit: 1,
            head: '=== doctor started 2026-11-14 09:05:00 ===',
            lines: doctorProblems,
          ),
        );
      });
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
      expect(check.report!.problems, 1);
      expect(posts(), 1);
    });

    test('does not take the earlier run for the new one', () async {
      // Always the same finished earlier run: nothing says the check ran.
      server.on(
        'GET',
        '/api/actions/doctor/status',
        action(exit: 0, lines: const ['◆ Old', '  ✓ old']),
      );
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.timedOut);
      expect(check.report, isNull);
      expect(posts(), 1);
    });

    test('a run that finished while the answer was lost is read', () async {
      var reads = 0;
      server.onRequest('GET', '/api/actions/doctor/status', (_) {
        return (
          status: 200,
          body: reads++ == 0
              ? action(exit: 0, lines: const ['◆ Old', '  ✓ old'])
              : action(
                  exit: 1,
                  head: '=== doctor started 2026-11-14 09:01:00 ===',
                  lines: doctorProblems,
                ),
        );
      });
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
      expect(check.report!.problems, 1);
    });
  });

  group('a run that did not happen', () {
    test("Hermes' refusal is shown as it was written", () async {
      server.on('POST', '/api/ops/doctor', {
        'detail': 'doctor is already running',
      }, status: 500);
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.failed);
      expect(check.failure, CheckFailure.refused);
      expect(check.message, 'doctor is already running');
      expect(posts(), 1);
    });

    test('a missing route fails without a message', () async {
      server.on('POST', '/api/ops/doctor', {
        'detail': 'Not Found',
      }, status: 404);
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.failed);
      expect(check.failure, CheckFailure.unsupported);
      expect(check.message, isNull);
    });

    test('a refused read of the action ends the run', () async {
      server.on('GET', '/api/actions/doctor/status', {
        'detail': 'no',
      }, status: 403);
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.failed);
    });

    test(
      'a check that stops with nothing to read fails with its words',
      () async {
        server.on(
          'GET',
          '/api/actions/doctor/status',
          action(
            exit: 2,
            lines: const ['Traceback (most recent call last):', 'boom'],
          ),
        );
        await check.run(profile: 'work');
        expect(check.phase, CheckPhase.failed);
        expect(check.failure, CheckFailure.exited);
        expect(check.message, contains('boom'));
      },
    );

    test('Try again after a failure sends a new run', () async {
      server.on('POST', '/api/ops/doctor', {'detail': 'busy'}, status: 500);
      await check.run(profile: 'work');
      server.on('POST', '/api/ops/doctor', {'ok': true, 'name': 'doctor'});
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
      expect(posts(), 2);
    });
  });

  group('what is kept', () {
    test('drop clears the result', () async {
      await check.run(profile: 'work');
      check.drop();
      expect(check.phase, CheckPhase.idle);
      expect(check.report, isNull);
      expect(check.lines, isEmpty);
      expect(check.profile, isNull);
    });

    test('a new controller has nothing and asks for nothing', () async {
      await check.run(profile: 'work');
      final requests = server.requests.length;
      final fresh = build();
      addTearDown(fresh.dispose);
      expect(fresh.phase, CheckPhase.idle);
      expect(fresh.report, isNull);
      await pumpEventQueue();
      expect(server.requests.length, requests);
    });

    test('covering the app drops the result and the run in flight', () async {
      await check.run(profile: 'work');
      check.cover();
      expect(check.report, isNull);
      expect(check.phase, CheckPhase.idle);

      goesOn(const ['◆ A']);
      late final ServerCheckController c;
      var delays = 0;
      c = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: (d) async {
          clock = clock.add(d);
          if (delays++ == 2) c.cover();
        },
      );
      addTearDown(c.dispose);
      await c.run(profile: 'work');
      expect(c.phase, CheckPhase.idle);
      expect(c.report, isNull);
      final reads = server
          .requestsTo('GET', '/api/actions/doctor/status')
          .length;
      await pumpEventQueue();
      expect(
        server.requestsTo('GET', '/api/actions/doctor/status').length,
        reads,
      );
    });

    test('a profile switch drops the result of another profile', () async {
      await check.run(profile: 'work');
      check.profileChanged('work');
      expect(check.report, isNotNull);
      check.profileChanged('home');
      expect(check.report, isNull);
      expect(check.phase, CheckPhase.idle);
    });

    test('a profile switch ends a run for the old profile', () async {
      goesOn(const ['◆ A']);
      late final ServerCheckController c;
      var delays = 0;
      c = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: (d) async {
          clock = clock.add(d);
          if (delays++ == 1) c.profileChanged('home');
        },
      );
      addTearDown(c.dispose);
      await c.run(profile: 'work');
      expect(c.phase, CheckPhase.idle);
      expect(posts(), 1);
    });

    test('dispose mid-run stops following', () async {
      goesOn(const ['◆ A']);
      late final ServerCheckController c;
      var delays = 0;
      c = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: (d) async {
          clock = clock.add(d);
          if (delays++ == 2) c.dispose();
        },
      );
      await c.run(profile: 'work');
      final reads = server.requests.length;
      await pumpEventQueue();
      expect(server.requests.length, reads);
      expect(reads, lessThan(10));
    });
  });

  test('the app coming back to the front reads at once', () async {
    final gate = Completer<void>();
    var reads = 0;
    server.onRequest('GET', '/api/actions/doctor/status', (_) {
      reads++;
      return (
        status: 200,
        body: reads < 3
            ? action(running: true, lines: const ['◆ A'])
            : action(exit: 1, lines: doctorProblems),
      );
    });
    final c = ServerCheckController(
      repository: ServerCareRepository(server.client()),
      now: () => clock,
      // The timer of a suspended app: it never fires by itself.
      delay: (_) => gate.future,
    );
    addTearDown(c.dispose);
    final run = c.run(profile: 'work');
    await pumpEventQueue();
    expect(c.phase, CheckPhase.running);
    c.resumed();
    await pumpEventQueue();
    // Another wait begins; wake it too.
    c.resumed();
    await run;
    expect(c.phase, CheckPhase.finished);
  });

  group('telemetry', () {
    test('a span, an event and a breadcrumb with fixed names only', () async {
      server.on(
        'GET',
        '/api/actions/doctor/status',
        action(
          exit: 1,
          lines: [
            '◆ Secret section /home/me/.hermes',
            '  ✗ token abc123 rejected',
            '  ⚠ path /home/me/x',
          ],
        ),
      );
      await check.run(profile: 'private-profile');
      expect(crumbs.map((c) => c.$1), ['server_care.check.started']);
      expect(crumbs.single.$2, isEmpty);
      final span = tracer.spans.single;
      expect(span.name, 'server_care.check');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'outcome': 'done',
        'problems': '1-3',
        'warnings': '1-3',
        'unknown_lines': '0',
        'duration': '0-10s',
      });
      expect(span.ended, isTrue);
      expect(events.named('server_care.check_finished'), [
        {'outcome': 'done', 'problems': '1-3', 'warnings': '1-3'},
      ]);
      final everything = [
        span.attributes.toString(),
        events.named('server_care.check_finished').toString(),
        crumbs.toString(),
      ].join();
      for (final secret in [
        'private-profile',
        'abc123',
        '/home/me',
        'Secret',
      ]) {
        expect(everything, isNot(contains(secret)));
      }
    });

    test('a refusal is an outcome without Hermes words', () async {
      server.on('POST', '/api/ops/doctor', {
        'detail': 'secret detail',
      }, status: 500);
      await check.run(profile: 'work');
      expect(tracer.spans.single.attributes['outcome'], 'failed');
      expect(
        events.named('server_care.check_finished').single['outcome'],
        'failed',
      );
      expect(
        tracer.spans.single.attributes.toString(),
        isNot(contains('secret')),
      );
    });

    test('a broken tracer does not break a run', () async {
      check.dispose();
      check = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        telemetry: ConnectionTelemetry(tracer: ThrowingTracer()),
        now: () => clock,
        delay: (d) async => clock = clock.add(d),
      );
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
    });
  });

  group('review fixes', () {
    test('an adopted running run is accepted when it finishes', () async {
      server.onRequest('POST', '/api/ops/doctor', (r) {
        throw DioException.connectionError(requestOptions: r, reason: 'drop');
      });
      var reads = 0;
      const head = '=== doctor started 2026-11-14 09:05:00 ===';
      server.onRequest('GET', '/api/actions/doctor/status', (_) {
        reads++;
        return (
          status: 200,
          body: reads == 1
              ? action(exit: 0, lines: const ['◆ Old', '  ✓ old'])
              : reads == 2
              // The run is going; the baseline header differs from it.
              ? action(running: true, head: head, lines: const ['◆ A'])
              : action(exit: 1, head: head, lines: doctorProblems),
        );
      });
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
    });

    test(
      'a doctor that is already running is followed, not sent again',
      () async {
        var reads = 0;
        server.onRequest('GET', '/api/actions/doctor/status', (_) {
          reads++;
          return (
            status: 200,
            body: reads < 3
                ? action(running: true, lines: const ['◆ A', '  ✓ one'])
                : action(exit: 1, lines: doctorProblems),
          );
        });
        await check.run(profile: 'work');
        expect(posts(), 0);
        expect(check.phase, CheckPhase.finished);
        expect(check.report!.problems, 1);
      },
    );

    test(
      'Run after Dismiss does not send a second doctor while one runs',
      () async {
        goesOn(const ['◆ A']);
        await check.run(profile: 'work');
        expect(check.phase, CheckPhase.timedOut);
        expect(posts(), 1);
        check.dismiss();
        var reads = 0;
        server.onRequest(
          'GET',
          '/api/actions/doctor/status',
          (_) => (
            status: 200,
            body: reads++ < 2
                ? action(running: true, lines: const ['◆ A'])
                : action(exit: 1, lines: doctorProblems),
          ),
        );
        await check.run(profile: 'work');
        expect(posts(), 1);
        expect(check.phase, CheckPhase.finished);
      },
    );

    test(
      'a status read that finds no route ends the run without a request',
      () async {
        server.on('GET', '/api/actions/doctor/status', {
          'detail': 'Not Found',
        }, status: 404);
        var reported = 0;
        check.dispose();
        check = ServerCheckController(
          repository: ServerCareRepository(server.client()),
          now: () => clock,
          delay: (d) async => clock = clock.add(d),
          onUnsupported: () => reported++,
        );
        await check.run(profile: 'work');
        expect(check.phase, CheckPhase.failed);
        expect(check.failure, CheckFailure.unsupported);
        expect(posts(), 0);
        expect(reported, 1);
      },
    );

    test('a missing route on the request is reported to the shell', () async {
      server.on('POST', '/api/ops/doctor', {
        'detail': 'Not Found',
      }, status: 404);
      var reported = 0;
      check.dispose();
      check = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: (d) async => clock = clock.add(d),
        onUnsupported: () => reported++,
      );
      await check.run(profile: 'work');
      expect(check.failure, CheckFailure.unsupported);
      expect(reported, 1);
    });

    for (final (name, code) in [('non-zero', 2), ('no exit code', null)]) {
      test(
        'a run that stopped part-way ($name) is partial, not a report',
        () async {
          server.on(
            'GET',
            '/api/actions/doctor/status',
            action(
              exit: code,
              lines: const ['◆ Configuration', '  ✓ config.yaml found'],
            ),
          );
          await check.run(profile: 'work');
          expect(check.phase, CheckPhase.failed);
          expect(check.failure, CheckFailure.incomplete);
        },
      );
    }

    test('a run that stopped with nothing readable is exited', () async {
      server.on(
        'GET',
        '/api/actions/doctor/status',
        action(exit: 2, lines: const ['Traceback', 'boom']),
      );
      await check.run(profile: 'work');
      expect(check.failure, CheckFailure.exited);
      expect(check.report, isNull);
    });

    test('findings with a non-zero exit are a report', () async {
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
    });

    test('a clock set backwards does not wait for ever', () async {
      goesOn(const ['◆ A']);
      var waits = 0;
      check.dispose();
      check = ServerCheckController(
        repository: ServerCareRepository(server.client()),
        now: () => clock,
        delay: (d) async {
          waits++;
          clock = clock.subtract(const Duration(hours: 1));
        },
      );
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.timedOut);
      expect(waits, lessThan(5));
    });
  });

  group('review round', () {
    for (final (name, code) in [
      ('killed (137)', 137),
      ('no exit code', null),
    ]) {
      test('a doctor $name after one warning did not finish', () async {
        server.on(
          'GET',
          '/api/actions/doctor/status',
          action(exit: code, lines: const ['◆ Configuration', '  ⚠ Low disk']),
        );
        await check.run(profile: 'work');
        expect(check.phase, CheckPhase.failed);
        expect(check.failure, CheckFailure.incomplete);
        // What was read stays, to be shown as partial.
        expect(check.report!.warnings, 1);
        expect(check.lines, contains('  ⚠ Low disk'.trimRight()));
      });
    }

    test('exit 1 with findings and exit 0 are reports', () async {
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
      server.on('GET', '/api/actions/doctor/status', {
        ...action(exit: 0, lines: doctorAllPassed.sublist(1)),
      });
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
    });

    test('drop forgets a partial report too', () async {
      server.on(
        'GET',
        '/api/actions/doctor/status',
        action(exit: 137, lines: const ['◆ A', '  ⚠ Low disk']),
      );
      await check.run(profile: 'work');
      check.drop();
      expect(check.report, isNull);
      expect(check.lines, isEmpty);
    });

    test('a baseline that could not be read is taken at the first read '
        'after a lost answer', () async {
      server.onRequest('POST', '/api/ops/doctor', (r) {
        throw DioException.connectionError(requestOptions: r, reason: 'drop');
      });
      var reads = 0;
      server.onRequest('GET', '/api/actions/doctor/status', (r) {
        reads++;
        // The first read, before the request, fails.
        if (reads == 1) {
          throw DioException.connectionError(requestOptions: r, reason: 'x');
        }
        return (
          status: 200,
          body: reads == 2
              ? action(exit: 0, lines: const ['◆ Old', '  ✓ old'])
              : action(
                  exit: 1,
                  head: '=== doctor started 2026-11-14 09:05:00 ===',
                  lines: doctorProblems,
                ),
        );
      });
      await check.run(profile: 'work');
      expect(check.phase, CheckPhase.finished);
      expect(check.report!.problems, 1);
      expect(posts(), 1);
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
