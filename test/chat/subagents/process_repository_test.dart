import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_chat_transport.dart';
import '../../support/recording_tracer.dart';
import 'process_fixtures.dart';

void main() {
  late FakeChatTransport transport;
  late SubagentRepository repository;

  setUp(() {
    transport = FakeChatTransport();
    repository = SubagentRepository(transport);
  });

  group('parseProcessList', () {
    test('reads the fixture rows', () {
      final list = parseProcessList(processListAnswer)!;
      expect(list.processes.map((p) => p.id), [
        'proc_ab12',
        'proc_k1',
        'proc_e1',
      ]);
      final running = list.processes[0];
      expect(running.command, 'npm test');
      expect(running.running, isTrue);
      expect(running.status, ProgramStatus.running);
      expect(running.uptime, const Duration(seconds: 42));
      expect(running.outputTail, 'PASS src/a.test.js\n');
      expect(running.exitCode, isNull);

      final killed = list.processes[1];
      expect(killed.status, ProgramStatus.stopped);
      expect(killed.exitCode, -15);
      expect(killed.completionReason, 'killed');

      final exited = list.processes[2];
      expect(exited.status, ProgramStatus.exited);
      expect(exited.exitCode, 2);
    });

    test('skips rows without an id and rows that are not maps', () {
      final list = parseProcessList({
        'processes': [
          {'command': 'no id'},
          'junk',
          {'session_id': '', 'command': 'empty id'},
          {'session_id': 7},
          {'session_id': 'ok'},
        ],
      })!;
      expect(list.processes.map((p) => p.id), ['ok']);
      // A row without a status is a running one, as the schema's default.
      expect(list.processes.single.running, isTrue);
    });

    test('reads numbers as ints, doubles or numeric strings', () {
      final list = parseProcessList({
        'processes': [
          {
            'session_id': 'a',
            'status': 'exited',
            'exit_code': '3',
            'uptime_seconds': 4.6,
          },
          {
            'session_id': 'b',
            'status': 'exited',
            'exit_code': 0.0,
            'uptime_seconds': '9',
          },
          {'session_id': 'c', 'uptime_seconds': -5, 'exit_code': 'nope'},
        ],
      })!;
      expect(list.processes[0].exitCode, 3);
      expect(list.processes[0].uptime, const Duration(seconds: 4));
      expect(list.processes[1].exitCode, 0);
      expect(list.processes[1].uptime, const Duration(seconds: 9));
      expect(list.processes[2].exitCode, isNull);
      expect(list.processes[2].uptime, Duration.zero);
    });

    test('maps every status: running, killed, exited with and without a '
        'code, and anything unknown as ended', () {
      ProgramStatus of(Map<String, Object?> row) => parseProcessList({
        'processes': [
          {'session_id': 'x', ...row},
        ],
      })!.processes.single.status;
      expect(of({'status': 'running'}), ProgramStatus.running);
      expect(
        of({'status': 'exited', 'completion_reason': 'killed'}),
        ProgramStatus.stopped,
      );
      expect(
        of({'status': 'exited', 'completion_reason': 'killed', 'exit_code': 0}),
        ProgramStatus.stopped,
        reason: 'killed wins whatever the code',
      );
      expect(of({'status': 'exited', 'exit_code': 0}), ProgramStatus.exited);
      expect(of({'status': 'exited'}), ProgramStatus.ended);
      expect(of({'status': 'zombie'}), ProgramStatus.ended);
      expect(
        of({'status': 'zombie', 'exit_code': 1}),
        ProgramStatus.ended,
        reason: 'an unknown status never reads as a clean exit',
      );
      expect(of({'status': 'zombie', 'exit_code': 0}), ProgramStatus.ended);
    });

    test('keeps the command as given', () {
      final long = 'x' * 200;
      final list = parseProcessList({
        'processes': [
          {'session_id': 'a', 'command': long},
          {'session_id': 'b', 'command': ''},
        ],
      })!;
      expect(list.processes[0].command, long);
      expect(list.processes[1].command, isNull);
    });

    test('an answer without its processes is not an empty list', () {
      expect(parseProcessList({}), isNull);
      expect(parseProcessList({'processes': 'nope'}), isNull);
      expect(parseProcessList({'processes': []})!.processes, isEmpty);
    });

    test('toString prints counts, not commands, output or ids', () {
      final list = parseProcessList(processListAnswer)!;
      final text = '$list ${list.processes.join(' ')}';
      for (final secret in ['npm', 'proc_', 'PASS', '/repo']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  group('parseProcessKill', () {
    test('mirrors the four statuses', () {
      expect(parseProcessKill(killKilled)!.outcome, KillOutcome.killed);
      expect(
        parseProcessKill(killAlreadyExited)!.outcome,
        KillOutcome.alreadyExited,
      );
      expect(parseProcessKill(killNotFound)!.outcome, KillOutcome.notFound);
      expect(parseProcessKill(killError)!.outcome, KillOutcome.error);
      expect(parseProcessKill({'status': 'maybe'}), isNull);
      expect(parseProcessKill({}), isNull);
    });

    test('reads the code, reason, output and the cut flag', () {
      final killed = parseProcessKill(killKilled)!;
      expect(killed.exitCode, -15);
      expect(killed.completionReason, 'killed');
      expect(killed.output, 'PASS src/a.test.js\n');
      expect(killed.outputCut, isFalse);
      expect(
        parseProcessKill({...killKilled, 'output_cut': true})!.outputCut,
        isTrue,
      );
      expect(
        parseProcessKill({...killKilled, 'output_cut': 1200})!.outputCut,
        isTrue,
      );
      expect(
        parseProcessKill({...killKilled, 'output_cut': 0})!.outputCut,
        isFalse,
      );
      expect(parseProcessKill(killKilled).toString(), isNot(contains('PASS')));
    });
  });

  group('calls', () {
    test(
      'process.list reads attached only and says so when not attached',
      () async {
        transport.agentSessionAttached = false;
        expect(
          await repository.processList('thread-1', profile: 'work'),
          isA<WorkNotAttached<ProcessList>>(),
        );
        expect(transport.agentReads, isEmpty);
        expect(transport.agentActions, isEmpty);
      },
    );

    test('process.list and process.kill send their method with the ids the '
        'caller names', () async {
      transport.agentAnswer = (call) => switch (call.method) {
        'process.list' => processListAnswer,
        _ => killKilled,
      };
      final list = await repository.processList('thread-1', profile: 'work');
      expect((list as WorkOk<ProcessList>).value.processes, hasLength(3));
      final kill = await repository.processKill(
        'thread-1',
        'proc_ab12',
        profile: 'work',
      );
      expect((kill as WorkOk<ProcessKill>).value.outcome, KillOutcome.killed);
      final read = transport.agentReads.single;
      expect(read.method, 'process.list');
      expect(read.threadId, 'thread-1');
      expect(read.profile, 'work');
      final action = transport.agentActions.single;
      expect(action.method, 'process.kill');
      expect(action.params['process_id'], 'proc_ab12');
      expect(action.profile, 'work');
    });

    test('each error code reads as its kind', () async {
      Future<AgentWorkResult<ProcessList>> listThrowing(Exception error) {
        transport.agentAnswer = (_) => throw error;
        return repository.processList('t');
      }

      expect(
        await listThrowing(
          const GatewayRpcException(kGatewayMethodNotFound, 'x'),
        ),
        isA<WorkUnsupported<ProcessList>>(),
      );
      expect(
        await listThrowing(const GatewayRpcException(kSessionNotOwned, 'x')),
        isA<WorkFailed<ProcessList>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.notOwned,
        ),
      );
      for (final code in [kAgentStillStarting, kListBodyError]) {
        expect(
          await listThrowing(GatewayRpcException(code, 'x')),
          isA<WorkFailed<ProcessList>>().having(
            (f) => f.kind,
            'kind',
            WorkFailureKind.server,
          ),
          reason: '$code',
        );
      }
      expect(
        await listThrowing(const GatewayRequestTimeout()),
        isA<WorkLost<ProcessList>>(),
      );

      Future<AgentWorkResult<ProcessKill>> killThrowing(Exception error) {
        transport.agentAnswer = (_) => throw error;
        return repository.processKill('t', 'p');
      }

      final notFound = await killThrowing(
        const GatewayRpcException(kNoSuchProcess, 'no such process'),
      );
      expect(
        (notFound as WorkOk<ProcessKill>).value.outcome,
        KillOutcome.notFound,
      );
      expect(
        await killThrowing(const GatewayRpcException(kSessionNotOwned, 'x')),
        isA<WorkFailed<ProcessKill>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.notOwned,
        ),
      );
      expect(
        await killThrowing(
          const GatewayRpcException(kGatewayMethodNotFound, 'x'),
        ),
        isA<WorkUnsupported<ProcessKill>>(),
      );
      expect(
        await killThrowing(const GatewayRequestTimeout()),
        isA<WorkLost<ProcessKill>>(),
      );
      expect(
        await killThrowing(const GatewayConnectionClosed()),
        isA<WorkLost<ProcessKill>>(),
      );
    });

    test('a lost kill is never resent by the repository', () async {
      transport.agentAnswer = (_) => throw const GatewayRequestTimeout();
      await repository.processKill('t', 'p');
      expect(transport.agentActions, hasLength(1));
    });

    test('random and truncated JSON never throws', () async {
      final random = Random(6);
      Object? junk(int depth) => switch (random.nextInt(depth > 2 ? 5 : 8)) {
        0 => null,
        1 => random.nextInt(1 << 20) - 1000,
        2 => random.nextDouble() * 1e6,
        3 => String.fromCharCodes([
          for (var i = 0; i < random.nextInt(30); i++) random.nextInt(0x2FFF),
        ]),
        4 => random.nextBool(),
        5 => [for (var i = 0; i < random.nextInt(5); i++) junk(depth + 1)],
        _ => {
          for (final key in [
            'processes',
            'session_id',
            'status',
            'exit_code',
            'uptime_seconds',
            'output_tail',
            'command',
            'completion_reason',
            'output',
            'output_cut',
          ])
            if (random.nextBool()) key: junk(depth + 1),
        },
      };
      for (var i = 0; i < 500; i++) {
        final value = junk(0);
        final map = value is Map
            ? value.cast<String, Object?>()
            : {'processes': value};
        parseProcessList(map);
        parseProcessKill(map);
      }
      final whole = jsonEncode(processListAnswer);
      for (var cut = 0; cut < whole.length; cut += 7) {
        Object? decoded;
        try {
          decoded = jsonDecode(whole.substring(0, cut));
        } on FormatException {
          continue;
        }
        if (decoded is Map) parseProcessList(decoded.cast());
      }
      transport.agentAnswer = (_) => {'processes': 'nope'};
      expect(await repository.processList('t'), isA<WorkFailed<ProcessList>>());
      transport.agentAnswer = (_) => {'status': 3};
      expect(
        await repository.processKill('t', 'p'),
        isA<WorkFailed<ProcessKill>>(),
      );
    });
  });

  group('span', () {
    test('subagent.rpc names the program methods and carries no command, '
        'output or id', () async {
      final tracer = RecordingTracer();
      repository = SubagentRepository(
        transport,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          serverAttributes: const {'hermes.version': '1'},
        ),
      );
      transport.agentAnswer = (call) => switch (call.method) {
        'process.list' => {
          'processes': [
            {
              'session_id': 'secret-proc',
              'command': 'secret-command --token=secret',
              'output_tail': 'secret output',
              'cwd': '/secret/path',
            },
          ],
        },
        _ => throw const GatewayRpcException(kNoSuchProcess, 'secret'),
      };
      await repository.processList('secret-thread', profile: 'secret-profile');
      await repository.processKill(
        'secret-thread',
        'secret-proc',
        profile: 'secret-profile',
      );
      expect([
        for (final s in tracer.spans) s.name,
      ], everyElement('subagent.rpc'));
      expect(
        [for (final s in tracer.spans) s.attributes['method']],
        ['process_list', 'process_kill'],
      );
      expect(
        [for (final s in tracer.spans) s.attributes['outcome']],
        ['ok', 'not_owned'],
      );
      expect(tracer.spans[0].attributes['rows'], '1-4');
      for (final span in tracer.spans) {
        expect(
          span.attributes.keys.toSet().difference({
            'method',
            'outcome',
            'rows',
            'hermes.version',
          }),
          isEmpty,
        );
        expect(span.attributes.values.join(' '), isNot(contains('secret')));
        expect(span.ended, isTrue);
      }
    });
  });
}
