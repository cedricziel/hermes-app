import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_detail_host.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/chat/subagents/subagent_roster.dart';

import '../../support/fake_chat_transport.dart';

class FakeEnv extends ChangeNotifier implements RosterEnvironment {
  @override
  Object? connection = Object();
  @override
  bool foreground = true, unlocked = true;

  @override
  Listenable get changes => this;

  void update(void Function() change) {
    change();
    notifyListeners();
  }
}

Map<String, Object?> listed(
  String id, {
  String status = 'running',
  String? parent,
  String? delegation,
  bool steer = true,
  int tools = 1,
  double? started,
}) => {
  'subagent_id': id,
  'goal': 'goal $id',
  'parent_id': ?parent,
  'delegation_id': ?delegation,
  'status': status,
  'tool_count': tools,
  'accepting_steer': steer,
  'started_at': ?started,
};

Subagent frame(
  String id, {
  SubagentStatus status = SubagentStatus.running,
  String? parent,
  int index = 0,
  String? summary,
}) => Subagent(
  id: id,
  goal: 'goal $id',
  parentId: parent,
  index: index,
  status: status,
  summary: summary,
);

class Rig {
  Rig() {
    roster = SubagentRoster(
      threadId: 'secret-thread',
      profile: 'secret-profile',
      repository: SubagentRepository(transport),
      env: env,
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
    );
    transport.agentAnswer = (call) => answer(call);
  }

  final env = FakeEnv();
  final transport = FakeChatTransport();
  final events = <(String, Map<String, Object?>)>[];
  late final SubagentRoster roster;
  FutureOr<Map<String, Object?>> Function(FakeAgentCall) answer = (_) => {
    'subagents': [],
    'delegations': [],
  };

  int get reads => transport.agentReads.length;

  void listAnswers(List<Map<String, Object?>> rows, [List<Object?>? failed]) {
    answer = (_) => {'subagents': rows, 'delegations': failed ?? []};
  }

  List<String> get now => [for (final p in roster.sections.now) p.row.id];
  List<String> get session => [
    for (final p in roster.sections.session) p.row.id,
  ];
}

void rig(String name, void Function(FakeAsync async, Rig r) body) {
  test(name, () {
    fakeAsync((async) {
      final r = Rig();
      body(async, r);
      r.roster.dispose();
    });
  });
}

