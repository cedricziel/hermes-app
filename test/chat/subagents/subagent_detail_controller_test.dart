import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_detail_host.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/subagent_detail_controller.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../../support/fake_chat_transport.dart';

class FakeHost extends ChangeNotifier implements AgentDetailHost {
  AgentView? current = const AgentView(
    state: AgentState.running,
    goal: 'secret goal',
    acceptingSteer: true,
  );
  @override
  bool online = true, readingAllowed = true, unlocked = true;

  /// Answers [rereadList]; null leaves it pending forever.
  Future<AgentWorkResult<AgentView?>> Function()? reread;
  var rereads = 0;

  @override
  Listenable get changes => this;

  @override
  AgentView? get view => current;

  @override
  Future<AgentWorkResult<AgentView?>> rereadList() {
    rereads++;
    return reread?.call() ?? Completer<AgentWorkResult<AgentView?>>().future;
  }

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  void end([AgentState state = AgentState.finished, String? summary]) =>
      update(() => current = AgentView(state: state, summary: summary));
}

class Harness {
  Harness() {
    controller = SubagentDetailController(
      key: key,
      repository: SubagentRepository(transport),
      host: host,
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
      breadcrumbs: Breadcrumbs.of(trail),
    );
  }

  final key = AgentKey(
    threadId: 'secret-thread',
    profile: 'secret-profile',
    connection: Object(),
    subagentId: 'a1',
  );
  final transport = FakeChatTransport();
  final host = FakeHost();
  final events = <(String, Map<String, Object?>)>[];
  final trail = BreadcrumbTrail(capacity: 50);
  late final SubagentDetailController controller;

  List<String> get interrupts => [
    for (final call in transport.agentActions)
      if (call.method == 'subagent.interrupt') '${call.params['subagent_id']}',
  ];

  List<String> get steers => [
    for (final call in transport.agentActions)
      if (call.method == 'subagent.steer') '${call.params['text']}',
  ];

  int get tailReads => [
    for (final call in transport.agentReads)
      if (call.method == 'subagent.tail') call,
  ].length;

  List<String?> get outcomes => [
    for (final (_, attributes) in events) attributes['outcome'] as String?,
  ];
}

Map<String, Object?> tail(String text, {bool available = true}) => {
  'available': available,
  'text': text,
  'truncated': false,
};

void flow(String name, void Function(FakeAsync async, Harness h) body) {
  test(name, () {
    fakeAsync((async) {
      final h = Harness();
      h.transport.agentAnswer = (call) => switch (call.method) {
        'subagent.tail' => tail('output'),
        'subagent.interrupt' => {'found': true},
        _ => {'status': 'queued'},
      };
      body(async, h);
      h.controller.dispose();
    });
  });
}

AgentWorkResult<AgentView?> running() =>
    const WorkOk(AgentView(state: AgentState.running, acceptingSteer: true));
AgentWorkResult<AgentView?> gone() => const WorkOk(null);

