import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/subagents/process_stop_controller.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/chat/subagents/subagent_roster.dart';

import '../../support/fake_chat_transport.dart';
import 'process_fixtures.dart';
import 'subagent_roster_test.dart' show FakeEnv;

class FakeCards extends ChangeNotifier implements ProgramCards {
  FakeCards() {
    state.adopt(attachment!);
  }

  Object? attachment = Object();
  final state = ProcessOutputState();
  var notified = 0;

  @override
  Listenable get cardChanges => this;

  @override
  Object? attachmentOf(String threadId) => attachment;

  @override
  ProcessOutputState? cardsFor(
    String threadId,
    Object attachment, {
    bool create = false,
  }) => attachment == this.attachment && state.hasScope(attachment)
      ? state
      : null;

  @override
  void cardsChanged() {
    notified++;
    notifyListeners();
  }

  void frame(String id, String chunk) => state.apply(
    ProcessOutputUpdate(id, chunk: chunk),
    attachment: attachment!,
  );

  void reattach() {
    attachment = Object();
    state.adopt(attachment!);
  }
}

Map<String, Object?> program(
  String id, {
  String status = 'running',
  String? command,
}) => {'session_id': id, 'status': status, 'command': ?command};

class Rig {
  Rig({bool withPrograms = true}) {
    roster = SubagentRoster(
      threadId: 'secret-thread',
      profile: 'secret-profile',
      repository: SubagentRepository(transport),
      env: env,
      programs: withPrograms ? cards : null,
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
    );
    transport.agentAnswer = (call) => switch (call.method) {
      'process.list' => programs(call),
      'process.kill' => kill(call),
      _ => agents(call),
    };
  }

  final env = FakeEnv();
  final cards = FakeCards();
  final transport = FakeChatTransport();
  final events = <(String, Map<String, Object?>)>[];
  late final SubagentRoster roster;
  FutureOr<Map<String, Object?>> Function(FakeAgentCall) agents = (_) => {
    'subagents': [],
    'delegations': [],
  };
  FutureOr<Map<String, Object?>> Function(FakeAgentCall) programs = (_) => {
    'processes': [],
  };

  FutureOr<Map<String, Object?>> Function(FakeAgentCall) kill = (_) =>
      killKilled;

  void listPrograms(List<Map<String, Object?>> rows) =>
      programs = (_) => {'processes': rows};

  int reads(String method) =>
      transport.agentReads.where((call) => call.method == method).length;
  int get programReads => reads('process.list');
  int get agentReads => reads('subagent.list');
}

void rig(
  String name,
  void Function(FakeAsync async, Rig r) body, {
  bool withPrograms = true,
}) {
  test(name, () {
    fakeAsync((async) {
      final r = Rig(withPrograms: withPrograms);
      body(async, r);
      r.roster.dispose();
    });
  });
}

