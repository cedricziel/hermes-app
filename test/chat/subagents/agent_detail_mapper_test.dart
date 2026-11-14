import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/agent_detail_host.dart';
import 'package:hermes_app/src/chat/subagents/agent_detail_mapper.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/roster_row.dart';
import 'package:hermes_app/src/chat/subagents/subagent_detail_controller.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_detail_view.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_output_view.dart';

import '../../support/fake_chat_transport.dart';

const _goal =
    'Audit the dependency tree for packages with known '
    'vulnerabilities';

/// A host that follows one [RosterRow], as the roster's host does.
class MapperHost extends ChangeNotifier implements AgentDetailHost {
  MapperHost(this.row);

  final RosterRow row;
  @override
  bool online = true, readingAllowed = true, unlocked = true;

  /// Answers [rereadList]; null leaves it pending forever.
  Future<AgentWorkResult<AgentView?>> Function()? reread;

  @override
  Listenable get changes => this;

  @override
  AgentView? get view => row.toView();

  @override
  Future<AgentWorkResult<AgentView?>> rereadList() =>
      reread?.call() ?? Completer<AgentWorkResult<AgentView?>>().future;

  /// Changes the row and tells the controller, as a frame or a list read does.
  void change(void Function(RosterRow row) edit) {
    edit(row);
    notifyListeners();
  }

  void set(void Function() edit) {
    edit();
    notifyListeners();
  }
}

class MapperHarness {
  MapperHarness({RosterRow? row, Duration age = Duration.zero})
    : row =
          row ??
          (RosterRow(id: 'a1', order: 0, goal: _goal)
            ..acceptingSteer = true
            ..startedAt = clock.now().subtract(age)) {
    host = MapperHost(this.row);
    controller = SubagentDetailController(
      key: AgentKey(
        threadId: 't',
        profile: null,
        connection: Object(),
        subagentId: 'a1',
      ),
      repository: SubagentRepository(transport),
      host: host,
    );
    transport.agentAnswer = (call) => switch (call.method) {
      'subagent.tail' => tail('output'),
      'subagent.interrupt' => {'found': true},
      _ => {'status': 'queued'},
    };
  }

  final RosterRow row;
  late final MapperHost host;
  late final SubagentDetailController controller;
  final transport = FakeChatTransport();

  AgentDetailModel get model =>
      agentDetailModel(row: row, controller: controller, readOnly: false);
}

Map<String, Object?> tail(
  String text, {
  bool available = true,
  bool truncated = false,
}) => {'available': available, 'text': text, 'truncated': truncated};

void flow(String name, void Function(FakeAsync async, MapperHarness h) body) {
  test(name, () {
    fakeAsync((async) {
      final h = MapperHarness();
      body(async, h);
      h.controller.dispose();
    });
  });
}

AgentWorkResult<AgentView?> _running() =>
    const WorkOk(AgentView(state: AgentState.running, acceptingSteer: true));
AgentWorkResult<AgentView?> _gone() => const WorkOk(null);