void main() {
  group('merging', () {
    rig('frames from several replies become one row per id', (async, r) {
      r.roster.applyFrame(frame('a'));
      r.roster.applyFrame(frame('b'));
      r.roster.applyFrame(frame('a', status: SubagentStatus.completed));
      expect(r.now, ['b']);
      expect(r.session, ['a']);
    });

    rig('a list adds agents no frame named', (async, r) {
      r.listAnswers([listed('x', started: 100)]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.now, ['x']);
      expect(r.roster.row('x')!.goal, 'goal x');
      expect(r.roster.row('x')!.acceptingSteer, isTrue);
    });

    rig('a frame newer than a list read wins', (async, r) {
      final gate = Completer<Map<String, Object?>>();
      r.roster.applyFrame(frame('a'));
      r.answer = (_) => gate.future;
      r.roster.watch();
      async.flushMicrotasks();
      r.roster.applyFrame(frame('a', status: SubagentStatus.completed));
      gate.complete({
        'subagents': [listed('a')],
      });
      async.flushMicrotasks();
      expect(r.roster.row('a')!.state, AgentState.finished);
    });

    rig('terminal states stay; a list never brings an ended row back', (
      async,
      r,
    ) {
      r.roster.applyFrame(frame('a', status: SubagentStatus.completed));
      r.roster.applyFrame(frame('a'));
      expect(r.roster.row('a')!.state, AgentState.finished);
      r.listAnswers([listed('a')]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.roster.row('a')!.state, AgentState.finished);
    });

    rig('a running row the list no longer has becomes ended, not finished', (
      async,
      r,
    ) {
      r.roster.applyFrame(frame('a'));
      r.roster.applyFrame(frame('b', status: SubagentStatus.completed));
      r.listAnswers([]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.roster.row('a')!.state, AgentState.ended);
      expect(r.roster.row('b')!.state, AgentState.finished);
    });

    rig('a status the list does not know reads as ended', (async, r) {
      r.listAnswers([listed('a', status: 'paused_for_budget')]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.roster.row('a')!.state, AgentState.ended);
    });

    rig('failed delegations are keyed and dedupe against frame rows', (
      async,
      r,
    ) {
      r.roster.applyFrame(frame('a', index: 1));
      r.listAnswers(
        [listed('a', delegation: 'd1')],
        [
          {
            'delegation_id': 'd1',
            'task_index': 1,
            'status': 'failed',
            'goal': 'dup',
          },
          {
            'delegation_id': 'd1',
            'task_index': 2,
            'status': 'failed',
            'goal': 'Audit the dependency tree',
            'error': 'boom',
          },
        ],
      );
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.session, ['d1#2']);
      final failed = r.roster.row('d1#2')!;
      expect(failed.state, AgentState.failed);
      expect(failed.error, 'boom');
      expect(failed.goal, 'Audit the dependency tree');
    });
  });

  group('sections', () {
    rig('nest up to three levels under a listed parent; unknown parent is '
        'top level', (async, r) {
      r.roster.applyFrame(frame('a1'));
      r.roster.applyFrame(frame('a2', parent: 'a1'));
      r.roster.applyFrame(frame('a3', parent: 'a2'));
      r.roster.applyFrame(frame('a4', parent: 'a3'));
      r.roster.applyFrame(frame('z', parent: 'nobody'));
      final levels = {for (final p in r.roster.sections.now) p.row.id: p.level};
      expect(levels, {'a1': 0, 'a2': 1, 'a3': 2, 'a4': 2, 'z': 0});
    });

    rig('a finished child of a running parent is top level in This session', (
      async,
      r,
    ) {
      r.roster.applyFrame(frame('a1'));
      r.roster.applyFrame(frame('a2', parent: 'a1'));
      r.roster.applyFrame(
        frame('a2', parent: 'a1', status: SubagentStatus.completed),
      );
      expect(r.now, ['a1']);
      expect(r.roster.sections.session.single.level, 0);
    });

    rig('This session keeps the 20 newest ended rows and counts the rest', (
      async,
      r,
    ) {
      for (var i = 0; i < 23; i++) {
        r.roster.applyFrame(frame('e$i', status: SubagentStatus.completed));
      }
      final sections = r.roster.sections;
      expect(sections.session, hasLength(20));
      expect(sections.hiddenEnded, 3);
      expect(sections.session.first.row.id, 'e3');
    });

    rig('rows are ordered by start time', (async, r) {
      r.listAnswers([
        listed('late', started: 200),
        listed('early', started: 100),
      ]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.now, ['early', 'late']);
    });
  });

  group('reads', () {
    rig('happen only while watched: once, then every 5 s while something '
        'runs', (async, r) {
      r.listAnswers([listed('a')]);
      async.elapse(const Duration(seconds: 20));
      expect(r.reads, 0);
      final watch = r.roster.watch();
      async.flushMicrotasks();
      expect(r.reads, 1);
      async.elapse(const Duration(seconds: 5));
      expect(r.reads, 2);
      async.elapse(const Duration(seconds: 10));
      expect(r.reads, 4);
      watch.close();
      async.elapse(const Duration(seconds: 30));
      expect(r.reads, 4);
    });

    rig('stop polling when nothing runs', (async, r) {
      r.listAnswers([listed('a', status: 'completed')]);
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.reads, 1);
    });

    rig('wait for foreground, unlock and a connection', (async, r) {
      r.env.foreground = false;
      r.listAnswers([listed('a')]);
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.reads, 0);
      r.env.update(() {
        r.env.foreground = true;
        r.env.unlocked = false;
      });
      async.elapse(const Duration(seconds: 10));
      expect(r.reads, 0);
      r.env.update(() => r.env.unlocked = true);
      async.flushMicrotasks();
      expect(r.reads, 1);
      r.env.update(() => r.env.connection = null);
      async.elapse(const Duration(seconds: 10));
      expect(r.reads, 1);
    });

    rig('a chat not attached sends nothing and keeps the frame rows', (
      async,
      r,
    ) {
      r.transport.agentSessionAttached = false;
      r.roster.applyFrame(frame('a'));
      r.roster.watch();
      async.elapse(const Duration(seconds: 20));
      expect(r.reads, 0);
      expect(r.now, ['a']);
      expect(r.roster.lastReadFailed, isFalse);
    });

    rig('a malformed answer keeps the rows and backs off', (async, r) {
      r.roster.applyFrame(frame('a'));
      r.answer = (_) => {'subagents': 'nope'};
      r.roster.watch();
      async.flushMicrotasks();
      expect(r.now, ['a']);
      expect(r.roster.lastReadFailed, isTrue);
      async.elapse(const Duration(seconds: 5));
      expect(r.reads, 1, reason: 'the next tick is skipped');
      async.elapse(const Duration(seconds: 60));
      expect(r.reads, greaterThan(1));
      expect(r.reads, lessThan(10));
    });

    rig('unsupported stops list reads for the connection and logs once', (
      async,
      r,
    ) {
      r.roster.applyFrame(frame('a'));
      r.answer = (_) =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'x');
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.reads, 1);
      expect(r.events.map((e) => '${e.$1} ${e.$2}'), [
        'subagent.unsupported {method: list}',
      ]);
      expect(r.now, ['a']);
      // The next connection tries again.
      r.answer = (_) => {'subagents': [], 'delegations': []};
      r.env.update(() => r.env.connection = Object());
      async.flushMicrotasks();
      expect(r.reads, 2);
    });

    rig('a 4001 stops reads until the connection changes or an action '
        'attached the session', (async, r) {
      r.roster.applyFrame(frame('a'));
      r.answer = (_) => throw const GatewayRpcException(4001, 'x');
      r.roster.watch();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(r.reads, 1);
      r.answer = (_) => {
        'subagents': [listed('a')],
      };
      r.roster.markAttached();
      async.flushMicrotasks();
      expect(r.reads, 2);
      expect(r.roster.row('a')!.acceptingSteer, isTrue);
    });

    rig('an answer after the connection changed is dropped', (async, r) {
      final gate = Completer<Map<String, Object?>>();
      r.answer = (_) => gate.future;
      r.roster.watch();
      async.flushMicrotasks();
      r.env.update(() => r.env.connection = Object());
      gate.complete({
        'subagents': [listed('old')],
      });
      async.flushMicrotasks();
      expect(r.now, isNot(contains('old')));
    });

    rig('clear drops rows and an answer still in flight', (async, r) {
      final gate = Completer<Map<String, Object?>>();
      r.roster.applyFrame(frame('a'));
      r.answer = (_) => gate.future;
      r.roster.watch();
      async.flushMicrotasks();
      r.roster.clear();
      gate.complete({
        'subagents': [listed('late')],
      });
      async.flushMicrotasks();
      expect(r.roster.hasAgents, isFalse);
    });

    rig('dispose stops everything', (async, r) {
      r.listAnswers([listed('a')]);
      r.roster.watch();
      async.flushMicrotasks();
      r.roster.dispose();
      async.elapse(const Duration(seconds: 30));
      expect(r.reads, 1);
      r.roster.applyFrame(frame('b'));
      expect(r.roster.hasAgents, isFalse);
    });
  });

  group('detail host', () {
    rig('shows the row and re-reads the list for a stop check', (async, r) {
      r.roster.applyFrame(frame('a'));
      final host = r.roster.hostFor('a');
      expect(host.view!.state, AgentState.running);
      expect(host.online, isTrue);
      r.roster.watch();
      async.flushMicrotasks();
      r.listAnswers([]);
      AgentView? seen;
      unawaited(
        host.rereadList().then((result) {
          seen = (result as dynamic).value as AgentView?;
        }),
      );
      async.flushMicrotasks();
      expect(seen!.state, AgentState.ended);
    });

    rig('a failed re-read is not an answer', (async, r) {
      r.roster.applyFrame(frame('a'));
      r.answer = (_) => throw const GatewayRequestTimeout();
      final host = r.roster.hostFor('a');
      Object? result;
      unawaited(host.rereadList().then((value) => result = value));
      async.flushMicrotasks();
      expect(result.runtimeType.toString(), startsWith('WorkLost'));
    });
  });

  group('privacy', () {
    rig('toString and events carry no goal or id', (async, r) {
      r.roster.applyFrame(
        Subagent(
          id: 'secret-id',
          goal: 'secret goal',
          status: SubagentStatus.completed,
          summary: 'secret summary',
        ),
      );
      final text = [
        r.roster,
        r.roster.row('secret-id')!,
        r.roster.sections,
        r.roster.row('secret-id')!.toView(),
      ].join(' ');
      expect(text, isNot(contains('secret')));
      expect(r.events, isEmpty);
    });
  });
}
