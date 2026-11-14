import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/toolset_installs.dart';
import 'package:hermes_app/src/tools/tools_action_follower.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

const _start = '/api/tools/toolsets/web/post-setup';
const _status = '/api/actions/tools-post-setup/status';

Map<String, Object?> _log({
  required bool running,
  int? exit,
  int? pid = 42,
  List<String> lines = const [],
}) => {
  'name': 'tools-post-setup',
  'running': running,
  'exit_code': exit,
  'pid': pid,
  'lines': lines,
};

/// Moves the fake clock and lets every answer land.
void _advance(FakeAsync async, [Duration by = Duration.zero]) {
  async
    ..elapse(by)
    ..flushMicrotasks();
  _drain(async);
}

/// Dio schedules zero-length timers between its steps; run them and the
/// microtasks they free until nothing is left, without moving the clock.
void _drain(FakeAsync async) {
  for (var i = 0; i < 20; i++) {
    async
      ..elapse(Duration.zero)
      ..flushMicrotasks();
  }
}

R _settle<R>(FakeAsync async, Future<R> future) {
  R? value;
  var done = false;
  unawaited(
    future.then((v) {
      value = v;
      done = true;
    }),
  );
  _drain(async);
  expect(done, isTrue, reason: 'the call did not finish');
  return value as R;
}