void main() {
  group('the plain row', () {
    test('maps what the row says, with no controller', () {
      final row =
          RosterRow(id: 'a1', order: 0, goal: _goal, state: AgentState.finished)
            ..toolCount = 4
            ..lastTool = 'web_search'
            ..summary = 'Three packages need an update.'
            ..duration = const Duration(seconds: 95);
      final model = agentDetailModel(
        row: row,
        controller: null,
        readOnly: false,
      );
      expect(model.goal, _goal);
      expect(model.state, AgentState.finished);
      expect(model.toolCount, 4);
      expect(model.currentTool, 'web_search');
      expect(model.delivered, 'Three packages need an update.');
      expect(model.runTime, const Duration(seconds: 95));
      expect(model.error, isNull);
      expect(model.output, isNull);
      expect(model.note, isNull);
      expect(model.stop, AgentStopStatus.idle);
      expect(model.offline, isFalse);
    });

    test('a row without a tool count shows none used', () {
      final model = agentDetailModel(
        row: RosterRow(id: 'a1', order: 0, goal: _goal),
        controller: null,
        readOnly: false,
      );
      expect(model.toolCount, 0);
      expect(model.currentTool, isNull);
    });

    test('startedByAgent follows parentId', () {
      RosterRow rowWith(String? parent) =>
          RosterRow(id: 'a2', order: 1, goal: _goal, parentId: parent);
      bool started(RosterRow row) => agentDetailModel(
        row: row,
        controller: null,
        readOnly: false,
      ).startedByAgent;
      expect(started(rowWith('a1')), isTrue);
      expect(started(rowWith(null)), isFalse);
    });

    test('a failed delegation row carries its error and no live sections', () {
      fakeAsync((async) {
        final h = MapperHarness(
          row:
              RosterRow(
                  id: 'd1#0',
                  order: 0,
                  goal: _goal,
                  state: AgentState.failed,
                )
                ..delegationOnly = true
                ..error = 'The provider refused the request.',
        );
        async.flushMicrotasks();
        final model = agentDetailModel(
          row: h.row,
          controller: h.controller,
          readOnly: false,
        );
        expect(model.error, 'The provider refused the request.');
        expect(model.output, isNull);
        expect(model.note, isNull);
        expect(model.stop, AgentStopStatus.idle);
        h.controller.dispose();
      });
    });

    flow('readOnly gives no output, note or stop even with a controller', (
      async,
      h,
    ) {
      async.flushMicrotasks();
      h.controller.setNote('typed');
      final model = agentDetailModel(
        row: h.row,
        controller: h.controller,
        readOnly: true,
      );
      expect(model.goal, _goal);
      expect(model.output, isNull);
      expect(model.note, isNull);
      expect(model.stop, AgentStopStatus.notControllable);
    });
  });

  group('run time', () {
    final now = DateTime.utc(2030, 1, 1, 12);
    Duration? timeOf(RosterRow row) => withClock(
      Clock.fixed(now),
      () =>
          agentDetailModel(row: row, controller: null, readOnly: false).runTime,
    );

    test('counts from the start while it runs', () {
      final row = RosterRow(id: 'a1', order: 0, goal: _goal)
        ..startedAt = now.subtract(const Duration(minutes: 2, seconds: 5))
        ..duration = const Duration(seconds: 1);
      expect(timeOf(row), const Duration(minutes: 2, seconds: 5));
      row.state = AgentState.starting;
      expect(timeOf(row), const Duration(minutes: 2, seconds: 5));
    });

    test('uses the reported duration once it ended', () {
      final row =
          RosterRow(id: 'a1', order: 0, goal: _goal, state: AgentState.finished)
            ..startedAt = now.subtract(const Duration(hours: 1))
            ..duration = const Duration(seconds: 42);
      expect(timeOf(row), const Duration(seconds: 42));
    });

    test('is unknown without a start while running, or a duration after', () {
      expect(timeOf(RosterRow(id: 'a1', order: 0, goal: _goal)), isNull);
      expect(
        timeOf(
          RosterRow(id: 'a1', order: 0, goal: _goal, state: AgentState.stopped)
            ..startedAt = now.subtract(const Duration(minutes: 1)),
        ),
        isNull,
      );
    });

    test('a start in the future reads as zero', () {
      final row = RosterRow(id: 'a1', order: 0, goal: _goal)
        ..startedAt = now.add(const Duration(seconds: 30));
      expect(timeOf(row), Duration.zero);
    });

    test('agentRunTime moves with the clock while running', () {
      final row = RosterRow(id: 'a1', order: 0, goal: _goal)..startedAt = now;
      expect(
        withClock(
          Clock.fixed(now.add(const Duration(seconds: 7))),
          () => agentRunTime(row),
        ),
        const Duration(seconds: 7),
      );
    });
  });

  group('output', () {
    flow('is loading until the first read answers', (async, h) {
      expect(h.model.output!.status, AgentOutputStatus.loading);
      async.flushMicrotasks();
      expect(h.model.output!.status, AgentOutputStatus.ready);
      expect(h.model.output!.text, 'output');
      expect(h.model.output!.last, isFalse);
    });

    flow('available false is "none" for a young agent', (async, h) {
      h.transport.agentAnswer = (_) => tail('', available: false);
      async.flushMicrotasks();
      expect(h.model.output!.status, AgentOutputStatus.none);
      expect(h.model.output!.text, isEmpty);
    });

    test('available false is "never" 30 s after the agent started', () {
      fakeAsync((async) {
        final h = MapperHarness(age: const Duration(minutes: 2));
        h.transport.agentAnswer = (_) => tail('', available: false);
        async.flushMicrotasks();
        expect(h.model.output!.status, AgentOutputStatus.never);
        h.controller.dispose();
      });
    });

    flow('an unsupported tail leaves the section out', (async, h) {
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'x');
      async.flushMicrotasks();
      expect(h.model.output, isNull);
      expect(h.model.note, isNotNull, reason: 'notes are a separate method');
    });

    flow('a truncated answer says so only when there is text', (async, h) {
      h.transport.agentAnswer = (_) =>
          tail('line one\nline two\nline three', truncated: true);
      async.flushMicrotasks();
      expect(h.model.output!.truncated, isTrue);
      h.transport.agentAnswer = (_) => tail('', truncated: true);
      async.elapse(kTailEvery);
      expect(h.model.output!.text, isEmpty);
      expect(h.model.output!.truncated, isFalse);
    });

    flow('a failed refresh keeps the text and flags it', (async, h) {
      async.flushMicrotasks();
      h.transport.agentAnswer = (_) =>
          throw const GatewayRpcException(5000, 'x');
      async.elapse(kTailEvery);
      final output = h.model.output!;
      expect(output.refreshFailed, isTrue);
      expect(output.text, 'output');
      expect(output.status, AgentOutputStatus.ready);
    });

    flow('paused while the reader holds the text', (async, h) {
      async.flushMicrotasks();
      h.controller.setReaderHolding(true);
      h.transport.agentAnswer = (_) => tail('newer');
      async.elapse(kTailEvery);
      expect(h.model.output!.paused, isTrue);
      expect(h.model.output!.text, 'output');
      h.controller.jumpToLatest();
      expect(h.model.output!.paused, isFalse);
      expect(h.model.output!.text, 'newer');
    });

    flow('is the last output once the agent ended', (async, h) {
      async.flushMicrotasks();
      expect(h.model.output!.last, isFalse);
      h.host.change(
        (row) => row
          ..state = AgentState.finished
          ..summary = 'Done.',
      );
      expect(h.model.output!.last, isTrue);
      expect(h.model.output!.text, 'output');
    });

    flow('an ended agent that never showed output has no "last output"', (
      async,
      h,
    ) {
      h.transport.agentAnswer = (_) => tail('', available: false);
      async.flushMicrotasks();
      h.host.change((row) => row.state = AgentState.finished);
      expect(h.model.output!.last, isFalse);
    });
  });

  group('the note', () {
    flow('starts idle and empty', (async, h) {
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.idle);
      expect(note.text, isEmpty);
      expect(note.length, 0);
      expect(note.frozen, isFalse);
      expect(note.canSend, isFalse);
      expect(note.goal, _goal);
      expect(note.sentNotes, isEmpty);
      expect(note.offline, isFalse);
    });

    flow('counts the trimmed text and can send it', (async, h) {
      h.controller.setNote('  Only the Go modules \n');
      final note = h.model.note!;
      expect(note.text, '  Only the Go modules \n');
      expect(note.length, 'Only the Go modules'.length);
      expect(note.canSend, isTrue);
    });

    flow('sending', (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? gate.future : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.sending);
      expect(note.canSend, isFalse);
    });

    flow('queued lists the note and clears the text', (async, h) {
      h.controller.setNote('Only the Go modules');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.queued);
      expect(note.sentNotes, ['Only the Go modules']);
      expect(note.text, isEmpty);
    });

    flow('rejected keeps the text', (async, h) {
      h.row.acceptingSteer = null;
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? {'status': 'rejected'} : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.rejected);
      expect(note.text, 'hello');
    });

    flow('rejected by an agent that takes notes, still running: not '
        'controllable', (async, h) {
      h.host.reread = () async => _running();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.steer' ? {'status': 'rejected'} : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.notControllable);
      expect(note.frozen, isTrue);
      expect(note.text, 'hello');
    });

    flow('a lost answer', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.steer'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.lost);
      expect(note.canSend, isTrue, reason: 'only a tap sends it again');
      expect(note.text, 'hello');
    });

    flow('a failed send', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.steer'
          ? throw const GatewayRpcException(5000, 'x')
          : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      expect(h.model.note!.status, AgentNoteStatus.failed);
    });

    flow('an unsupported server', (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.steer'
          ? throw const GatewayRpcException(kGatewayMethodNotFound, 'x')
          : tail('x');
      h.controller.setNote('hello');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.status, AgentNoteStatus.unsupported);
      expect(note.canSend, isFalse);
    });

    flow('missed is read from the Hermes notice in the summary', (async, h) {
      h.controller.setNote('hi');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      h.host.change(
        (row) => row
          ..state = AgentState.finished
          ..summary = 'Done. thanks, the steer did not land',
      );
      expect(
        h.model.note!.status,
        AgentNoteStatus.queued,
        reason: 'a paraphrase is not the notice',
      );
      h.host.change((row) => row.summary = 'Done. $kMissedNoteInSummary: hi]');
      expect(h.model.note!.status, AgentNoteStatus.missed);
    });

    flow('missed is read from the Hermes notice in a failure\'s error', (
      async,
      h,
    ) {
      h.controller.setNote('hi');
      unawaited(h.controller.sendNote());
      async.flushMicrotasks();
      h.host.change(
        (row) => row
          ..state = AgentState.failed
          ..error = 'Boom $kMissedNoteInError: hi]',
      );
      expect(h.model.note!.status, AgentNoteStatus.missed);
    });

    flow('a notice without a queued note claims nothing', (async, h) {
      h.host.change(
        (row) => row
          ..state = AgentState.finished
          ..summary = '$kMissedNoteInSummary: x]',
      );
      expect(h.model.note!.status, AgentNoteStatus.idle);
    });
  });

  group('the note is frozen or left out', () {
    flow('frozen once a stop was accepted, keeping the text', (async, h) {
      h.controller.setNote('Only the Go modules');
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
      final note = h.model.note!;
      expect(note.frozen, isTrue);
      expect(note.text, 'Only the Go modules');
      expect(note.canSend, isFalse);
    });

    flow('frozen when the agent ended with text typed', (async, h) {
      h.controller.setNote('unsent');
      h.host.change((row) => row.state = AgentState.finished);
      final note = h.model.note!;
      expect(note.frozen, isTrue);
      expect(note.text, 'unsent');
      expect(note.canSend, isFalse);
    });

    flow('frozen when accepting_steer turns false with text typed', (async, h) {
      h.controller.setNote('unsent');
      h.host.change((row) => row.acceptingSteer = false);
      final note = h.model.note!;
      expect(note, isNotNull);
      expect(note.frozen, isTrue);
      expect(note.text, 'unsent');
      expect(note.canSend, isFalse);
    });

    flow('left out when an active agent takes no notes and nothing is typed', (
      async,
      h,
    ) {
      h.host.change((row) => row.acceptingSteer = false);
      expect(h.model.note, isNull);
      expect(h.model.output, isNotNull);
    });

    flow('an agent whose list never said still gets the field', (async, h) {
      h.host.change((row) => row.acceptingSteer = null);
      expect(h.model.note, isNotNull);
      expect(h.model.note!.frozen, isFalse);
    });

    flow('an ended agent keeps its note model for the view to hide', (
      async,
      h,
    ) {
      h.host.change(
        (row) => row
          ..state = AgentState.finished
          ..acceptingSteer = false,
      );
      expect(h.model.note, isNotNull);
      expect(h.model.note!.text, isEmpty);
    });
  });

  group('offline', () {
    flow('carries through to the model, the note and Send', (async, h) {
      h.controller.setNote('hello');
      expect(h.model.note!.canSend, isTrue);
      h.host.set(() => h.host.online = false);
      final model = h.model;
      expect(model.offline, isTrue);
      expect(model.note!.offline, isTrue);
      expect(model.note!.canSend, isFalse);
      expect(model.note!.text, 'hello');
      expect(model.output!.text, isEmpty, reason: 'nothing was read yet');
    });
  });

  group('stop', () {
    // Every phase, and how to reach it. The last test checks none is missing.
    final covered = <StopPhase>{};

    void phase(
      String name,
      StopPhase expectedPhase,
      AgentStopStatus expectedStatus,
      void Function(FakeAsync async, MapperHarness h) arrange,
    ) {
      covered.add(expectedPhase);
      flow('$name maps to $expectedStatus', (async, h) {
        arrange(async, h);
        expect(h.controller.stopPhase, expectedPhase);
        expect(h.model.stop, expectedStatus);
      });
    }

    void press(FakeAsync async, MapperHarness h) {
      h.controller.startStop();
      unawaited(h.controller.confirmStop());
      async.flushMicrotasks();
    }

    phase('idle', StopPhase.idle, AgentStopStatus.idle, (async, h) {});

    phase(
      'confirming (a dialog is open, the detail is unchanged)',
      StopPhase.confirming,
      AgentStopStatus.idle,
      (async, h) => h.controller.startStop(),
    );

    phase('sending', StopPhase.sending, AgentStopStatus.sending, (async, h) {
      final gate = Completer<Map<String, Object?>>();
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? gate.future : tail('x');
      press(async, h);
    });

    phase('checking', StopPhase.checking, AgentStopStatus.checking, (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRequestTimeout()
          : tail('x');
      press(async, h);
    });

    phase('stopping', StopPhase.stopping, AgentStopStatus.stopping, (async, h) {
      press(async, h);
    });

    phase(
      'alreadyFinished',
      StopPhase.alreadyFinished,
      AgentStopStatus.alreadyFinished,
      (async, h) {
        h.transport.agentAnswer = (call) =>
            call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
        h.host.reread = () async => _gone();
        press(async, h);
      },
    );

    phase(
      'notControllable',
      StopPhase.notControllable,
      AgentStopStatus.notControllable,
      (async, h) {
        h.transport.agentAnswer = (call) =>
            call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
        h.host.reread = () async => _running();
        press(async, h);
      },
    );

    phase('unconfirmed', StopPhase.unconfirmed, AgentStopStatus.unconfirmed, (
      async,
      h,
    ) {
      h.transport.agentAnswer = (call) =>
          call.method == 'subagent.interrupt' ? {'found': false} : tail('x');
      h.host.reread = () async => const WorkFailed(WorkFailureKind.server);
      press(async, h);
    });

    phase('failed', StopPhase.failed, AgentStopStatus.failed, (async, h) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRpcException(5000, 'x')
          : tail('x');
      press(async, h);
    });

    phase('unsupported', StopPhase.unsupported, AgentStopStatus.unsupported, (
      async,
      h,
    ) {
      h.transport.agentAnswer = (call) => call.method == 'subagent.interrupt'
          ? throw const GatewayRpcException(kGatewayMethodNotFound, 'x')
          : tail('x');
      press(async, h);
    });

    phase('ended', StopPhase.ended, AgentStopStatus.ended, (async, h) {
      h.controller.startStop();
      h.host.change((row) => row.state = AgentState.finished);
    });

    test('every StopPhase is covered above', () {
      expect(covered, StopPhase.values.toSet());
    });
  });
}