void main() {
  group('program reads', () {
    rig('share the roster\'s demand: once on watch, then every 5 s on the '
        'same timer while a program runs', (async, r) {
      r.listPrograms([program('p', command: 'npm test')]);
      async.elapse(const Duration(seconds: 20));
      expect(r.programReads, 0);
      final watch = r.roster.watch();
      async.flushMicrotasks();
      expect(r.programReads, 1);
      expect(r.agentReads, 1);
      expect(r.cards.state.card('p')!.command, 'npm test');
      expect(r.cards.notified, greaterThan(0));
      async.elapse(const Duration(seconds: 10));
      expect(r.programReads, 3);
      // No agent runs, and the agents were listed once: only programs read.
      expect(r.agentReads, 1);
      watch.close();
      async.elapse(const Duration(seconds: 30));
      expect(r.programReads, 3);
    });

    rig('stop when no listed program runs', (async, r) {
      r.cards.frame('p', 'out');
      r.listPrograms([program('p', status: 'exited')]);
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.programReads, 1);
    });

    rig('wait for foreground, unlock and a connection', (async, r) {
      r.env.foreground = false;
      r.listPrograms([program('p')]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.programReads, 0);
      r.env.update(() {
        r.env.foreground = true;
        r.env.unlocked = false;
      });
      async.elapse(const Duration(seconds: 10));
      expect(r.programReads, 0);
      r.env.update(() => r.env.unlocked = true);
      async.flushMicrotasks();
      expect(r.programReads, 1);
      r.env.update(() => r.env.connection = null);
      async.elapse(const Duration(seconds: 10));
      expect(r.programReads, 1);
    });

    rig('a session not attached sends nothing and never resumes', (async, r) {
      r.transport.agentSessionAttached = false;
      r.cards.attachment = null;
      r.roster.watch();
      async.elapse(const Duration(seconds: 20));
      expect(r.transport.agentReads, isEmpty);
      expect(r.transport.agentActions, isEmpty);
    });

    rig('without program cards nothing reads process.list', (async, r) {
      r.roster.watch();
      async.elapse(const Duration(seconds: 20));
      expect(r.programReads, 0);
      expect(r.agentReads, 1);
    }, withPrograms: false);

    rig('unsupported stops program reads for the connection, not agent '
        'reads, and logs once', (async, r) {
      r.programs = (_) =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'x');
      r.agents = (_) => {
        'subagents': [
          {'subagent_id': 'a', 'status': 'running'},
        ],
      };
      r.cards.frame('p', 'out');
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.programReads, 1);
      expect(r.agentReads, greaterThan(1));
      expect(r.events.map((e) => '${e.$1} ${e.$2}'), [
        'subagent.unsupported {method: process_list}',
      ]);
      // The cards stay as frames left them: no list entry, no Stop.
      expect(r.cards.state.card('p')!.listed, isFalse);
      r.programs = (_) => {'processes': []};
      r.env.update(() => r.env.connection = Object());
      async.flushMicrotasks();
      expect(r.programReads, 2);
    });

    rig('a 4001 stops program reads until the session is attached', (async, r) {
      r.programs = (_) =>
          throw const GatewayRpcException(kSessionNotOwned, 'x');
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.programReads, 1);
      r.listPrograms([program('p')]);
      r.roster.markAttached();
      async.flushMicrotasks();
      expect(r.programReads, 2);
      expect(r.cards.state.card('p'), isNotNull);
    });

    rig('5032 is a quiet failed read on the backoff', (async, r) {
      r.cards.frame('p', 'out');
      r.listPrograms([program('p', command: 'first')]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.programReads, 1);
      r.programs = (_) =>
          throw const GatewayRpcException(kAgentStillStarting, 'x');
      async.elapse(const Duration(seconds: 5));
      expect(r.programReads, 2);
      expect(r.cards.state.card('p')!.command, 'first');
      expect(r.events, isEmpty);
      async.elapse(const Duration(seconds: 5));
      expect(r.programReads, 2, reason: 'the next tick is skipped');
      async.elapse(const Duration(seconds: 5));
      expect(r.programReads, 3);
    });

    rig('both lists failing in one round back off once', (async, r) {
      r.cards.frame('p', 'out');
      r.listPrograms([program('p')]);
      r.agents = (_) => {
        'subagents': [
          {'subagent_id': 'a', 'status': 'running'},
        ],
      };
      r.roster.watch();
      async.flushMicrotasks();
      r.programs = (_) => throw const GatewayRpcException(5010, 'x');
      r.agents = (_) => throw const GatewayRpcException(5000, 'x');
      async.elapse(const Duration(seconds: 5));
      expect((r.agentReads, r.programReads), (2, 2));
      async.elapse(const Duration(seconds: 5));
      expect((r.agentReads, r.programReads), (2, 2));
      async.elapse(const Duration(seconds: 5));
      expect((r.agentReads, r.programReads), (3, 3));
    });

    rig('a late answer after the connection changed is dropped', (async, r) {
      final gate = Completer<Map<String, Object?>>();
      r.programs = (_) => gate.future;
      r.roster.watch();
      async.flushMicrotasks();
      r.programs = (_) => {'processes': []};
      r.env.update(() => r.env.connection = Object());
      gate.complete({
        'processes': [program('old')],
      });
      async.flushMicrotasks();
      expect(r.cards.state.card('old'), isNull);
    });

    rig('a late answer after the attachment, the chat or a clear is dropped', (
      async,
      r,
    ) {
      for (final change in <void Function()>[
        r.cards.reattach,
        () => r.roster.retarget('other-thread'),
        r.roster.clear,
      ]) {
        final gate = Completer<Map<String, Object?>>();
        r.programs = (_) => gate.future;
        final watch = r.roster.watch();
        async.flushMicrotasks();
        change();
        gate.complete({
          'processes': [program('late')],
        });
        async.flushMicrotasks();
        expect(r.cards.state.card('late'), isNull);
        watch.close();
        async.flushMicrotasks();
      }
    });

    rig('readProgramsNow reads after one in flight and answers it', (async, r) {
      final gate = Completer<Map<String, Object?>>();
      r.programs = (_) => gate.future;
      r.roster.watch();
      async.flushMicrotasks();
      AgentWorkResult<ProcessList>? answer;
      unawaited(r.roster.readProgramsNow().then((value) => answer = value));
      async.flushMicrotasks();
      r.listPrograms([program('p')]);
      gate.complete({'processes': []});
      async.flushMicrotasks();
      expect(r.programReads, 2);
      expect((answer! as WorkOk<ProcessList>).value.processes.single.id, 'p');
    });

    rig('dispose stops everything', (async, r) {
      r.listPrograms([program('p')]);
      r.roster.watch();
      async.flushMicrotasks();
      r.roster.dispose();
      async.elapse(const Duration(seconds: 30));
      expect(r.programReads, 1);
    });
  });

  group('stop host', () {
    rig('a lost kill re-reads the list through the roster and is never '
        'resent', (async, r) {
      r.cards.frame('p', 'out');
      r.listPrograms([program('p')]);
      r.roster.watch();
      async.flushMicrotasks();
      final stop = ProcessStopController(
        key: ProcessKey(
          threadId: r.roster.threadId,
          profile: r.roster.profile,
          connection: r.roster.connection!,
          processId: 'p',
        ),
        repository: r.roster.repository,
        host: r.roster.programHostFor('p')!,
      );
      expect(stop.canStop, isTrue);
      r.kill = (_) => throw const GatewayRequestTimeout();
      r.listPrograms([
        {
          'session_id': 'p',
          'status': 'exited',
          'exit_code': -15,
          'completion_reason': 'killed',
        },
      ]);
      final before = r.programReads;
      stop.startStop();
      unawaited(stop.confirmStop());
      async.flushMicrotasks();
      expect(r.programReads, before + 1);
      expect(stop.phase, ProcessStopPhase.killed);
      expect(r.cards.state.card('p')!.status, ProgramStatus.stopped);
      expect(
        r.transport.agentActions.where((c) => c.method == 'process.kill'),
        hasLength(1),
      );
      stop.dispose();
    });

    rig('a kill answer lands on the card, and the host follows the cards', (
      async,
      r,
    ) {
      r.cards.frame('p', '');
      r.listPrograms([program('p')]);
      r.roster.watch();
      async.flushMicrotasks();
      final host = r.roster.programHostFor('p')!;
      var heard = 0;
      host.changes.addListener(() => heard++);
      host.applyKill(parseProcessKill({...killKilled, 'output': 'tail'})!);
      expect(host.card!.status, ProgramStatus.stopped);
      expect(host.card!.text, 'tail');
      expect(heard, greaterThan(0));
      expect(host.online, isTrue);
      r.env.update(() => r.env.connection = null);
      expect(host.online, isFalse);
    });

    rig('no program cards, no stop host', (async, r) {
      expect(r.roster.programHostFor('p'), isNull);
    }, withPrograms: false);
  });

  group('privacy', () {
    rig('reads log nothing about programs, and toString prints counts', (
      async,
      r,
    ) {
      r.listPrograms([
        {
          'session_id': 'secret-proc',
          'command': 'secret-command',
          'output_tail': 'secret output',
          'cwd': '/secret',
        },
      ]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.events, isEmpty);
      expect('${r.roster} ${r.cards.state}', isNot(contains('secret')));
    });
  });
}
