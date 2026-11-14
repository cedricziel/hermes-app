import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/process_card_mapper.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/subagents/process_stop_controller.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../../support/fake_chat_transport.dart';
import 'process_fixtures.dart';

const _running = ProcessOutput(
  processId: 'secret-proc',
  text: 'secret output',
  status: ProgramStatus.running,
  command: 'secret-command --token=abc',
);

class FakeProgramHost extends ChangeNotifier implements ProcessStopHost {
  ProcessOutput? current = _running;
  @override
  bool online = true;

  /// Answers [rereadList]; null leaves it pending forever.
  Future<AgentWorkResult<ListedProcess?>> Function()? reread;
  var rereads = 0;
  final kills = <ProcessKill>[];

  @override
  Listenable get changes => this;

  @override
  ProcessOutput? get card => current;

  @override
  Future<AgentWorkResult<ListedProcess?>> rereadList() {
    rereads++;
    return reread?.call() ??
        Completer<AgentWorkResult<ListedProcess?>>().future;
  }

  @override
  void applyKill(ProcessKill answer) => kills.add(answer);

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  void exit() => update(
    () => current = const ProcessOutput(
      processId: 'secret-proc',
      status: ProgramStatus.exited,
      exitCode: 0,
    ),
  );
}

class Harness {
  Harness() {
    controller = ProcessStopController(
      key: key,
      repository: SubagentRepository(transport),
      host: host,
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
      breadcrumbs: Breadcrumbs.of(trail),
    );
  }

  final key = ProcessKey(
    threadId: 'secret-thread',
    profile: 'secret-profile',
    connection: Object(),
    processId: 'secret-proc',
  );
  final transport = FakeChatTransport();
  final host = FakeProgramHost();
  final events = <(String, Map<String, Object?>)>[];
  final trail = BreadcrumbTrail(capacity: 50);
  late final ProcessStopController controller;

  List<String> get kills => [
    for (final call in transport.agentActions)
      if (call.method == 'process.kill') '${call.params['process_id']}',
  ];

  List<String?> get outcomes => [
    for (final (name, attributes) in events)
      if (name == 'process.stop') attributes['outcome'] as String?,
  ];

  void stop() {
    controller.startStop();
    unawaited(controller.confirmStop());
  }
}

void flow(String name, void Function(FakeAsync async, Harness h) body) {
  test(name, () {
    fakeAsync((async) {
      final h = Harness();
      h.transport.agentAnswer = (_) => killKilled;
      body(async, h);
      h.controller.dispose();
    });
  });
}

AgentWorkResult<ListedProcess?> listed({
  bool running = true,
  String? reason,
  int? code,
}) => WorkOk(
  ListedProcess(
    id: 'secret-proc',
    running: running,
    completionReason: reason,
    exitCode: code,
  ),
);

