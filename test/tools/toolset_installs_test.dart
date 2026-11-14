import 'dart:async';

import 'package:dio/dio.dart';
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

void main() {
  late FakeHermesServer server;
  late ToolsetInstalls installs;
  late RecordingTracer tracer;
  late List<String> events;
  late List<String?> rereads;

  ToolsetInstalls build({Duration patience = const Duration(seconds: 5)}) =>
      ToolsetInstalls(
        requestReread: rereads.add,
        interval: const Duration(milliseconds: 10),
        patience: patience,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
      );

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'timed out waiting');
  }

  /// Serves the given status answers in order, repeating the last one.
  void script(List<Map<String, Object?>> answers) {
    var i = 0;
    server.onRequest('GET', _status, (_) {
      final body = answers[i < answers.length ? i : answers.length - 1];
      i++;
      return (status: 200, body: body);
    });
  }

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

  test('an exit of 0 ends as succeeded and asks for a re-read, with the '
      'last six lines', () async {
    script([
      _log(running: true, lines: ['a']),
      _log(
        running: false,
        exit: 0,
        lines: [for (var i = 1; i <= 9; i++) 'line $i', '', '  '],
      ),
    ]);

    final started = await installs.startConfirmed(
      toolsRepository(server),
      'web',
      'local_driver',
    );
    await until(() => !installs.busy);

    expect(started, ToolsInstallStart.started);
    final state = installs.state!;
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

  test('a non-zero exit is failed and still asks for a re-read', () async {
    script([
      _log(running: false, exit: 3, lines: ['boom']),
    ]);

    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => !installs.busy);

    expect(installs.state!.phase, ToolsInstallPhase.failed);
    expect(installs.state!.exitCode, 3);
    expect(rereads, ['web']);
  });

  test('running:false with no exit code is unknown, never success', () async {
    script([_log(running: true), _log(running: false, exit: null)]);

    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => !installs.busy);

    expect(installs.state!.phase, ToolsInstallPhase.unknown);
    expect(rereads, ['web']);
  });

  test('another run replacing the slot is unknown', () async {
    script([
      _log(running: true, pid: 42),
      _log(running: false, exit: 0, pid: 99),
    ]);

    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => !installs.busy);

    expect(installs.state!.phase, ToolsInstallPhase.unknown);
  });

  test(
    '22 minutes (patience) without an end is unknown and re-reads',
    () async {
      installs.dispose();
      installs = build(patience: const Duration(milliseconds: 80));
      script([
        _log(running: true, lines: ['still going']),
      ]);

      await installs.startConfirmed(toolsRepository(server), 'web', 'k');
      await until(() => !installs.busy);

      expect(installs.state!.phase, ToolsInstallPhase.unknown);
      expect(rereads, ['web']);
      final polls = server.requestsTo('GET', _status).length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(server.requestsTo('GET', _status), hasLength(polls));
    },
  );

  test('the default patience is 22 minutes and the default poll 2 s', () {
    expect(kToolsActionPatience, const Duration(minutes: 22));
    expect(kToolsActionInterval, const Duration(seconds: 2));
  });

  test('a failed poll is not an end', () async {
    var n = 0;
    server.onRequest('GET', _status, (_) {
      n++;
      if (n < 3) return (status: 502, body: {'detail': 'x'});
      return (status: 200, body: _log(running: false, exit: 0));
    });

    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => !installs.busy);

    expect(installs.state!.phase, ToolsInstallPhase.succeeded);
  });

  test('a second start while one runs is refused and not sent', () async {
    script([_log(running: true)]);
    await installs.startConfirmed(toolsRepository(server), 'web', 'k');

    final second = await installs.startConfirmed(
      toolsRepository(server),
      'terminal',
      'other',
    );

    expect(second, ToolsInstallStart.busy);
    expect(server.requestsTo('POST', _start), hasLength(1));
    expect(installs.state!.toolset, 'web');
    expect(installs.followSwitchStarted(toolsRepository(server), 'x'), isFalse);
  });

  test('two starts at once send one request', () async {
    final gate = Completer<void>();
    server.onRequest('POST', _start, (_) async {
      await gate.future;
      return (status: 200, body: {'ok': true, 'pid': 42});
    });
    script([_log(running: true)]);

    final first = installs.startConfirmed(toolsRepository(server), 'web', 'k');
    final second = await installs.startConfirmed(
      toolsRepository(server),
      'web',
      'k',
    );
    gate.complete();

    expect(second, ToolsInstallStart.busy);
    expect(await first, ToolsInstallStart.started);
    expect(server.requestsTo('POST', _start), hasLength(1));
  });

  test('a refused key shows Hermes\' text and follows nothing', () async {
    server.on('POST', _start, {'detail': 'Unknown key'}, status: 400);

    final result = await installs.startConfirmed(
      toolsRepository(server),
      'web',
      'nope',
    );

    expect(result, ToolsInstallStart.refused);
    expect(installs.state!.phase, ToolsInstallPhase.refused);
    expect(installs.state!.detail, 'Unknown key');
    expect(server.requestsTo('GET', _status), isEmpty);
    expect(installs.busy, isFalse);
  });

  test('a failed start leaves nothing running', () async {
    server.on('POST', _start, {'detail': 'spawn'}, status: 500);

    final result = await installs.startConfirmed(
      toolsRepository(server),
      'web',
      'k',
    );

    expect(result, ToolsInstallStart.notStarted);
    expect(installs.state!.phase, ToolsInstallPhase.notStarted);
    expect(installs.busy, isFalse);
  });

  test(
    'a lost answer to the start is unknown, re-reads, and is not resent',
    () async {
      server.onRequest('POST', _start, (r) {
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        );
      });

      final result = await installs.startConfirmed(
        toolsRepository(server),
        'web',
        'k',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(result, ToolsInstallStart.unknown);
      expect(installs.state!.phase, ToolsInstallPhase.unknown);
      expect(rereads, ['web']);
      expect(server.requestsTo('POST', _start), hasLength(1));
      expect(installs.busy, isFalse);
    },
  );

  group('followSwitchStarted', () {
    test('follows read-only and ends in a re-read', () async {
      script([
        _log(running: true, pid: 7),
        _log(running: false, exit: 0, pid: 7),
      ]);

      final following = installs.followSwitchStarted(
        toolsRepository(server),
        'cua_driver',
        toolset: 'computer_use',
      );
      await until(() => !installs.busy);

      expect(following, isTrue);
      expect(installs.state!.switchStarted, isTrue);
      expect(installs.state!.phase, ToolsInstallPhase.succeeded);
      expect(rereads, ['computer_use']);
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    });

    test('an old finished log it never saw running is unknown', () async {
      script([_log(running: false, exit: 0, pid: 5)]);

      installs.followSwitchStarted(toolsRepository(server), 'cua_driver');
      await until(() => !installs.busy);

      expect(installs.state!.phase, ToolsInstallPhase.unknown);
      expect(rereads, [null]);
    });
  });

  test('it survives a screen: state is read from the object, not a '
      'controller', () async {
    script([
      _log(running: true, lines: ['one']),
    ]);
    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => installs.state!.lines.isNotEmpty);

    expect(installs.state!.lines, ['one']);
    expect(installs.busy, isTrue);
  });

  test('clear on sign-out stops polling and drops the state', () async {
    script([_log(running: true)]);
    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    await until(() => server.requestsTo('GET', _status).isNotEmpty);

    installs.clear();
    final polls = server.requestsTo('GET', _status).length;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(installs.state, isNull);
    expect(installs.busy, isFalse);
    expect(server.requestsTo('GET', _status), hasLength(polls));
    expect(rereads, isEmpty);
  });

  test('a start answer that arrives after clear is dropped', () async {
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
    installs.clear();
    gate.complete();
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(installs.state, isNull);
    expect(server.requestsTo('GET', _status), isEmpty);
  });

  test('dispose stops polling', () async {
    script([_log(running: true)]);
    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    installs.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final polls = server.requestsTo('GET', _status).length;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(server.requestsTo('GET', _status), hasLength(polls));
  });

  test('acknowledge drops an ended state but never a running one', () async {
    script([_log(running: true)]);
    await installs.startConfirmed(toolsRepository(server), 'web', 'k');
    installs.acknowledge();
    expect(installs.state, isNotNull);

    script([_log(running: false, exit: 0)]);
    await until(() => !installs.busy);
    installs.acknowledge();
    expect(installs.state, isNull);
  });

  test('telemetry carries the step and the outcome only', () async {
    script([
      _log(running: false, exit: 0, lines: ['secret log line SEKRET']),
    ]);

    await installs.startConfirmed(
      toolsRepository(server),
      'web',
      'local_driver',
    );
    await until(() => !installs.busy);

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
}