void main() {
  late FakeHermesServer server;
  late ToolsetInstalls installs;
  late RecordingTracer tracer;
  late List<String> events;
  late List<String?> rereads;

  const poll = kToolsActionInterval;

  ToolsetInstalls build() => ToolsetInstalls(
    requestReread: rereads.add,
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      events: (name, [attributes = const {}]) =>
          events.add('$name $attributes'),
    ),
  );

  /// Serves the given status answers in order, repeating the last one.
  void script(List<Map<String, Object?>> answers) {
    var i = 0;
    server.onRequest('GET', _status, (_) {
      final body = answers[i < answers.length ? i : answers.length - 1];
      i++;
      return (status: 200, body: body);
    });
  }

  void failReads() => server.onRequest(
    'GET',
    _status,
    (_) => (status: 502, body: {'detail': 'x'}),
  );

  int polls() => server.requestsTo('GET', _status).length;

  ToolsInstallStart start(FakeAsync async, {String key = 'local_driver'}) =>
      _settle(
        async,
        installs.startConfirmed(toolsRepository(server), 'web', key),
      );

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', _start, {
        'ok': true,
        'pid': 42,
        'name': 'tools-post-setup',
        'key': 'local_driver',
      });
    tracer = RecordingTracer();
    events = [];
    rereads = [];
    installs = build();
  });

  tearDown(() => installs.dispose());

  test('the defaults are 22 minutes and 2 seconds', () {
    expect(kToolsActionPatience, const Duration(minutes: 22));
    expect(kToolsActionInterval, const Duration(seconds: 2));
  });

  test('an exit of 0 ends as succeeded and asks for a re-read, with the '
      'last six lines', () {
    fakeAsync((async) {
      script([
        _log(running: true, lines: ['a']),
        _log(
          running: false,
          exit: 0,
          lines: [for (var i = 1; i <= 9; i++) 'line $i', '', '  '],
        ),
      ]);

      expect(start(async), ToolsInstallStart.started);
      expect(installs.busy, isTrue);
      _advance(async, poll);

      final state = installs.state!;
      expect(installs.busy, isFalse);
      expect(state.phase, ToolsInstallPhase.succeeded);
      expect(state.exitCode, 0);
      expect(state.lines, [
        'line 4',
        'line 5',
        'line 6',
        'line 7',
        'line 8',
        'line 9',
      ]);
      expect(rereads, ['web']);
      expect(
        server.requestsTo('POST', _start).single.data,
        contains('local_driver'),
      );
    });
  });

  test('a non-zero exit is failed and still asks for a re-read', () {
    fakeAsync((async) {
      script([
        _log(running: false, exit: 3, lines: ['boom']),
      ]);

      start(async);

      expect(installs.state!.phase, ToolsInstallPhase.failed);
      expect(installs.state!.exitCode, 3);
      expect(rereads, ['web']);
    });
  });

  test('running:false with no exit code is unknown, never success', () {
    fakeAsync((async) {
      script([_log(running: true), _log(running: false, exit: null)]);

      start(async);
      _advance(async, poll);

      expect(installs.state!.phase, ToolsInstallPhase.unknown);
      expect(rereads, ['web']);
    });
  });

  test('another run replacing the slot is unknown', () {
    fakeAsync((async) {
      script([_log(running: true), _log(running: false, exit: 0, pid: 99)]);

      start(async);
      _advance(async, poll);

      expect(installs.state!.phase, ToolsInstallPhase.unknown);
    });
  });

  group('a log that is not this run\'s', () {
    test('a start with no pid is not ended by an earlier run\'s finished '
        'log', () {
      fakeAsync((async) {
        server.on('POST', _start, {'ok': true});
        script([
          _log(running: false, exit: 0, pid: 99, lines: ['old']),
        ]);

        start(async);

        expect(installs.state!.phase, ToolsInstallPhase.unknown);
        expect(installs.state!.phase, isNot(ToolsInstallPhase.succeeded));
        expect(rereads, ['web']);
      });
    });

    test('a start with no pid ends only after the run was seen running', () {
      fakeAsync((async) {
        server.on('POST', _start, {'ok': true});
        script([
          _log(running: true, pid: 8),
          _log(running: false, exit: 0, pid: 8),
        ]);

        start(async);
        _advance(async, poll);

        expect(installs.state!.phase, ToolsInstallPhase.succeeded);
      });
    });

    test('a known pid and a finished log without a pid is unknown', () {
      fakeAsync((async) {
        script([_log(running: false, exit: 0, pid: null)]);

        start(async);

        expect(installs.state!.phase, ToolsInstallPhase.unknown);
      });
    });

    test('a known pid and a finished log with another pid is unknown', () {
      fakeAsync((async) {
        script([_log(running: false, exit: 0, pid: 7)]);

        start(async);

        expect(installs.state!.phase, ToolsInstallPhase.unknown);
      });
    });
  });

  test('22 minutes without an end is unknown and re-reads; polling stops', () {
    fakeAsync((async) {
      script([
        _log(running: true, lines: ['still going']),
      ]);

      start(async);
      _advance(async, const Duration(minutes: 21, seconds: 50));
      expect(installs.busy, isTrue);
      _advance(async, const Duration(seconds: 10));

      expect(installs.state!.phase, ToolsInstallPhase.unknown);
      expect(rereads, ['web']);
      final seen = polls();
      _advance(async, const Duration(minutes: 5));
      expect(polls(), seen);
    });
  });

  group('failed reads of the status', () {
    test('back off 2 s then 4 s, say so, and recover', () {
      fakeAsync((async) {
        var n = 0;
        server.onRequest('GET', _status, (_) {
          n++;
          return n <= 2
              ? (status: 502, body: {'detail': 'x'})
              : (status: 200, body: _log(running: true, lines: ['back']));
        });

        start(async);
        expect(polls(), 1);
        expect(installs.state!.followFailing, isTrue);
        expect(installs.busy, isTrue);

        _advance(async, const Duration(seconds: 1));
        expect(polls(), 1);
        _advance(async, const Duration(seconds: 1));
        expect(polls(), 2);
        _advance(async, const Duration(seconds: 3));
        expect(polls(), 2, reason: 'the second wait is 4 s');
        _advance(async, const Duration(seconds: 1));

        expect(polls(), 3);
        expect(installs.state!.followFailing, isFalse);
        expect(installs.state!.lines, ['back']);
        expect(rereads, isEmpty);
      });
    });

    test('three in a row end as unknown, ask for a re-read, and can be '
        'checked again', () {
      fakeAsync((async) {
        failReads();

        start(async);
        _advance(async, const Duration(seconds: 2));
        _advance(async, const Duration(seconds: 4));

        final state = installs.state!;
        expect(polls(), 3);
        expect(state.phase, ToolsInstallPhase.unknown);
        expect(state.followLost, isTrue);
        expect(installs.busy, isFalse);
        expect(rereads, ['web']);

        script([_log(running: false, exit: 0)]);
        expect(installs.checkAgain(), isTrue);
        _advance(async);

        expect(installs.state!.phase, ToolsInstallPhase.succeeded);
        expect(installs.state!.followLost, isFalse);
        expect(rereads, ['web', 'web']);
        expect(installs.checkAgain(), isFalse);
      });
    });

    test('checkAgain does nothing when the follow did not give up', () {
      fakeAsync((async) {
        script([_log(running: true)]);
        start(async);

        expect(installs.checkAgain(), isFalse);
      });
    });
  });

  test('a second start while one runs is refused and not sent', () {
    fakeAsync((async) {
      script([_log(running: true)]);
      start(async);

      final second = _settle(
        async,
        installs.startConfirmed(toolsRepository(server), 'terminal', 'other'),
      );

      expect(second, ToolsInstallStart.busy);
      expect(server.requestsTo('POST', _start), hasLength(1));
      expect(installs.state!.toolset, 'web');
      expect(
        installs.followSwitchStarted(toolsRepository(server), 'x'),
        isFalse,
      );
    });
  });

  test('two starts at once send one request', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      server.onRequest('POST', _start, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'pid': 42});
      });
      script([_log(running: true)]);

      final first = installs.startConfirmed(
        toolsRepository(server),
        'web',
        'k',
      );
      final second = _settle(
        async,
        installs.startConfirmed(toolsRepository(server), 'web', 'k'),
      );
      gate.complete();
      final firstResult = _settle(async, first);

      expect(second, ToolsInstallStart.busy);
      expect(firstResult, ToolsInstallStart.started);
      expect(server.requestsTo('POST', _start), hasLength(1));
    });
  });

  test('a refused key shows Hermes\' text and follows nothing', () {
    fakeAsync((async) {
      server.on('POST', _start, {'detail': 'Unknown key'}, status: 400);

      final result = start(async, key: 'nope');

      expect(result, ToolsInstallStart.refused);
      expect(installs.state!.phase, ToolsInstallPhase.refused);
      expect(installs.state!.detail, 'Unknown key');
      expect(polls(), 0);
      expect(installs.busy, isFalse);
    });
  });

  test('a failed start leaves nothing running', () {
    fakeAsync((async) {
      server.on('POST', _start, {'detail': 'spawn'}, status: 500);

      final result = start(async);

      expect(result, ToolsInstallStart.notStarted);
      expect(installs.state!.phase, ToolsInstallPhase.notStarted);
      expect(installs.busy, isFalse);
    });
  });

  group('a lost answer to the start', () {
    void lose() => server.onRequest('POST', _start, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });

    test('keeps the slot busy, follows read-only and refuses a second '
        'start', () {
      fakeAsync((async) {
        lose();
        script([_log(running: true, pid: 8)]);

        final result = start(async);
        final second = _settle(
          async,
          installs.startConfirmed(toolsRepository(server), 'web', 'k'),
        );

        expect(result, ToolsInstallStart.unknown);
        expect(installs.busy, isTrue);
        expect(installs.state!.startLost, isTrue);
        expect(second, ToolsInstallStart.busy);
        expect(server.requestsTo('POST', _start), hasLength(1));
        expect(polls(), 1);
      });
    });

    test('an earlier run\'s finished log does not end it; the run seen '
        'running does', () {
      fakeAsync((async) {
        lose();
        script([
          _log(running: false, exit: 0, pid: 99, lines: ['old']),
          _log(running: true, pid: 8),
          _log(running: false, exit: 0, pid: 8),
        ]);

        start(async);
        expect(installs.busy, isTrue);
        _advance(async, poll);
        expect(installs.busy, isTrue);
        expect(rereads, isEmpty);
        _advance(async, poll);

        expect(installs.state!.phase, ToolsInstallPhase.succeeded);
        expect(rereads, ['web']);
      });
    });

    test('patience ends it as unknown with a re-read', () {
      fakeAsync((async) {
        lose();
        script([_log(running: true, pid: 8)]);

        start(async);
        _advance(async, kToolsActionPatience);

        expect(installs.busy, isFalse);
        expect(installs.state!.phase, ToolsInstallPhase.unknown);
        expect(rereads, ['web']);
      });
    });
  });

  group('followSwitchStarted', () {
    test('follows read-only and ends in a re-read', () {
      fakeAsync((async) {
        script([
          _log(running: true, pid: 7),
          _log(running: false, exit: 0, pid: 7),
        ]);

        final following = installs.followSwitchStarted(
          toolsRepository(server),
          'cua_driver',
          toolset: 'computer_use',
        );
        _advance(async, poll);

        expect(following, isTrue);
        expect(installs.state!.switchStarted, isTrue);
        expect(installs.state!.phase, ToolsInstallPhase.succeeded);
        expect(rereads, ['computer_use']);
        expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
      });
    });

    test('an old finished log it never saw running is unknown', () {
      fakeAsync((async) {
        script([_log(running: false, exit: 0, pid: 5)]);

        installs.followSwitchStarted(toolsRepository(server), 'cua_driver');
        _advance(async);

        expect(installs.state!.phase, ToolsInstallPhase.unknown);
        expect(rereads, [null]);
      });
    });
  });

  test('it survives a screen: state is read from the object', () {
    fakeAsync((async) {
      script([
        _log(running: true, lines: ['one']),
      ]);
      start(async);

      expect(installs.state!.lines, ['one']);
      expect(installs.busy, isTrue);
    });
  });

  test('clear on sign-out stops polling, drops the state and records the '
      'span as unknown', () {
    fakeAsync((async) {
      script([_log(running: true)]);
      start(async);

      installs.clear();
      final seen = polls();
      _advance(async, const Duration(minutes: 1));

      expect(installs.state, isNull);
      expect(installs.busy, isFalse);
      expect(polls(), seen);
      expect(rereads, isEmpty);
      final span = tracer.spans.singleWhere((s) => s.name == 'tools.setup');
      expect(span.attributes['outcome'], 'unknown');
      expect(span.ended, isTrue);
      expect(events, [
        'tools.setup_outcome {step: post_setup, outcome: unknown}',
      ]);
    });
  });

  test('a start answer that arrives after clear is dropped', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      server.onRequest('POST', _start, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'pid': 42});
      });
      script([_log(running: true)]);
      final pending = installs.startConfirmed(
        toolsRepository(server),
        'web',
        'k',
      );
      async.flushMicrotasks();
      installs.clear();
      gate.complete();
      final result = _settle(async, pending);
      _advance(async, poll);

      expect(result, ToolsInstallStart.dropped);
      expect(installs.state, isNull);
      expect(polls(), 0);
    });
  });

  test('dispose stops polling and later starts are dropped', () {
    fakeAsync((async) {
      script([_log(running: true)]);
      start(async);
      installs.dispose();
      final seen = polls();
      _advance(async, const Duration(minutes: 1));

      expect(polls(), seen);
      expect(start(async), ToolsInstallStart.dropped);
    });
  });

  test('acknowledge drops an ended state but never a running one', () {
    fakeAsync((async) {
      script([_log(running: true), _log(running: false, exit: 0)]);
      start(async);
      installs.acknowledge();
      expect(installs.state, isNotNull);

      _advance(async, poll);
      installs.acknowledge();
      expect(installs.state, isNull);
    });
  });

  test('telemetry carries the step and the outcome only', () {
    fakeAsync((async) {
      script([
        _log(running: false, exit: 0, lines: ['secret log line SEKRET']),
      ]);

      start(async);

      final span = tracer.spans.singleWhere((s) => s.name == 'tools.setup');
      expect(span.attributes['step'], 'post_setup');
      expect(span.attributes['outcome'], 'ok');
      expect(span.ended, isTrue);
      expect(events, ['tools.setup_outcome {step: post_setup, outcome: ok}']);
      final recorded = [
        for (final s in tracer.spans) '${s.name} ${s.attributes}',
        ...events,
        installs.toString(),
      ].join('\n');
      for (final leak in ['SEKRET', 'local_driver', 'web', 'work']) {
        expect(recorded, isNot(contains(leak)));
      }
    });
  });
}
