import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_chat_transport.dart';
import '../../support/recording_tracer.dart';

void main() {
  late FakeChatTransport transport;
  late SubagentRepository repository;
  final key = AgentKey(
    threadId: 'thread-1',
    profile: 'work',
    connection: Object(),
    subagentId: 'a1',
  );

  setUp(() {
    transport = FakeChatTransport();
    repository = SubagentRepository(transport);
  });

  group('parseAgentList', () {
    test('reads the server example', () {
      final list = parseAgentList({
        'subagents': [
          {
            'subagent_id': 'child',
            'parent_id': null,
            'depth': 1,
            'goal': 'owned task',
            'delegation_id': 'deleg-1',
            'model': 'test',
            'started_at': 1763120000.5,
            'status': 'running',
            'tool_count': 1,
            'last_tool': 'read_file',
            'accepting_steer': true,
          },
        ],
        'delegations': [],
      })!;
      final agent = list.agents.single;
      expect(agent.id, 'child');
      expect(agent.parentId, isNull);
      expect(agent.depth, 1);
      expect(agent.state, AgentState.running);
      expect(agent.toolCount, 1);
      expect(agent.lastTool, 'read_file');
      expect(agent.acceptingSteer, isTrue);
      expect(agent.startedAt!.millisecondsSinceEpoch, 1763120000500);
    });

    test('skips rows without an id and rows that are not maps', () {
      final list = parseAgentList({
        'subagents': [
          {'goal': 'no id'},
          'junk',
          {'subagent_id': '', 'goal': 'empty id'},
          {'subagent_id': 'ok'},
        ],
      })!;
      expect(list.agents.map((a) => a.id), ['ok']);
    });

    test('reads numbers as ints, doubles or numeric strings', () {
      final list = parseAgentList({
        'subagents': [
          {
            'subagent_id': 'a',
            'depth': '2',
            'tool_count': 3.0,
            'started_at': '1763120000',
          },
          {'subagent_id': 'b', 'depth': 'deep', 'tool_count': double.nan},
        ],
      })!;
      expect(list.agents[0].depth, 2);
      expect(list.agents[0].toolCount, 3);
      expect(list.agents[0].startedAt!.millisecondsSinceEpoch, 1763120000000);
      expect(list.agents[1].depth, isNull);
      expect(list.agents[1].toolCount, isNull);
    });

    test(
      'maps every status; an unknown one is ended, a missing one running',
      () {
        const expected = {
          'queued': AgentState.starting,
          'running': AgentState.running,
          'completed': AgentState.finished,
          'interrupted': AgentState.stopped,
          'failed': AgentState.failed,
          'error': AgentState.failed,
          'timeout': AgentState.failed,
          'paused_for_budget': AgentState.ended,
        };
        final list = parseAgentList({
          'subagents': [
            for (final status in expected.keys)
              {'subagent_id': status, 'status': status},
            {'subagent_id': 'none'},
          ],
        })!;
        for (final agent in list.agents) {
          expect(agent.state, expected[agent.id] ?? AgentState.running);
        }
      },
    );

    test('keys failed delegations by delegation id and task index', () {
      final list = parseAgentList({
        'subagents': [],
        'delegations': [
          {
            'delegation_id': 'd1',
            'task_index': '2',
            'status': 'failed',
            'goal': 'Audit',
            'error': 'boom',
            'dispatched_at': 10,
            'completed_at': 20.5,
          },
          {'delegation_id': 'd1'},
          {'task_index': 1},
        ],
      })!;
      final failed = list.delegations.single;
      expect(failed.key, 'd1#2');
      expect(failed.state, AgentState.failed);
      expect(failed.error, 'boom');
    });

    test(
      'a list that is not a list is malformed; unknown fields are ignored',
      () {
        expect(parseAgentList({'subagents': 'nope'}), isNull);
        expect(parseAgentList({'subagents': [], 'delegations': 4}), isNull);
        expect(parseAgentList({'extra': 1})!.agents, isEmpty);
      },
    );

    test('toString prints counts, not goals or ids', () {
      final list = parseAgentList({
        'subagents': [
          {'subagent_id': 'secret-id', 'goal': 'secret goal'},
        ],
      })!;
      expect('$list ${list.agents.single}', isNot(contains('secret')));
    });
  });

  group('parseAgentTail', () {
    test('reads the answer as is when it was not cut', () {
      final tail = parseAgentTail({
        'subagent_id': 'a1',
        'available': true,
        'text': 'one\ntwo',
        'truncated': false,
      })!;
      expect(tail.text, 'one\ntwo');
      expect(tail.available, isTrue);
    });

    test('drops the partial first line when the server truncated', () {
      final tail = parseAgentTail({
        'available': true,
        'text': 'rtial line\nwhole line\n',
        'truncated': true,
      })!;
      expect(tail.text, 'whole line\n');
    });

    test(
      'cuts to 16 KiB at a character boundary, without broken characters',
      () {
        // "é" is two bytes; an odd window start falls inside one.
        final text = '${'é' * 9000}\nlast line';
        final tail = parseAgentTail({
          'available': true,
          'text': text,
          'truncated': false,
        })!;
        expect(tail.truncated, isTrue);
        expect(tail.text, isNot(contains('�')));
        expect(
          utf8.encode(tail.text).length,
          lessThanOrEqualTo(kAgentTailBytes),
        );
        expect(tail.text, 'last line');
      },
    );

    test('a window that starts inside a multi-byte character loses no whole '
        'lines and shows no replacement', () {
      final line = '${'€' * 100}\n';
      final text = line * 400;
      final tail = parseAgentTail({
        'available': true,
        'text': text,
        'truncated': true,
      })!;
      expect(tail.text, isNot(contains('�')));
      expect(
        tail.text.split('\n').where((l) => l.isNotEmpty),
        everyElement('€' * 100),
      );
    });

    test('unavailable output is empty and available false', () {
      final tail = parseAgentTail({
        'available': false,
        'text': '',
        'truncated': false,
      })!;
      expect(tail.available, isFalse);
      expect(tail.text, isEmpty);
    });

    test('a wrong shape is null', () {
      expect(parseAgentTail({'text': 'x'}), isNull);
      expect(parseAgentTail({'available': true, 'text': 7}), isNull);
    });
  });

  group('outcomes', () {
    test('stop', () {
      expect(parseStopOutcome({'found': true}), StopOutcome.stopped);
      expect(parseStopOutcome({'found': false}), StopOutcome.alreadyEnded);
      expect(parseStopOutcome({'found': 'yes'}), isNull);
    });

    test('steer', () {
      expect(parseSteerOutcome({'status': 'queued'}), SteerOutcome.queued);
      expect(parseSteerOutcome({'status': 'rejected'}), SteerOutcome.rejected);
      expect(parseSteerOutcome({'status': 'maybe'}), isNull);
    });

    test('Hermes notices are matched by their full prefix only', () {
      expect(
        summaryShowsMissedNote(
          'Done. [steer did not land — the subagent finished before it could be '
          'delivered: note]',
        ),
        isTrue,
      );
      expect(summaryShowsMissedNote('the steer did not land'), isFalse);
      expect(
        errorShowsMissedNote(
          'timeout [steer did not land before the subagent stopped: note]',
        ),
        isTrue,
      );
      // The two forms are not interchangeable.
      expect(
        errorShowsMissedNote(
          '[steer did not land — the subagent finished before it could be '
          'delivered: x]',
        ),
        isFalse,
      );
      expect(summaryShowsMissedNote(null), isFalse);
    });
  });

  group('calls', () {
    test('list reads attached only and says so when not attached', () async {
      transport.agentSessionAttached = false;
      expect(
        await repository.list('thread-1', profile: 'work'),
        isA<WorkNotAttached<AgentList>>(),
      );
      expect(transport.agentReads, isEmpty);
    });

    test('list, tail, interrupt and steer send their method with the ids the '
        'key binds', () async {
      transport.agentAnswer = (call) => switch (call.method) {
        'subagent.list' => {'subagents': [], 'delegations': []},
        'subagent.tail' => {'available': true, 'text': 'x', 'truncated': false},
        'subagent.interrupt' => {'found': true},
        _ => {'status': 'queued'},
      };
      expect(await repository.list('thread-1', profile: 'work'), isA<WorkOk>());
      expect(await repository.tail(key), isA<WorkOk>());
      expect(
        (await repository.interrupt(key) as WorkOk).value,
        StopOutcome.stopped,
      );
      expect(
        (await repository.steer(key, '  Only Go modules \n') as WorkOk).value,
        SteerOutcome.queued,
      );
      expect(
        transport.agentReads.map(
          (c) => '${c.method} ${c.threadId} ${c.profile} ${c.params}',
        ),
        [
          'subagent.list thread-1 work {profile: work}',
          'subagent.tail thread-1 work {subagent_id: a1}',
        ],
      );
      expect(transport.agentActions.map((c) => '${c.method} ${c.params}'), [
        'subagent.interrupt {subagent_id: a1}',
        'subagent.steer {subagent_id: a1, text: Only Go modules}',
      ]);
    });

    test('a blank or too long note is refused without sending', () async {
      expect(await repository.steer(key, '  \n'), isA<WorkFailed>());
      expect(
        await repository.steer(key, 'x' * (kMaxNoteLength + 1)),
        isA<WorkFailed>(),
      );
      expect(transport.agentActions, isEmpty);
      transport.agentAnswer = (_) => {'status': 'queued'};
      // The 4,000 limit counts the trimmed text: padding does not count.
      expect(
        await repository.steer(key, '${' ' * 50}${'x' * kMaxNoteLength}  '),
        isA<WorkOk<SteerOutcome>>(),
      );
      expect(
        transport.agentActions.single.params['text'],
        hasLength(kMaxNoteLength),
      );
    });

    test('each error code reads as its kind', () async {
      Future<AgentWorkResult<StopOutcome>> stopWith(Object error) {
        transport.agentAnswer = (_) => Future.error(error);
        return repository.interrupt(key);
      }

      GatewayRpcException rpc(int code) => GatewayRpcException(code, 'x');
      for (final code in [4000, 4002, 4012]) {
        expect(
          (await stopWith(rpc(code)) as WorkFailed).kind,
          WorkFailureKind.rejected,
        );
      }
      for (final code in [4001, 4044]) {
        expect(
          (await stopWith(rpc(code)) as WorkFailed).kind,
          WorkFailureKind.notOwned,
        );
      }
      expect(
        (await stopWith(rpc(5032)) as WorkFailed).kind,
        WorkFailureKind.server,
      );
      expect(
        (await stopWith(rpc(1234)) as WorkFailed).kind,
        WorkFailureKind.other,
      );
      expect(
        await stopWith(rpc(kGatewayMethodNotFound)),
        isA<WorkUnsupported>(),
      );
      expect(await stopWith(const GatewayRequestTimeout()), isA<WorkLost>());
      expect(await stopWith(const GatewayConnectionClosed()), isA<WorkLost>());
      expect(await stopWith(TimeoutException('x')), isA<WorkLost>());
      expect(await stopWith(UnsupportedError('x')), isA<WorkUnsupported>());
      expect(await stopWith(StateError('x')), isA<WorkFailed>());
    });

    test('a lost answer is never resent by the repository', () async {
      transport.agentAnswer = (_) => throw const GatewayRequestTimeout();
      expect(await repository.interrupt(key), isA<WorkLost>());
      expect(await repository.steer(key, 'x'), isA<WorkLost>());
      expect(transport.agentActions, hasLength(2));
    });

    test('a malformed answer is a failure and never throws', () async {
      transport.agentAnswer = (_) => {'subagents': 'nope'};
      expect(await repository.list('thread-1'), isA<WorkFailed<AgentList>>());
      transport.agentAnswer = (_) => {'found': 'yes'};
      expect(await repository.interrupt(key), isA<WorkFailed>());
    });
  });

  group('span', () {
    test(
      'subagent.rpc carries only method, outcome and size buckets',
      () async {
        final tracer = RecordingTracer();
        repository = SubagentRepository(
          transport,
          telemetry: ConnectionTelemetry(
            tracer: tracer,
            serverAttributes: const {'hermes.version': '1'},
          ),
        );
        transport.agentAnswer = (call) => switch (call.method) {
          'subagent.list' => {
            'subagents': [
              {'subagent_id': 'secret-id', 'goal': 'secret goal'},
            ],
          },
          'subagent.tail' => {
            'available': true,
            'text': 'secret output',
            'truncated': false,
          },
          'subagent.interrupt' => throw const GatewayConnectionClosed(),
          _ => {'status': 'queued', 'text': 'secret note'},
        };
        await repository.list('secret-thread', profile: 'secret-profile');
        await repository.tail(key);
        await repository.interrupt(key);
        await repository.steer(key, 'secret note');
        expect([
          for (final s in tracer.spans) s.name,
        ], everyElement('subagent.rpc'));
        expect(
          [for (final s in tracer.spans) s.attributes['method']],
          ['list', 'tail', 'interrupt', 'steer'],
        );
        expect(
          [for (final s in tracer.spans) s.attributes['outcome']],
          ['ok', 'ok', 'lost', 'ok'],
        );
        expect(tracer.spans[0].attributes['rows'], '1-4');
        expect(tracer.spans[1].attributes['tail_kib'], '1-4');
        final allowed = {
          'method',
          'outcome',
          'rows',
          'tail_kib',
          'hermes.version',
        };
        for (final span in tracer.spans) {
          expect(span.attributes.keys.toSet().difference(allowed), isEmpty);
          expect(span.attributes.values.join(' '), isNot(contains('secret')));
          expect(span.ended, isTrue);
        }
      },
    );

    test('a tracer that throws does not break the call', () async {
      repository = SubagentRepository(
        transport,
        telemetry: ConnectionTelemetry(tracer: ThrowingTracer()),
      );
      transport.agentAnswer = (_) => {'found': true};
      expect(await repository.interrupt(key), isA<WorkOk>());
    });
  });
}