void main() {
  group('confirmation', () {
    flow('nothing is sent without a confirmation', (async, h) {
      h.controller.startStop();
      expect(h.controller.phase, ProcessStopPhase.confirming);
      async.elapse(const Duration(seconds: 30));
      expect(h.kills, isEmpty);
      h.controller.cancelStop();
      expect(h.controller.phase, ProcessStopPhase.idle);
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.kills, isEmpty, reason: 'a cancelled confirmation is spent');
    });

    flow('a confirmed stop sends one kill through act, for the program the '
        'key names', (async, h) {
      h.stop();
      expect(h.controller.phase, ProcessStopPhase.sending);
      async.flushMicrotasks();
      expect(h.kills, ['secret-proc']);
      expect(h.transport.agentReads, isEmpty);
      final call = h.transport.agentActions.single;
      expect(call.threadId, 'secret-thread');
      expect(call.profile, 'secret-profile');
      expect(h.controller.phase, ProcessStopPhase.killed);
      expect(h.host.kills.single.outcome, KillOutcome.killed);
      expect(h.outcomes, ['killed']);
    });

    flow('a second press while one is in flight is ignored', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (_) => gate.future;
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.canStop, isFalse);
      h.controller.startStop();
      expect(h.controller.phase, ProcessStopPhase.sending);
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.kills, hasLength(1));
      gate.complete(killKilled);
      async.flushMicrotasks();
      expect(h.kills, hasLength(1));
    });

    flow('the confirmation is bound to the program shown: a list that '
        'refreshes or reorders cannot redirect it', (async, h) {
      h.controller.startStop();
      h.host.update(
        () => h.host.current = const ProcessOutput(
          processId: 'secret-proc',
          status: ProgramStatus.running,
          command: 'renamed',
        ),
      );
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.kills, ['secret-proc']);
    });

    flow('the program exiting while the confirmation is open closes it', (
      async,
      h,
    ) {
      h.controller.startStop();
      h.host.exit();
      expect(h.controller.phase, ProcessStopPhase.ended);
      expect(h.controller.confirmationClosed, isTrue);
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.kills, isEmpty);
      expect(h.controller.canStop, isFalse);
    });

    flow('offline disables Stop and queues nothing', (async, h) {
      h.host.update(() => h.host.online = false);
      expect(h.controller.canStop, isFalse);
      expect(h.controller.offline, isTrue);
      h.controller.startStop();
      expect(h.controller.phase, ProcessStopPhase.idle);
      // Confirmed just as the connection went.
      h.host.update(() => h.host.online = true);
      h.controller.startStop();
      h.host.update(() => h.host.online = false);
      unawaited(h.controller.confirmStop());
      h.host.update(() => h.host.online = true);
      async.elapse(const Duration(seconds: 30));
      expect(h.kills, isEmpty);
      expect(h.controller.phase, ProcessStopPhase.idle);
    });

    flow('a program the list does not show running offers no Stop', (async, h) {
      h.host.update(
        () => h.host.current = const ProcessOutput(processId: 'secret-proc'),
      );
      expect(h.controller.canStop, isFalse);
      h.host.exit();
      expect(h.controller.canStop, isFalse);
    });
  });

  group('outcomes', () {
    for (final (answer, phase, outcome, status) in [
      (
        killAlreadyExited,
        ProcessStopPhase.alreadyEnded,
        'already_exited',
        ProcessStopStatus.alreadyEnded,
      ),
      (
        killNotFound,
        ProcessStopPhase.notListed,
        'not_found',
        ProcessStopStatus.notListed,
      ),
      (killError, ProcessStopPhase.failed, 'error', ProcessStopStatus.failed),
    ]) {
      flow('${answer['status']} reads as $phase', (async, h) {
        h.transport.agentAnswer = (_) => answer;
        h.stop();
        async.flushMicrotasks();
        expect(h.controller.phase, phase);
        expect(h.outcomes, [outcome]);
        expect(processStopStatusOf(h.controller.phase), status);
        expect(h.host.kills.single.outcome, isNotNull);
      });
    }

    flow('4044 reads as not listed, quietly', (async, h) {
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(kNoSuchProcess, 'no such process');
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.notListed);
      expect(h.outcomes, ['not_found']);
    });

    flow('an error offers Stop again, which asks again', (async, h) {
      h.transport.agentAnswer = (_) => killError;
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.canStop, isTrue);
      h.controller.startStop();
      expect(h.controller.phase, ProcessStopPhase.confirming);
      expect(h.kills, hasLength(1));
    });

    flow('a 4001 or a resume that failed is an error with Stop again', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(kSessionNotOwned, 'x');
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.failed);
      expect(h.controller.canStop, isTrue);
      expect(h.outcomes, ['error']);
    });

    flow('method-not-found removes Stop after one sentence', (async, h) {
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'x');
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.unsupported);
      expect(h.controller.canStop, isFalse);
      expect(h.outcomes, ['error']);
    });

    flow('killed shows Stopped and Stop is gone', (async, h) {
      h.stop();
      async.flushMicrotasks();
      expect(processStopStatusOf(h.controller.phase), ProcessStopStatus.killed);
      expect(h.controller.canStop, isFalse);
    });
  });

  group('a lost answer', () {
    void lose(Harness h) =>
        h.transport.agentAnswer = (_) => throw const GatewayRequestTimeout();

    flow('re-reads the list and never resends', (async, h) {
      lose(h);
      h.host.reread = () async => listed();
      h.stop();
      async.flushMicrotasks();
      expect(h.host.rereads, 1);
      expect(h.kills, hasLength(1));
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
      async.elapse(const Duration(minutes: 1));
      expect(h.kills, hasLength(1));
    });

    flow('a re-read showing it running ends unconfirmed, with Stop offered '
        'and confirmed again', (async, h) {
      lose(h);
      h.host.reread = () async => listed();
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
      expect(
        processStopStatusOf(h.controller.phase),
        ProcessStopStatus.unconfirmed,
      );
      expect(h.outcomes, ['unconfirmed']);
      expect(h.controller.canStop, isTrue);
      h.controller.startStop();
      expect(h.controller.phase, ProcessStopPhase.confirming);
      expect(h.kills, hasLength(1));
    });

    flow('a re-read showing it stopped or exited ends in that state', (
      async,
      h,
    ) {
      lose(h);
      h.host.reread = () async => listed(running: false, reason: 'killed');
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.killed);
      h.host.reread = () async => listed(running: false, code: 0);
      h.controller.dispose();
      final again = Harness()..host.reread = () async => listed(running: false);
      lose(again);
      again.stop();
      async.flushMicrotasks();
      // A lost answer claims nothing: the card's own state (Exited or
      // Ended) says what happened.
      expect(again.controller.phase, ProcessStopPhase.idle);
      expect(
        processStopStatusOf(again.controller.phase),
        ProcessStopStatus.idle,
      );
      expect(again.outcomes, ['unconfirmed']);
      again.controller.dispose();
    });

    flow('a re-read showing it gone ends as no longer listed', (async, h) {
      lose(h);
      h.host.reread = () async => const WorkOk(null);
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.notListed);
    });

    flow('a re-read that fails or is unsupported ends unconfirmed', (async, h) {
      lose(h);
      h.host.reread = () async => const WorkFailed(WorkFailureKind.server);
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
      h.host.reread = () async => const WorkUnsupported();
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
      expect(h.kills, hasLength(2), reason: 'each one confirmed');
    });

    flow('a check ends within 10 s', (async, h) {
      lose(h);
      h.stop();
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.checking);
      expect(
        processStopStatusOf(h.controller.phase),
        ProcessStopStatus.checking,
      );
      async.elapse(const Duration(seconds: 9));
      expect(h.controller.phase, ProcessStopPhase.checking);
      async.elapse(const Duration(seconds: 1));
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
    });

    flow('losing the connection while checking ends it unconfirmed', (
      async,
      h,
    ) {
      lose(h);
      h.stop();
      async.flushMicrotasks();
      h.host.update(() => h.host.online = false);
      async.flushMicrotasks();
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
      expect(h.controller.canStop, isFalse, reason: 'offline');
    });

    flow('a thrown answer counts as lost', (async, h) {
      h.transport.agentAnswer = (_) => throw const GatewayConnectionClosed();
      h.host.reread = () async => listed();
      h.stop();
      async.flushMicrotasks();
      expect(h.host.rereads, 1);
      expect(h.controller.phase, ProcessStopPhase.unconfirmed);
    });
  });

  group('privacy', () {
    flow('logs carry only the outcome and the breadcrumb no attribute; '
        'nothing names the program', (async, h) {
      h.transport.agentAnswer = (_) => {
        ...killKilled,
        'command': 'secret-command',
        'output': 'secret output',
        'error': 'secret error',
      };
      h.stop();
      async.flushMicrotasks();
      expect(h.events.single.$1, 'process.stop');
      expect(h.events.single.$2, {'outcome': 'killed'});
      final crumbs = h.trail.recent.toList();
      expect(crumbs.map((c) => c.name), ['process.stop.pressed']);
      expect(crumbs.single.attributes, isEmpty);
      final seen = [
        for (final (name, attributes) in h.events) '$name $attributes',
        for (final crumb in crumbs) '${crumb.name} ${crumb.attributes}',
        h.controller.toString(),
        h.key.toString(),
        h.host.current.toString(),
        h.host.kills.single.toString(),
      ].join(' ');
      expect(seen, isNot(contains('secret')));
      expect(seen, isNot(contains('abc')));
    });

    flow('process.stop is never sent', (async, h) {
      h.transport.agentAnswer = (_) => throw const GatewayRequestTimeout();
      h.host.reread = () async => listed();
      for (var i = 0; i < 3; i++) {
        h.stop();
        async.elapse(const Duration(seconds: 11));
      }
      expect(h.transport.agentActions.map((call) => call.method).toSet(), {
        'process.kill',
      });
      expect(
        [
          ...h.transport.agentActions,
          ...h.transport.agentReads,
        ].where((call) => call.method == 'process.stop'),
        isEmpty,
      );
    });

    flow('a logger that throws does not break the stop', (async, h) {
      final broken = ProcessStopController(
        key: h.key,
        repository: SubagentRepository(h.transport),
        host: h.host,
        events: (name, [attributes = const {}]) => throw StateError('down'),
      );
      broken.startStop();
      unawaited(broken.confirmStop());
      async.flushMicrotasks();
      expect(broken.phase, ProcessStopPhase.killed);
      broken.dispose();
    });
  });

  flow('dispose drops an answer still in flight', (async, h) {
    final gate = Completer<Map<String, Object?>>();
    h.transport.agentAnswer = (_) => gate.future;
    h.stop();
    async.flushMicrotasks();
    h.controller.dispose();
    gate.complete(killKilled);
    async.flushMicrotasks();
    expect(h.host.kills, isEmpty);
    expect(h.events, isEmpty);
  });
}
