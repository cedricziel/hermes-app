import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';

import '../../support/fake_chat_transport.dart';
import 'process_fixtures.dart';
import 'subagent_fixtures.dart';

/// The answers recorded from a real Hermes (`kSubagentFixturesRevision`) read
/// the way the app reads them. Every expectation names a value that was in
/// the recorded answer, so a parser that dropped it would fail here.
void main() {
  group('subagent.list', () {
    test('two running children of one delegation', () {
      final list = parseAgentList(listRunning)!;
      expect(list.agents.map((a) => a.id), [kAgentApples, kAgentPears]);
      expect(list.delegations, isEmpty);
      for (final agent in list.agents) {
        expect(agent.state, AgentState.running);
        expect(agent.parentId, isNull);
        expect(agent.depth, 0);
        expect(agent.delegationId, kDelegationId);
        expect(agent.toolCount, 1);
        expect(agent.lastTool, 'terminal');
        expect(agent.acceptingSteer, isTrue);
        expect(agent.startedAt, isNotNull);
        expect(agent.goal, startsWith('Count the '));
      }
    });

    test('an interrupted child is a delegation row that reads as stopped', () {
      final list = parseAgentList(listInterruptedDelegation)!;
      expect(list.agents, isEmpty);
      final row = list.delegations.single;
      expect(row.key, '$kDelegationId#1');
      expect(row.state, AgentState.stopped);
      expect(row.error, isNull);
      expect(row.goal, 'Count the pears in the demo crate');
      expect(row.dispatchedAt, isNotNull);
      expect(row.completedAt, isNotNull);
    });

    test('a failed child is a failed delegation with the provider text', () {
      final row = parseAgentList(listFailedDelegation)!.delegations.single;
      expect(row.state, AgentState.failed);
      expect(row.error, 'HTTP 400: model request rejected');
      // The error of this kind of failure has no missed-note notice; the
      // frame's summary has it (see completeFailedWithMissedNote).
      expect(errorShowsMissedNote(row.error), isFalse);
    });

    test('lists with no rows are lists, not failures', () {
      expect(parseAgentList(listEmpty)!.agents, isEmpty);
      expect(
        parseAgentList(listAfterInterrupt)!.agents.single.id,
        kAgentApples,
      );
    });
  });

  group('subagent.tail', () {
    test('running: header and lines, not truncated', () {
      final tail = parseAgentTail(tailRunning)!;
      expect(tail.available, isTrue);
      expect(tail.truncated, isFalse);
      expect(tail.text, startsWith('=== Hermes subagent live transcript ==='));
      expect(tail.text, contains('tool     | -> terminal(sleep 30)'));
    });

    test('after the tool batch a result line follows', () {
      final tail = parseAgentTail(tailAfterToolBatch)!;
      expect(tail.text, matches(RegExp(r'result\s+\|')));
    });

    test('an ended agent is unavailable with no text', () {
      final tail = parseAgentTail(tailUnavailable)!;
      expect(tail.available, isFalse);
      expect(tail.text, isEmpty);
      expect(tail.truncated, isFalse);
    });

    test('a truncated tail drops its partial first line', () {
      final answer = tailTruncatedAnswer();
      final raw = answer['text']! as String;
      expect(raw.length, 16384);
      final tail = parseAgentTail(answer)!;
      expect(tail.truncated, isTrue);
      expect(tail.text.length, lessThan(raw.length));
      // What is kept starts at a line start Hermes wrote.
      expect(tail.text, matches(RegExp(r'^12:20:00 (tool|result) ')));
      expect(raw.endsWith(tail.text), isTrue);
    });
  });

  group('subagent.interrupt and subagent.steer', () {
    test('found true and false', () {
      expect(parseStopOutcome(interruptFound), StopOutcome.stopped);
      expect(parseStopOutcome(interruptNotFound), StopOutcome.alreadyEnded);
    });

    test('queued and rejected', () {
      expect(parseSteerOutcome(steerQueued), SteerOutcome.queued);
      expect(parseSteerOutcome(steerRejected), SteerOutcome.rejected);
    });
  });

  group('errors read as their kind', () {
    late FakeChatTransport transport;
    late SubagentRepository repository;
    final key = AgentKey(
      threadId: 't',
      profile: null,
      connection: Object(),
      subagentId: kAgentApples,
    );

    setUp(() {
      transport = FakeChatTransport();
      repository = SubagentRepository(transport);
    });

    GatewayRpcException error(Map<String, Object?> e) =>
        GatewayRpcException(e['code']! as int, e['message']! as String);

    test('4001 on a read is not owned', () async {
      transport.agentAnswer = (_) => throw error(errorNotOwned);
      expect(
        await repository.list('t'),
        isA<WorkFailed<AgentList>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.notOwned,
        ),
      );
      expect(
        await repository.tail(key),
        isA<WorkFailed<AgentTail>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.notOwned,
        ),
      );
    });

    test('4000 and 4002 are rejected requests', () async {
      for (final recorded in [errorNoSubagentId, errorBlankNote]) {
        transport.agentAnswer = (_) => throw error(recorded);
        expect(
          await repository.steer(key, 'x'),
          isA<WorkFailed<SteerOutcome>>().having(
            (f) => f.kind,
            'kind',
            WorkFailureKind.rejected,
          ),
        );
      }
    });

    test('process errors: 4044 reads as not found, 4001 and 5032 fail, '
        '-32601 is unsupported', () async {
      transport.agentAnswer = (_) => throw error(recordedErrorNoSuchProcess);
      final gone = await repository.processKill('t', 'proc_000000000000');
      expect((gone as WorkOk<ProcessKill>).value.outcome, KillOutcome.notFound);

      transport.agentAnswer = (_) => throw error(recordedErrorUnknownSession);
      expect(
        await repository.processList('t'),
        isA<WorkFailed<ProcessList>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.notOwned,
        ),
      );

      transport.agentAnswer = (_) => throw error(recordedErrorAgentFailed);
      for (final result in [
        await repository.processList('t'),
        await repository.processKill('t', 'p'),
      ]) {
        expect(
          result,
          isA<WorkFailed<Object?>>().having(
            (f) => f.kind,
            'kind',
            WorkFailureKind.server,
          ),
        );
      }

      transport.agentAnswer = (_) => throw error(recordedErrorMethodNotFound);
      expect(
        await repository.processKill('t', 'p'),
        isA<WorkUnsupported<ProcessKill>>(),
      );
      expect(
        await repository.processList('t'),
        isA<WorkUnsupported<ProcessList>>(),
      );
      expect(
        await repository.interrupt(key),
        isA<WorkUnsupported<StopOutcome>>(),
      );

      transport.agentAnswer = (_) => throw error(recordedErrorNoProcessId);
      expect(
        await repository.processKill('t', ''),
        isA<WorkFailed<ProcessKill>>().having(
          (f) => f.kind,
          'kind',
          WorkFailureKind.rejected,
        ),
      );
    });
  });

  group('the missed-note notices', () {
    test('a completion frame carries the success-path notice, a failed one '
        'too', () {
      for (final frame in [
        completeWithMissedNote,
        completeFailedWithMissedNote,
      ]) {
        expect(summaryShowsMissedNote(frame['summary'] as String?), isTrue);
      }
      expect(
        summaryShowsMissedNote(completeFinished['summary'] as String?),
        isFalse,
      );
    });
  });

  group('process.list and process.kill', () {
    test('a running program', () {
      final row = parseProcessList(recordedListRunning)!.processes.single;
      expect(row.id, 'proc_0a1b2c3d4e5f');
      expect(row.status, ProgramStatus.running);
      expect(row.command, 'echo ready on demo port; sleep 300');
      expect(row.uptime, const Duration(seconds: 2));
      expect(row.outputTail, 'ready on demo port\n');
      expect(row.exitCode, isNull);
    });

    test('a killed program is exited with reason killed and a negative '
        'code, and reads as stopped', () {
      final row = parseProcessList(recordedListKilled)!.processes.single;
      expect(row.running, isFalse);
      expect(row.completionReason, 'killed');
      expect(row.exitCode, -15);
      expect(row.status, ProgramStatus.stopped);
      expect(row.outputTail, 'ready on demo port\n');
    });

    test('kill answers: killed and already_exited', () {
      final killed = parseProcessKill(recordedKillKilled)!;
      expect(killed.outcome, KillOutcome.killed);
      expect(killed.completionReason, 'killed');
      expect(killed.output, 'ready on demo port\n');
      expect(killed.exitCode, isNull);
      final again = parseProcessKill(recordedKillAlreadyExited)!;
      expect(again.outcome, KillOutcome.alreadyExited);
      expect(again.exitCode, -15);
      expect(again.completionReason, 'killed');
    });
  });
}