void main() {
  group('output', () {
    flow('is read on open and every 2 s, one read in flight', (async, h) {
      async.flushMicrotasks();
      expect(h.tailReads, 1);
      expect(h.controller.tail, 'output');
      expect(h.controller.tailPhase, TailPhase.ready);
      async.elapse(const Duration(seconds: 2));
      expect(h.tailReads, 2);
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (_) => gate.future;
      async.elapse(const Duration(seconds: 6));
      expect(h.tailReads, 3, reason: 'a slow read blocks the next ones');
      gate.complete(tail('later'));
      async.flushMicrotasks();
      expect(h.controller.tail, 'later');
    });

    flow('holds the shown text while the reader holds it, then jumps', (
      async,
      h,
    ) {
      async.flushMicrotasks();
      h.controller.setReaderHolding(true);
      h.transport.agentAnswer = (_) => tail('newer');
      async.elapse(const Duration(seconds: 2));
      expect(h.controller.tail, 'output');
      expect(h.controller.paused, isTrue);
      h.controller.jumpToLatest();
      expect(h.controller.tail, 'newer');
      expect(h.controller.paused, isFalse);
    });

    flow('says the output never comes 30 s after the agent started', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (_) => tail('', available: false);
      async.flushMicrotasks();
      expect(h.controller.tailPhase, TailPhase.noOutput);
      async.elapse(const Duration(seconds: 31));
      expect(h.controller.tailPhase, TailPhase.neverAvailable);
    });

    flow('a failed refresh keeps the text and says so', (async, h) {
      async.flushMicrotasks();
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(5000, 'x');
      async.elapse(const Duration(seconds: 2));
      expect(h.controller.tail, 'output');
      expect(h.controller.refreshFailed, isTrue);
      h.transport.agentAnswer = (_) => tail('ok');
      async.elapse(const Duration(seconds: 2));
      expect(h.controller.refreshFailed, isFalse);
    });

    flow('an unsupported tail stops reading and removes the section', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'x');
      async.flushMicrotasks();
      expect(h.controller.tailPhase, TailPhase.unsupported);
      async.elapse(const Duration(seconds: 10));
      expect(h.tailReads, 1);
    });

    flow('lock drops the text and reads again after unlock', (async, h) {
      async.flushMicrotasks();
      h.host.update(() => h.host.unlocked = false);
      expect(h.controller.tail, isEmpty);
      async.elapse(const Duration(seconds: 6));
      expect(h.tailReads, 1);
      h.host.update(() => h.host.unlocked = true);
      async.flushMicrotasks();
      expect(h.tailReads, 2);
      expect(h.controller.tail, 'output');
    });

    flow('stops reading when the agent ends and keeps the last output', (
      async,
      h,
    ) {
      async.flushMicrotasks();
      h.host.end();
      async.elapse(const Duration(seconds: 10));
      expect(h.tailReads, 1);
      expect(h.controller.tail, 'output');
      expect(h.controller.lastOutput, isTrue);
    });

    flow('is not read in the background or while hidden', (async, h) {
      async.flushMicrotasks();
      h.host.update(() => h.host.readingAllowed = false);
      async.elapse(const Duration(seconds: 10));
      expect(h.tailReads, 1);
    });

    flow('does not read a not-controllable agent\'s output', (async, h) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
      h.host.reread = () async => running();
      async.flushMicrotasks();
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.notControllable);
      final reads = h.tailReads;
      async.elapse(const Duration(seconds: 10));
      expect(h.tailReads, reads);
    });

    flow('a session not attached reads as no output, not loading forever', (
      async,
      h,
    ) {
      h.transport.agentSessionAttached = false;
      async.flushMicrotasks();
      expect(h.controller.tailPhase, TailPhase.noOutput);
    });

    flow('a row not in the roster yet does not stop the reads for good', (
      async,
      h,
    ) {
      h.host.update(() => h.host.current = null);
      async.flushMicrotasks();
      h.host.update(() => h.host.online = false);
      h.host.update(() => h.host.online = true);
      h.host.update(
        () => h.host.current = const AgentView(state: AgentState.running),
      );
      final before = h.tailReads;
      async.elapse(const Duration(seconds: 2));
      expect(h.tailReads, greaterThan(before));
    });

    flow('a read that began before the lock never lands after it', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (_) => gate.future;
      async.flushMicrotasks();
      h.host.update(() => h.host.unlocked = false);
      h.host.update(() => h.host.unlocked = true);
      gate.complete(tail('stale secret'));
      async.flushMicrotasks();
      expect(h.controller.tail, isNot(contains('stale')));
    });

    flow('dispose drops the output and a late answer is ignored', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (_) => gate.future;
      async.flushMicrotasks();
      h.controller.dispose();
      gate.complete(tail('late'));
      async.flushMicrotasks();
      expect(h.controller.tail, isEmpty);
    });
  });

  group('stop', () {
    flow('is never sent without confirmation', (async, h) {
      h.controller.startStop();
      expect(h.controller.stopPhase, StopPhase.confirming);
      h.controller.cancelStop();
      async.flushMicrotasks();
      expect(h.interrupts, isEmpty);
      expect(h.controller.stopPhase, StopPhase.idle);
      expect(h.controller.canStop, isTrue);
    });

    flow('sends once; a second press while in flight opens nothing', (
      async,
      h,
    ) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? gate.future : tail('x');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      unawaited(h.controller.confirmStop());
      h.controller.startStop();
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.sending);
      expect(h.controller.canStop, isFalse);
      expect(h.interrupts, ['a1']);
      gate.complete({'found': true});
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.stopping);
      expect(h.interrupts, ['a1']);
      expect(h.outcomes, ['stopped']);
    });

    flow('goes to the agent it was started for whatever the list does', (
      async,
      h,
    ) {
      h.controller.startStop();
      h.host.update(
        () => h.host.current = const AgentView(
          state: AgentState.running,
          goal: 'another agent now sits here',
        ),
      );
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.interrupts, ['a1']);
      expect(h.transport.agentActions.single.threadId, 'secret-thread');
    });

    flow('closes with "That agent has ended." when the agent ends first', (
      async,
      h,
    ) {
      h.controller.startStop();
      h.host.end();
      expect(h.controller.stopPhase, StopPhase.ended);
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.interrupts, isEmpty);
    });

    flow('found false and the re-read still shows it running: not '
        'controllable here', (async, h) {
      h.transport.agentAnswer = (_) => {'found': false};
      h.host.reread = () async => running();
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.notControllable);
      expect(h.outcomes, ['not_controllable']);
      expect(h.interrupts, hasLength(1));
    });

    flow('found false and a successful re-read without the agent: already '
        'finished', (async, h) {
      h.transport.agentAnswer = (_) => {'found': false};
      h.host.reread = () async => gone();
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.alreadyFinished);
    });

    for (final (name, read)
        in <(String, Future<AgentWorkResult<AgentView?>> Function())>[
          ('fails', () async => const WorkFailed(WorkFailureKind.server)),
          ('is unsupported', () async => const WorkUnsupported()),
          ('is lost', () async => const WorkLost()),
          (
            'never answers',
            () => Completer<AgentWorkResult<AgentView?>>().future,
          ),
        ]) {
      flow('found false and a re-read that $name: unconfirmed within 10 s, '
          'Stop offered again behind a new confirmation', (async, h) {
        h.transport.agentAnswer = (call) =>
            call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
        h.host.reread = read;
        h.controller.startStop();
        unawaited(h.controller.confirmStop());
        async.flushMicrotasks();
        async.elapse(kStopCheckLimit);
        expect(h.controller.stopPhase, StopPhase.unconfirmed);
        expect(h.outcomes, ['unconfirmed']);
        expect(h.controller.canStop, isTrue);
        h.controller.startStop();
        expect(h.controller.stopPhase, StopPhase.confirming);
        expect(h.interrupts, hasLength(1), reason: 'nothing resent');
      });
    }

    flow('a lost answer checks, never resends, and a still running agent is '
        'unconfirmed', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      h.host.reread = () async => running();
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.host.rereads, 1);
      expect(h.controller.stopPhase, StopPhase.unconfirmed);
      expect(h.interrupts, hasLength(1));
    });

    flow('a lost answer and a re-read without the agent does not claim it '
        'had already finished', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      h.host.reread = () async => gone();
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.idle);
      expect(h.outcomes, ['unconfirmed']);
    });

    flow('a completion frame while checking after found false says it had '
        'already finished', (async, h) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.checking);
      h.host.end();
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.alreadyFinished);
    });

    flow('a note\'s check does not cut a stop check short', (async, h) {
      final stopRead = Completer<AgentWorkResult<AgentView?>>();
      var reads = 0;
      h.host.reread = () {
        reads++;
        return reads == 1 ? stopRead.future : Future.value(running());
      };
      h.transport.agentAnswer = (call) => switch (call.method) {
        'subagent.interrupt' => throw const GatewayRequestTimeout(),
        'subagent.steer' => {'status': 'rejected'},
        _ => tail('x'),
      };
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.checking);
      h.controller.setNote('hi');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.checking);
      stopRead.complete(gone());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.idle);
    });

    flow('a host that throws from the re-read still ends the check', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
      h.host.reread = () => throw StateError('boom');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.unconfirmed);
    });

    flow('calls after dispose do nothing and do not throw', (async, h) {
      h.controller.dispose();
      h.controller.cancelStop();
      h.controller.jumpToLatest();
      h.controller.startStop();
      h.controller.setNote('x');
      expect(h.controller.note, isEmpty);
    });

    flow('checking says so, and losing the connection ends it at once', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.checking);
      h.host.update(() => h.host.online = false);
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.unconfirmed);
      expect(h.controller.offline, isTrue);
      expect(h.controller.canStop, isFalse);
      h.host.update(() => h.host.online = true);
      async.elapse(const Duration(seconds: 30));
      expect(h.interrupts, hasLength(1), reason: 'nothing queued for later');
      expect(h.controller.canStop, isTrue);
    });

    for (final code in [4001, 5000]) {
      flow('error $code offers Stop again and sends nothing more', (async, h) {
        h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
            ? throw GatewayRpcException(code, 'x')
            : tail('x');
        h.controller.startStop();
        unawaited(h.controller.confirmStop());
        async.flushMicrotasks();
        expect(h.controller.stopPhase, StopPhase.failed);
        expect(h.controller.canStop, isTrue);
        async.elapse(const Duration(seconds: 30));
        expect(h.interrupts, hasLength(1));
        expect(h.outcomes, ['error']);
      });
    }

    flow('an unsupported server removes Stop', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRpcException(kGatewayMethodNotFound, 'x')
          : tail('x');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.unsupported);
      expect(h.controller.canStop, isFalse);
    });

    flow('a completion frame before the answer wins and the answer changes '
        'nothing', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? gate.future : tail('x');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      h.host.end();
      gate.complete({'found': false});
      async.flushMicrotasks();
      expect(h.controller.stopPhase, StopPhase.idle);
      expect(h.outcomes, ['already_ended']);
      expect(h.host.rereads, 0);
    });

    flow('offline: Stop cannot be started and nothing is sent', (async, h) {
      h.host.update(() => h.host.online = false);
      expect(h.controller.canStop, isFalse);
      h.controller.startStop();
      expect(h.controller.stopPhase, StopPhase.idle);
      expect(h.interrupts, isEmpty);
    });

    flow('an accepted stop turns a typed note into "Not sent"', (async, h) {
      h.controller.setNote('Only the Go modules');
      expect(h.controller.noteFrozen, isFalse);
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      expect(h.controller.noteFrozen, isTrue);
      expect(h.controller.note, 'Only the Go modules');
      expect(h.controller.canSendNote, isFalse);
      h.controller.setNote('changed');
      expect(h.controller.note, 'Only the Go modules');
    });
  });

  group('notes', () {
    flow('are sent once with trimmed text, clear on queued and are listed', (
      async,
      h,
    ) {
      h.controller.setNote('  Only the Go modules \n');
      unawaited(h.controller.sendNote());
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.steers, ['Only the Go modules']);
      expect(h.controller.note, isEmpty);
      expect(h.controller.sentNotes, ['Only the Go modules']);
      expect(h.controller.notePhase, NotePhase.queued);
      expect(h.outcomes, ['queued']);
    });

    flow('text typed while a note is in flight is kept', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? gate.future : tail('x');
      h.controller.setNote('Only Go');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      h.controller.setNote('Only Go modules, skip npm');
      gate.complete({'status': 'queued'});
      async.flushMicrotasks();
      expect(h.controller.sentNotes, ['Only Go']);
      expect(h.controller.note, 'Only Go modules, skip npm');
    });

    flow('a blank note cannot be sent', (async, h) {
      h.controller.setNote('  \n ');
      expect(h.controller.canSendNote, isFalse);
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.steers, isEmpty);
    });

    flow('the 4,000 limit counts the trimmed text', (async, h) {
      h.controller.setNote('${' ' * 20}${'x' * 4000}${' ' * 20}');
      expect(h.controller.noteLength, 4000);
      expect(h.controller.canSendNote, isTrue);
      h.controller.setNote('x' * 4001);
      expect(h.controller.noteTooLong, isTrue);
      expect(h.controller.canSendNote, isFalse);
      h.controller.setNote('😀' * 4000);
      expect(h.controller.canSendNote, isTrue);
    });

    flow('rejected keeps the text', (async, h) {
      h.host.current = const AgentView(
        state: AgentState.running,
        acceptingSteer: false,
      );
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? {'status': 'rejected'} : tail('x');
      h.controller.setNote('hello');
      expect(h.controller.canSendNote, isFalse);
      h.host.update(
        () => h.host.current = const AgentView(state: AgentState.running),
      );
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.controller.notePhase, NotePhase.rejected);
      expect(h.controller.note, 'hello');
    });

    flow('rejected by an agent the list says takes notes, still running '
        'after a re-read: not controllable here', (async, h) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? {'status': 'rejected'} : tail('x');
      h.host.reread = () async => running();
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.controller.notePhase, NotePhase.notControllable);
      expect(h.controller.note, 'hello');
      expect(h.controller.noteFrozen, isTrue);
      expect(h.controller.canSendNote, isFalse);
    });

    flow('rejected with a re-read that fails stays rejected', (async, h) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? {'status': 'rejected'} : tail('x');
      h.host.reread = () async => const WorkLost();
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.controller.notePhase, NotePhase.rejected);
    });

    flow('a lost answer keeps the text, enables Send and never resends', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.steer'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 60));
      expect(h.controller.notePhase, NotePhase.lost);
      expect(h.controller.note, 'hello');
      expect(h.controller.sentNotes, isEmpty);
      expect(h.controller.canSendNote, isTrue);
      expect(h.steers, hasLength(1));
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.steers, hasLength(2), reason: 'only a tap sends again');
    });

    for (final code in [4001, 5000]) {
      flow('error $code keeps the text', (async, h) {
        h.transport.agentAnswer = (call) => call.method == 'subagent.steer'
            ? throw GatewayRpcException(code, 'x')
            : tail('x');
        h.controller.setNote('hello');
        unawaited(h.controller.sendNote());
        async.flushMicrotasks();
        expect(h.controller.notePhase, NotePhase.failed);
        expect(h.controller.note, 'hello');
        expect(h.steers, hasLength(1));
      });
    }

    flow('an unsent note stays readable and unsendable after the agent ends', (
      async,
      h,
    ) {
      h.controller.setNote('hello');
      h.host.end();
      expect(h.controller.noteFrozen, isTrue);
      expect(h.controller.note, 'hello');
      expect(h.controller.canSendNote, isFalse);
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.steers, isEmpty);
    });

    flow('offline disables Send and keeps the text; nothing is queued', (
      async,
      h,
    ) {
      h.controller.setNote('hello');
      h.host.update(() => h.host.online = false);
      expect(h.controller.canSendNote, isFalse);
      expect(h.controller.note, 'hello');
      h.host.update(() => h.host.online = true);
      async.elapse(const Duration(seconds: 30));
      expect(h.steers, isEmpty);
      expect(h.controller.canSendNote, isTrue);
    });

    flow('a missed note is read from Hermes\' full notice prefixes only', (
      async,
      h,
    ) {
      h.controller.setNote('hi');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.controller.noteMissed, isFalse);
      h.host.end(AgentState.finished, 'Done. the steer did not land');
      expect(h.controller.noteMissed, isFalse);
      h.host.end(AgentState.finished, 'Done. $kMissedNoteInSummary: hi]');
      expect(h.controller.noteMissed, isTrue);
      expect(h.outcomes, ['queued', 'missed']);
      h.host.update(
        () => h.host.current = const AgentView(
          state: AgentState.failed,
          error: '$kMissedNoteInError: hi]',
        ),
      );
      expect(h.controller.noteMissed, isTrue);
      expect(h.outcomes.where((o) => o == 'missed'), hasLength(1));
    });

    flow('nothing is claimed about a note that was not queued', (async, h) {
      h.host.end(AgentState.finished, '$kMissedNoteInSummary: x]');
      expect(h.controller.noteMissed, isFalse);
    });

    test('closing with a note in flight lets it finish without a retry or '
        'an outcome, and a new detail starts empty', () {
      fakeAsync((async) {
        final h = Harness();
        final gate = Completer<Map<String, Object?>>();
        h.transport.agentAnswer = (call) =>
            call.method == 'subagent.steer' ? gate.future : tail('x');
        h.controller.setNote('hello');
        unawaited(h.controller.sendNote());
        async.flushMicrotasks();
        h.controller.dispose();
        expect(h.controller.note, isEmpty);
        expect(h.controller.sentNotes, isEmpty);
        gate.complete({'status': 'queued'});
        async.elapse(const Duration(seconds: 30));
        expect(h.steers, ['hello']);
        expect(h.events, isEmpty);
        final reopened = Harness();
        expect(reopened.controller.note, isEmpty);
        expect(reopened.controller.sentNotes, isEmpty);
        reopened.controller.dispose();
      });
    });
  });

  group('privacy', () {
    flow('events and breadcrumbs carry only fixed words', (async, h) {
      h.host.current = const AgentView(
        state: AgentState.running,
        goal: 'secret goal',
        acceptingSteer: true,
      );
      h.transport.agentAnswer = (call) => switch (call.method) {
        'subagent.tail' => tail('secret output'),
        'subagent.steer' => {'status': 'queued', 'text': 'secret note'},
        _ => {'found': true},
      };
      async.flushMicrotasks();
      h.controller.setNote('secret note');
      unawaited(h.controller.sendNote());
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      final seen = [
        for (final (name, attributes) in h.events) '$name $attributes',
        for (final crumb in h.trail.recent) '${crumb.name} ${crumb.attributes}',
      ].join(' ');
      expect(seen, isNot(contains('secret')));
      expect(
        [for (final crumb in h.trail.recent) crumb.name],
        containsAll([
          'subagent.redirect.sent',
          'subagent.stop.pressed',
          'subagent.stop.confirmed',
        ]),
      );
      expect([
        for (final (name, _) in h.events) name,
      ], everyElement(anyOf('subagent.stop', 'subagent.redirect')));
      expect(h.controller.toString(), isNot(contains('secret')));
      expect(h.host.view.toString(), isNot(contains('secret')));
    });

    flow('a logger that throws does not break the detail', (async, h) {
      final broken = SubagentDetailController(
        key: h.key,
        repository: SubagentRepository(h.transport),
        host: h.host,
        events: (name, [attributes = const {}]) => throw StateError('down'),
      );
      broken.startStop();
      unawaited(broken.confirmStop());
      async.flushMicrotasks();
      expect(broken.stopPhase, StopPhase.stopping);
      broken.dispose();
    });
  });
}
