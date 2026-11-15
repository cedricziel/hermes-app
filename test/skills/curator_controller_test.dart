import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/curator/curator_config.dart';
import 'package:hermes_app/src/skills/curator/curator_controller.dart';
import 'package:hermes_app/src/skills/curator/curator_telemetry.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_breadcrumbs.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'curator_fixtures.dart';

const _marker = 'MARKER-5c2e';
const _statusPath = '/api/actions/curator-run/status';
const _newHeader = '=== curator-run started 2026-11-15 03:37:50 ===';

/// The log after a second run began: the first run's block, then the new
/// header, with the pass still going.
final _runningNow = <String, Object?>{
  ...recordedStatusRunning,
  'lines': [...(recordedStatusFinished['lines']! as List), '', _newHeader],
};

Map<String, Object?> _log(
  List<String> lines, {
  bool running = false,
  int? exit = 0,
}) => {
  'name': 'curator-run',
  'running': running,
  'exit_code': exit,
  'pid': null,
  'lines': lines,
};

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late RecordedBreadcrumbs crumbs;
  late DateTime clock;
  late List<Duration> delays;
  late int goneCalls;
  late int endedCalls;
  Completer<void>? delayGate;
  final made = <CuratorController>[];

  CuratorController build({
    String profile = 'demo-a',
    Duration timeout = const Duration(seconds: 5),
  }) {
    final controller = CuratorController(
      repository: HermesCuratorRepository(server.client(), timeout: timeout),
      readConfig: CuratorConfigReader(server.client()).call,
      profile: profile,
      telemetry: CuratorTelemetry(
        ConnectionTelemetry(
          events: (n, [a = const {}]) => events(n, a),
          tracer: tracer,
          serverAttributes: const {'hermes.version': '0.22.2'},
        ),
        crumbs.breadcrumbs,
      ),
      now: () => clock,
      delay: (d) async {
        delays.add(d);
        clock = clock.add(d);
        await delayGate?.future;
      },
      onProfileGone: () => goneCalls++,
      onRunEnded: () => endedCalls++,
    );
    made.add(controller);
    return controller;
  }

  /// Answers the action status from [answers], one per read; the last one
  /// repeats.
  void statuses(List<Object?> given) {
    // The read before the POST answers like the one on open.
    final answers = [given.first, given.first, ...given.skip(1)];
    var i = 0;
    server.onRequest(
      'GET',
      _statusPath,
      (_) => (status: 200, body: answers[math.min(i++, answers.length - 1)]),
    );
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(done(), isTrue, reason: 'condition never held');
  }

  Future<CuratorController> opened({
    String profile = 'demo-a',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final c = build(profile: profile, timeout: timeout)..start();
    await until(
      () => c.phase != CuratorRunPhase.opening && c.load != CuratorLoad.loading,
    );
    return c;
  }

  Future<void> confirm(CuratorController c) async {
    c.beginRun();
    await c.confirmRun();
  }

  int count(String method, String path) =>
      server.requests.where((r) => r.method == method && r.path == path).length;

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    crumbs = RecordedBreadcrumbs();
    clock = DateTime.utc(2026, 11, 15, 3, 40);
    delays = [];
    goneCalls = 0;
    endedCalls = 0;
    delayGate = null;
    serveRecordedCurator(server);
    statuses([recordedStatusFinished]);
    server.on('GET', '/api/config', recordedConfigCurator);
  });

  tearDown(() {
    for (final c in made) {
      if (!c.disposed) c.dispose();
    }
    made.clear();
    if (!(delayGate?.isCompleted ?? true)) delayGate!.complete();
  });

  group('status', () {
    test('loads the status and reads the action status once', () async {
      final c = await opened();

      expect(c.load, CuratorLoad.loaded);
      expect(c.status?.intervalHours, 168);
      expect(c.phase, CuratorRunPhase.idle);
      expect(c.canRunNow, isTrue);
      expect(count('GET', _statusPath), 1);
      expect(
        server.requests.map((r) => r.queryParameters['lines']),
        contains(2000),
      );
      expect(c.hasOutput, isFalse);
    });

    test('a route that is missing hides the section', () async {
      server.on(
        'GET',
        '/api/curator',
        recordedRouteMissing404.body,
        status: recordedRouteMissing404.status,
      );
      final c = await opened();

      expect(c.load, CuratorLoad.unsupported);
      expect(c.visible, isFalse);
    });

    test(
      'a missing profile is not an old server and reloads profiles',
      () async {
        server.on(
          'GET',
          '/api/curator',
          recordedProfileMissing.body,
          status: recordedProfileMissing.status,
        );
        final c = await opened();

        expect(c.load, CuratorLoad.profileGone);
        expect(c.visible, isTrue);
        expect(goneCalls, 1);
      },
    );

    test('unavailable, invalid and offline are told apart', () async {
      server.on(
        'GET',
        '/api/curator',
        recordedCuratorUnavailable.body,
        status: recordedCuratorUnavailable.status,
      );
      expect((await opened()).load, CuratorLoad.unavailable);

      server.on(
        'GET',
        '/api/curator',
        recordedProfileInvalid.body,
        status: recordedProfileInvalid.status,
      );
      expect((await opened()).load, CuratorLoad.failed);

      server.onRequest(
        'GET',
        '/api/curator',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
          error: const SocketException('no route'),
        ),
      );
      expect((await opened()).load, CuratorLoad.offline);
    });

    test('off in config offers no Run now', () async {
      server.on('GET', '/api/curator', recordedCuratorDisabled);
      final c = await opened();

      expect(c.status?.isOn, isFalse);
      expect(c.canRunNow, isFalse);
    });

    test('Try again reads again and keeps the old status meanwhile', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/curator', (_) => gate.future);

      final reload = c.reload();
      expect(c.refreshing, isTrue);
      expect(c.status, isNotNull);
      gate.complete((status: 200, body: recordedCuratorRan));
      await reload;

      expect(c.refreshing, isFalse);
      expect(c.status?.lastRunAt, isNotNull);
    });
  });

  group('pause', () {
    test('shows the value being sent, then the value Hermes answers', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('PUT', '/api/curator/paused', (_) => gate.future);

      final future = c.setPaused(true);
      expect(c.paused, isTrue);
      expect(c.pause, CuratorPause.saving);
      // Hermes answers a different value than the one sent.
      gate.complete((status: 200, body: recordedPausedOff));
      await future;

      expect(c.paused, isFalse);
      expect(c.pause, CuratorPause.idle);
      expect(crumbs.named('skills_curator.paused'), [
        {'paused': false},
      ]);
    });

    test(
      'a lost answer rolls back, reads status again and never resends',
      () async {
        final c = await opened();
        // What the 10 s receive timeout of the request ends in.
        server.onRequest(
          'PUT',
          '/api/curator/paused',
          (r) => throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          ),
        );

        final before = count('GET', '/api/curator');
        await c.setPaused(true);

        expect(c.pause, CuratorPause.lost);
        expect(c.paused, isFalse, reason: 'back to the last known value');
        await until(() => count('GET', '/api/curator') == before + 1);
        expect(count('PUT', '/api/curator/paused'), 1);
      },
    );

    test(
      '400 and 500 are section errors and the switch is rolled back',
      () async {
        final c = await opened();
        for (final error in [
          recordedPauseBodyInvalid,
          recordedPauseUnavailable,
        ]) {
          server.on(
            'PUT',
            '/api/curator/paused',
            error.body,
            status: error.status,
          );
          await c.setPaused(true);

          expect(c.pause, CuratorPause.failed);
          expect(c.paused, isFalse);
          expect(c.load, CuratorLoad.loaded);
        }
      },
    );

    test('404 Profile keeps the switch, reloads profiles, no hiding', () async {
      final c = await opened();
      server.on(
        'PUT',
        '/api/curator/paused',
        recordedProfileMissing.body,
        status: recordedProfileMissing.status,
      );
      await c.setPaused(true);

      expect(c.pause, CuratorPause.profileGone);
      expect(c.paused, isFalse);
      expect(c.visible, isTrue);
      expect(goneCalls, 1);
    });

    test('a missing route hides the section', () async {
      final c = await opened();
      server.on(
        'PUT',
        '/api/curator/paused',
        recordedRouteMissing405.body,
        status: recordedRouteMissing405.status,
      );
      await c.setPaused(true);

      expect(c.visible, isFalse);
    });
  });

  group('run confirmation', () {
    test(
      'opens at once; the config read refines it, never delays it',
      () async {
        final c = await opened();
        final gate = Completer<FakeResponse>();
        server.onRequest('GET', '/api/config', (_) => gate.future);

        c.beginRun();
        expect(c.confirmation, isNotNull);
        expect(c.confirmation?.consolidate, isNull);
        gate.complete((
          status: 200,
          body: {
            'curator': {'consolidate': true, 'prune_builtins': false},
          },
        ));
        await until(() => c.confirmation?.consolidate != null);

        expect(c.confirmation?.consolidate, isTrue);
        expect(c.confirmation?.pruneBuiltins, isFalse);
        expect(count('POST', '/api/curator/run'), 0);
      },
    );

    test('an unreadable config keeps the hedged wording', () async {
      server.on('GET', '/api/config', 'oops', status: 500);
      final c = await opened();
      c.beginRun();
      await pumpEventQueue();

      expect(c.confirmation?.consolidate, isNull);
      expect(c.confirmation?.pruneBuiltins, isNull);
    });

    test('Cancel sends nothing and a late config does not reopen it', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/config', (_) => gate.future);
      c.beginRun();
      c.cancelRun();
      gate.complete((status: 200, body: recordedConfigCurator));
      await pumpEventQueue();
      await c.confirmRun();

      expect(c.confirmation, isNull);
      expect(count('POST', '/api/curator/run'), 0);
    });
  });

  group('following a run', () {
    test(
      'finishes only with running false and a header after the POST',
      () async {
        statuses([
          recordedStatusFinished, // the read on open
          _runningNow,
          _runningNow,
          recordedStatusArchived,
        ]);
        final c = await opened();
        server.on('GET', '/api/curator', recordedCuratorRan);

        await confirm(c);

        expect(c.phase, CuratorRunPhase.finished);
        expect(count('POST', '/api/curator/run'), 1);
        expect(delays.take(2), [
          const Duration(seconds: 2),
          const Duration(seconds: 2),
        ]);
        expect(
          c.outputLines,
          contains('auto: checked=2 stale=1 archived=1 reactivated=0'),
        );
        expect(c.outputLines.first, isNot(startsWith('===')));
        expect(endedCalls, 1);
        expect(c.canRunNow, isTrue, reason: 'Run again');
        expect(c.startedAt, isNotNull);
      },
    );

    test('running false with the old header is not proof', () async {
      statuses([recordedStatusFinished, recordedStatusFinished]);
      final c = await opened();

      await confirm(c);

      expect(c.phase, CuratorRunPhase.unconfirmed);
      expect(c.hasOutput, isFalse);
      expect(c.canRunNow, isFalse);
      expect(c.canCheck, isTrue);
    });

    test('a newer last run time alone is not a finish', () async {
      statuses([recordedStatusFinished, _runningNow]);
      final c = await opened();
      server.on('GET', '/api/curator', recordedCuratorRan);

      await confirm(c);

      expect(c.phase, CuratorRunPhase.stillRunning);
      await until(() => c.startedAt != null);
      expect(c.startedAt, DateTime.utc(2026, 11, 15, 3, 37, 52, 300, 226));
      expect(c.canRunNow, isFalse);
    });

    test('a non-zero exit with proof is failed and shows the line', () async {
      statuses([
        recordedStatusArchived,
        _log([
          ..._lines(recordedStatusArchived),
          '',
          _disabledHeader,
          'curator: disabled via config',
        ], exit: 1),
      ]);
      final c = await opened();

      await confirm(c);

      expect(c.phase, CuratorRunPhase.failed);
      expect(c.outputLines.last, 'curator: disabled via config');
    });

    test('no exit code with proof is stopped and needs a read', () async {
      statuses([
        recordedStatusNeverRun,
        recordedStatusAfterRestart,
        recordedStatusAfterRestart,
      ]);
      final c = await opened();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.stopped);
      expect(c.canRunNow, isFalse);

      await c.checkStatus();

      expect(c.phase, CuratorRunPhase.checkedNothing);
      expect(c.canRunNow, isTrue);
    });

    test('backs off from 2 s to 5 s', () async {
      statuses([recordedStatusFinished, ...List.filled(25, _runningNow)]);
      final c = await opened();
      await confirm(c);

      expect(delays.first, const Duration(seconds: 2));
      expect(delays.map((d) => d.inSeconds).toSet(), {2, 3, 4, 5});
      expect(delays.map((d) => d.inSeconds).reduce(math.max), 5);
    });

    test(
      'stops after 15 minutes: still running, Check status offered',
      () async {
        statuses([recordedStatusFinished, _runningNow]);
        final c = await opened();
        await confirm(c);

        expect(c.phase, CuratorRunPhase.stillRunning);
        final waited = delays.fold(Duration.zero, (a, b) => a + b);
        expect(waited, greaterThanOrEqualTo(CuratorController.followLimit));
        expect(
          waited,
          lessThan(CuratorController.followLimit + const Duration(seconds: 6)),
        );
        expect(c.canCheck, isTrue);
        expect(c.canRunNow, isFalse);
        expect(tracer.spans.single.attributes['outcome'], 'timed_out');
      },
    );

    test('Check status that finds a run follows it with a new limit', () async {
      final answers = <Object?>[
        recordedStatusFinished,
        ...List.filled(2, _runningNow),
      ];
      statuses(answers);
      final c = await opened();
      await confirm(c);
      expect(c.phase, CuratorRunPhase.stillRunning);

      // The pass is still going on the next read, then ends after a while.
      var reads = 0;
      server.onRequest('GET', _statusPath, (_) {
        reads++;
        return (
          status: 200,
          body: reads < 60 ? _runningNow : recordedStatusArchived,
        );
      });
      await c.checkStatus();

      expect(reads, 60, reason: 'not cut off by the first 15 minutes');
      expect(c.phase, CuratorRunPhase.finished);
    });

    test('Check status reads once when nothing runs', () async {
      statuses([recordedStatusFinished, _runningNow]);
      final c = await opened();
      await confirm(c);
      server.requests.clear();
      statuses([recordedStatusArchived]);
      await c.checkStatus();

      expect(count('GET', _statusPath), 1);
      expect(c.phase, CuratorRunPhase.finished);
    });

    test('progress is lost after 10 s of failed polling', () async {
      var reads = 0;
      server.onRequest('GET', _statusPath, (r) {
        if (reads++ < 2) return (status: 200, body: recordedStatusFinished);
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      });
      final c = await opened();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.progressLost);
      expect(c.canRunNow, isFalse);
      expect(c.canCheck, isTrue);
      expect(reads, lessThan(10));
    });

    test('a run is blocked while another one is going', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('POST', '/api/curator/run', (_) => gate.future);
      final c = await opened();

      c.beginRun();
      final first = c.confirmRun();
      c.beginRun();
      await c.confirmRun();
      await c.confirmRun();

      expect(c.phase, CuratorRunPhase.starting);
      expect(c.confirmation, isNull);
      await until(() => count('POST', '/api/curator/run') == 1);
      statuses([recordedStatusFinished, recordedStatusArchived]);
      gate.complete((status: 200, body: recordedRunStarted));
      await first;
      expect(count('POST', '/api/curator/run'), 1);
    });
  });

  group('review fixes', () {
    test(
      'another client finishing a pass before a lost answer is not ours',
      () async {
        final c = await opened();
        // Another client's pass ran and ended after the section opened.
        statuses([recordedStatusArchived]);
        server.onRequest(
          'POST',
          '/api/curator/run',
          (r) => throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          ),
        );
        await confirm(c);
        expect(c.phase, CuratorRunPhase.lostAnswer);

        await c.checkStatus();

        expect(c.phase, CuratorRunPhase.checkedNothing);
        expect(c.hasOutput, isFalse);
      },
    );

    test('a pass running elsewhere at confirm time sends no POST', () async {
      final c = await opened();
      statuses([_runningNow]);
      await confirm(c);

      expect(c.phase, CuratorRunPhase.elsewhere);
      expect(count('POST', '/api/curator/run'), 0);
      expect(c.canRunNow, isFalse);
      expect(tracer.spans, isEmpty);
    });

    test('an unreadable read before the POST sends none', () async {
      final c = await opened();
      statuses([
        {...recordedStatusFinished, 'running': 'no'},
      ]);
      await confirm(c);

      expect(c.phase, CuratorRunPhase.unchecked);
      expect(count('POST', '/api/curator/run'), 0);
    });

    test('an unsupported pause does not stay saving', () async {
      final c = await opened();
      server.on(
        'PUT',
        '/api/curator/paused',
        recordedRouteMissing405.body,
        status: recordedRouteMissing405.status,
      );
      await c.setPaused(true);
      expect(c.pause, CuratorPause.idle);

      server.on('PUT', '/api/curator/paused', recordedPausedOn);
      await c.reload();
      await c.setPaused(true);

      expect(c.paused, isTrue);
    });

    test('a status read sent before a pause answer cannot undo it', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/curator', (_) => gate.future);
      final reload = c.reload();
      await c.setPaused(true);
      expect(c.paused, isTrue);

      gate.complete((status: 200, body: recordedCuratorNeverRun));
      await reload;

      expect(c.paused, isTrue);
    });

    test('the confirmation sends nothing once Run now is off', () async {
      final c = await opened();
      c.beginRun();
      server.on('GET', '/api/curator', recordedCuratorDisabled);
      await c.reload();
      await c.confirmRun();

      expect(count('POST', '/api/curator/run'), 0);
    });

    test(
      'a pass the app did not start is not proof, even with a header',
      () async {
        server.on('GET', _statusPath, 'no', status: 500);
        final c = await opened();
        expect(c.phase, CuratorRunPhase.unchecked);

        var reads = 0;
        server.onRequest('GET', _statusPath, (_) {
          reads++;
          return (
            status: 200,
            body: reads < 3 ? _runningNow : recordedStatusArchived,
          );
        });
        await c.checkStatus();

        expect(c.phase, CuratorRunPhase.checkedNothing);
        expect(c.hasOutput, isFalse);
      },
    );

    test('startedAt stays null when last_run_at did not change', () async {
      server.on('GET', '/api/curator', recordedCuratorRan);
      statuses([recordedStatusFinished, _runningNow, recordedStatusArchived]);
      final c = await opened();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.finished);
      expect(c.startedAt, isNull);
    });

    test('a pass resolved by Check status is logged again, marked', () async {
      statuses([recordedStatusFinished, _runningNow]);
      final c = await opened();
      await confirm(c);
      statuses([recordedStatusArchived]);
      await c.checkStatus();

      expect(events.named('skills_curator.run_finished'), [
        {'outcome': 'timed_out'},
        {'outcome': 'done', 'archived': 1, 'resolved_by_check': true},
      ]);
    });

    test('Check status after stopped keeps the earlier pass output', () async {
      statuses([
        recordedStatusNeverRun,
        recordedStatusAfterRestart,
        recordedStatusAfterRestart,
      ]);
      final c = await opened();
      await confirm(c);
      expect(c.phase, CuratorRunPhase.stopped);
      await c.checkStatus();

      expect(c.phase, CuratorRunPhase.checkedNothing);
      expect(c.hasOutput, isTrue);
    });

    test('a profile switch ends the wait without the delay', () async {
      statuses([recordedStatusFinished, ...List.filled(5, _runningNow)]);
      final c = await opened();
      delayGate = Completer<void>();
      c.beginRun();
      final run = c.confirmRun();
      await until(() => delays.isNotEmpty);

      c.switchProfile('demo-b');

      await run.timeout(const Duration(seconds: 2));
    });

    test(
      'polling failures that a success separates are not progress lost',
      () async {
        var reads = 0;
        server.onRequest('GET', _statusPath, (r) {
          final i = reads++;
          if (i < 2) return (status: 200, body: recordedStatusFinished);
          final k = i - 2;
          if (k >= 24) return (status: 200, body: recordedStatusArchived);
          if (k.isOdd) return (status: 200, body: _runningNow);
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        });
        final c = await opened();
        await confirm(c);

        expect(c.phase, CuratorRunPhase.finished);
      },
    );
  });

  group('finish proof traps', () {
    test(
      'a header with no line after it (a failed spawn) is no proof',
      () async {
        statuses([
          recordedStatusFinished,
          _log([..._lines(recordedStatusFinished), '', _newHeader]),
        ]);
        final c = await opened();
        await confirm(c);

        expect(c.phase, CuratorRunPhase.unconfirmed);
        expect(c.hasOutput, isFalse);
        expect(c.canRunNow, isFalse);
      },
    );

    test('a missing running is unknown, not "not running"', () async {
      final noRunning = {...recordedStatusArchived}..remove('running');
      statuses([recordedStatusFinished, noRunning]);
      final c = await opened();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.progressLost);
      expect(c.hasOutput, isFalse);
    });

    test('an open read with no running leaves Run now off', () async {
      statuses([
        {...recordedStatusFinished, 'running': 'no'},
      ]);
      final c = await opened();

      expect(c.phase, CuratorRunPhase.unchecked);
      expect(c.canRunNow, isFalse);
    });
  });

  group('config reader', () {
    test('reads the two switches and is null when unreadable', () async {
      final read = CuratorConfigReader(server.client()).call;
      final config = await read('demo-a');
      expect(config?.consolidate, isFalse);
      expect(config?.pruneBuiltins, isFalse);

      server.on('GET', '/api/config', 'oops', status: 500);
      expect(await read('demo-a'), isNull);
      server.on('GET', '/api/config', {'model': 'x'});
      expect((await read('demo-a'))?.consolidate, isNull);
      expect(await read(' '), isNull);
    });
  });

  group('a run that did not start or whose answer was lost', () {
    test(
      'a refused start says nothing started and can be tried again',
      () async {
        for (final (error, why) in [
          (recordedRunSpawnFailed, CuratorNotStarted.spawnFailed),
          (recordedRunUnnamed, CuratorNotStarted.refused),
          (recordedRunProfileInvalid, CuratorNotStarted.refused),
        ]) {
          server.on(
            'POST',
            '/api/curator/run',
            error.body,
            status: error.status,
          );
          final c = await opened();
          await confirm(c);

          expect(c.phase, CuratorRunPhase.notStarted);
          expect(c.notStarted, why);
          expect(c.canRunNow, isTrue);
        }
      },
    );

    test('a deleted profile is told apart and reloads profiles', () async {
      server.on(
        'POST',
        '/api/curator/run',
        recordedRunProfileGone.body,
        status: recordedRunProfileGone.status,
      );
      final c = await opened();
      await confirm(c);

      expect(c.notStarted, CuratorNotStarted.profileGone);
      expect(goneCalls, 1);
    });

    test('a request that never left the device is offline', () async {
      server.onRequest(
        'POST',
        '/api/curator/run',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
          error: const SocketException('no route'),
        ),
      );
      final c = await opened();
      await confirm(c);

      expect(c.notStarted, CuratorNotStarted.offline);
    });

    test('a dropped connection after the send is a lost answer', () async {
      server.onRequest(
        'POST',
        '/api/curator/run',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
          error: const HttpException('connection closed'),
        ),
      );
      final c = await opened();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.lostAnswer);
      expect(c.notStarted, isNull);
      expect(c.canRunNow, isFalse);
      expect(c.canCheck, isTrue);
      expect(count('POST', '/api/curator/run'), 1);
      expect(tracer.spans.single.attributes['trigger_lost'], isTrue);
      expect(tracer.spans.single.attributes['outcome'], 'unknown');
    });

    test('Check status after a lost answer reads, never posts again', () async {
      server.onRequest(
        'POST',
        '/api/curator/run',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      statuses([recordedStatusFinished, recordedStatusFinished]);
      final c = await opened();
      await confirm(c);
      await c.checkStatus();

      expect(c.phase, CuratorRunPhase.checkedNothing);
      expect(c.canRunNow, isTrue);
      expect(count('POST', '/api/curator/run'), 1);
    });

    test('a failed Check status stays unsure', () async {
      server.onRequest(
        'POST',
        '/api/curator/run',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final c = await opened();
      await confirm(c);
      server.on('GET', _statusPath, 'no', status: 500);
      await c.checkStatus();

      expect(c.phase, CuratorRunPhase.lostAnswer);
      expect(c.checkFailed, isTrue);
      expect(c.canRunNow, isFalse);
    });
  });

  group('open', () {
    test(
      'a pass running on the server disables Run now, shows no lines',
      () async {
        statuses([_runningNow]);
        final c = await opened();

        expect(c.phase, CuratorRunPhase.elsewhere);
        expect(c.canRunNow, isFalse);
        expect(c.canCheck, isTrue);
        expect(c.hasOutput, isFalse);
        expect(delays, isEmpty, reason: 'no polling until Check status');
      },
    );

    test(
      'Check status that finds it follows it, without showing lines',
      () async {
        var reads = 0;
        server.onRequest('GET', _statusPath, (_) {
          reads++;
          return (
            status: 200,
            body: reads < 4 ? _runningNow : recordedStatusArchived,
          );
        });
        final c = await opened();
        await c.checkStatus();

        expect(c.phase, CuratorRunPhase.checkedNothing);
        expect(c.hasOutput, isFalse);
        expect(c.canRunNow, isTrue);
        expect(endedCalls, 1);
      },
    );

    test(
      'an open read that fails leaves Run now off until Check status',
      () async {
        server.on('GET', _statusPath, 'no', status: 500);
        final c = await opened();

        expect(c.phase, CuratorRunPhase.unchecked);
        expect(c.canRunNow, isFalse);

        statuses([recordedStatusFinished]);
        await c.checkStatus();
        expect(c.canRunNow, isTrue);
      },
    );
  });

  group('result lifetime and profile', () {
    Future<CuratorController> finished() async {
      statuses([recordedStatusFinished, recordedStatusArchived]);
      final c = await opened();
      await confirm(c);
      expect(c.phase, CuratorRunPhase.finished);
      return c;
    }

    test('stays while the section is hidden by a search', () async {
      final c = await finished();

      c.searching = true;
      expect(c.visible, isFalse);
      c.searching = false;

      expect(c.visible, isTrue);
      expect(c.phase, CuratorRunPhase.finished);
      expect(c.hasOutput, isTrue);
    });

    test(
      'a profile switch drops the old result and reads the new profile',
      () async {
        final c = await finished();
        statuses([recordedStatusFinished]);
        server.requests.clear();

        c.switchProfile('demo-b');

        expect(c.hasOutput, isFalse);
        expect(c.outputLines, isEmpty);
        expect(c.status, isNull);
        await until(
          () => c.phase == CuratorRunPhase.idle && c.load == CuratorLoad.loaded,
        );
        expect(
          server.requests
              .where((r) => r.path == '/api/curator')
              .map((r) => r.queryParameters['profile']),
          ['demo-b'],
        );
      },
    );

    test('a profile switch cancels polling and ignores the old pass', () async {
      statuses([recordedStatusFinished, ...List.filled(5, _runningNow)]);
      final c = await opened();
      delayGate = Completer<void>();
      c.beginRun();
      final run = c.confirmRun();
      await until(() => delays.isNotEmpty);

      statuses([recordedStatusFinished]);
      c.switchProfile('demo-b');
      delayGate!.complete();
      await run;
      await pumpEventQueue();

      expect(c.phase, CuratorRunPhase.idle);
      expect(c.busy, isFalse);
      expect(c.profile, 'demo-b');
      expect(
        count('GET', _statusPath),
        3,
        reason: 'open, the read before the POST, then the new open',
      );
    });

    test('an old pause answer does not touch the new profile', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('PUT', '/api/curator/paused', (_) => gate.future);
      final pause = c.setPaused(true);
      c.switchProfile('demo-b');
      await until(() => c.load == CuratorLoad.loaded);
      gate.complete((status: 200, body: recordedPausedOn));
      await pause;

      expect(c.paused, isFalse);
      expect(c.pause, CuratorPause.idle);
    });
  });

  group('output', () {
    final noisy = _log([
      ...List<String>.from(recordedStatusNeverRun['lines']! as List),
      '',
      recordedRunHeader,
      'curator: skill\u202Eevil and \u001B[31mred\u001B[0m',
      for (var i = 0; i < 40; i++) 'line $i',
      'auto: checked=3 stale=0 archived=2 reactivated=0\r\n',
    ]);

    Future<CuratorController> ran() async {
      statuses([recordedStatusNeverRun, noisy]);
      final c = await opened();
      await confirm(c);
      return c;
    }

    test('shows cleaned display lines, the last 30', () async {
      final c = await ran();

      expect(c.outputLines, hasLength(30));
      expect(c.earlierLines, 12);
      expect(
        c.outputLines.last,
        'auto: checked=3 stale=0 archived=2 reactivated=0',
      );
      expect(c.outputLines.join(), isNot(contains('\u202E')));
      expect(c.outputLines.join(), isNot(contains('\u001B')));
    });

    test('control and bidi characters show visibly', () async {
      statuses([
        recordedStatusNeverRun,
        _log(['', recordedRunHeader, 'a\u202Eb \u001B[31mc']),
      ]);
      final c = await opened();
      await confirm(c);

      expect(c.outputLines.single, 'a<U+202E>b <U+001B>[31mc');
    });

    test('lock drops the lines and they do not come back', () async {
      final c = await ran();
      expect(c.hasOutput, isTrue);

      c.lock();
      expect(c.outputLines, isEmpty);
      expect(c.hasOutput, isFalse);
      expect(c.outputDropped, isTrue);
      c.unlocked();

      expect(c.outputLines, isEmpty);
      expect(c.hasOutput, isFalse);
      expect(c.phase, CuratorRunPhase.finished);
    });

    test('lines read while locked are never kept', () async {
      statuses([recordedStatusNeverRun, noisy]);
      final c = await opened();
      c.lock();
      await confirm(c);

      expect(c.phase, CuratorRunPhase.finished);
      expect(c.hasOutput, isFalse);
      expect(c.outputDropped, isTrue);
    });

    test('inactive hides the lines and shows them again', () async {
      final c = await ran();

      c.setInactive(true);
      expect(c.blanked, isTrue);
      expect(c.outputLines, isEmpty);
      c.setInactive(false);

      expect(c.outputLines, isNotEmpty);
    });
  });

  group('dispose', () {
    test('cancels polling and ends the span', () async {
      statuses([recordedStatusFinished, _runningNow]);
      final c = await opened();
      delayGate = Completer<void>();
      c.beginRun();
      final run = c.confirmRun();
      await until(() => delays.isNotEmpty);
      final before = count('GET', _statusPath);

      c.dispose();
      delayGate!.complete();
      await run;
      await pumpEventQueue();

      expect(count('GET', _statusPath), before);
      expect(tracer.spans.single.ended, isTrue);
      expect(tracer.spans.single.attributes['outcome'], 'unknown');
    });

    test('an answer after dispose does not notify', () async {
      final c = await opened();
      final gate = Completer<FakeResponse>();
      server.onRequest('PUT', '/api/curator/paused', (_) => gate.future);
      var notified = 0;
      c.addListener(() => notified++);
      final pause = c.setPaused(true);
      final seen = notified;
      c.dispose();
      gate.complete((status: 200, body: recordedPausedOn));
      await pause;

      expect(notified, seen);
    });

    test('the old State disposing leaves the new one alone', () async {
      final old = await opened();
      statuses([recordedStatusFinished, recordedStatusArchived]);
      final next = await opened();
      old.dispose();

      await confirm(next);

      expect(next.phase, CuratorRunPhase.finished);
      expect(next.hasOutput, isTrue);
    });
  });

  group('telemetry', () {
    test('a finished pass: span with outcome, event with archived', () async {
      statuses([recordedStatusFinished, _runningNow, recordedStatusArchived]);
      final c = await opened();
      await confirm(c);

      final span = tracer.spans.single;
      expect(span.name, 'skills_curator.run');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'outcome': 'done',
        'trigger_lost': false,
      });
      expect(span.ended, isTrue);
      expect(events.named('skills_curator.run_finished'), [
        {'outcome': 'done', 'archived': 1},
      ]);
      expect(crumbs.named('skills_curator.run.confirmed'), hasLength(1));
    });

    test('no archived line leaves the count out', () async {
      statuses([
        recordedStatusNeverRun,
        _log(['', recordedRunHeader, 'something reworded']),
      ]);
      final c = await opened();
      await confirm(c);

      expect(events.named('skills_curator.run_finished'), [
        {'outcome': 'done'},
      ]);
    });

    test('a refused start ends the span failed and logs no run', () async {
      server.on(
        'POST',
        '/api/curator/run',
        recordedRunSpawnFailed.body,
        status: recordedRunSpawnFailed.status,
      );
      final c = await opened();
      await confirm(c);

      expect(tracer.spans.single.attributes['outcome'], 'failed');
      expect(events.named('skills_curator.run_finished'), isEmpty);
    });
  });

  group('privacy', () {
    test('a marker in profile, skills and output reaches no sink', () async {
      final logged = <String>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (d) => logged.add('${d.exception} ${d.stack}');
      final oldPrint = debugPrint;
      debugPrint = (m, {wrapWidth}) => logged.add('$m');
      addTearDown(() {
        FlutterError.onError = oldOnError;
        debugPrint = oldPrint;
      });
      final profile = 'profile-$_marker';
      final lines = [
        '',
        '=== curator-run started 2026-11-15 03:50:00 ===',
        'curator: archived skill-$_marker',
        'auto: checked=1 stale=0 archived=1 reactivated=0',
      ];
      statuses([recordedStatusNeverRun, _log(lines)]);
      server
        ..on('GET', '/api/config', {
          'curator': {'consolidate': false, 'skill': _marker},
        })
        ..on('GET', '/api/curator', {
          ...recordedCuratorNeverRun,
          'note': _marker,
        });
      final c = await opened(profile: profile);
      await c.setPaused(true);
      await confirm(c);

      // Failure paths that carry the marker in server text.
      for (final failure in [
        (500, "Failed to run curator: 404: Profile '$_marker' does not exist."),
        (500, 'Failed to run curator: [Errno 21] Is a directory: /$_marker'),
        (400, "Profile '$_marker' invalid"),
      ]) {
        server.on('POST', '/api/curator/run', {
          'detail': failure.$2,
        }, status: failure.$1);
        statuses([recordedStatusNeverRun]);
        final d = await opened(profile: profile);
        await confirm(d);
      }
      server.on('PUT', '/api/curator/paused', {
        'detail': "Profile '$_marker' does not exist.",
      }, status: 404);
      await c.setPaused(false);

      final sinks = [
        ...logged,
        crumbs.text,
        for (final s in tracer.spans) ...[
          s.name,
          s.attributes.keys.join(' '),
          s.attributes.values.join(' '),
          s.eventDetails.join(' '),
          '${s.statusDescription}',
        ],
        for (final n in events.namesStartingWith('')) n,
        for (final n in events.namesStartingWith('skills_curator'))
          ...events.named(n).map((a) => '$a'),
      ].join('\n');
      expect(sinks, isNotEmpty);
      expect(sinks, isNot(contains(_marker)));
      expect(c.outputLines.join(), contains(_marker), reason: 'on screen only');
    });
  });
}

const _disabledHeader = '=== curator-run started 2026-11-15 03:38:11 ===';

List<String> _lines(Map<String, Object?> status) =>
    List<String>.from(status['lines']! as List);
