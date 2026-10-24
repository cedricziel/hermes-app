import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_chat_transport.dart';
import '../support/recording_tracer.dart';
import 'memory_tool_fixtures.dart';

const id = '1a2b3c4d';

void main() {
  group('parseMemoryDecisionAnswer', () {
    MemoryDecisionState approve(String answer) =>
        parseMemoryDecisionAnswer(answer, id: id, approve: true);

    test('approved', () {
      expect(approve(approvedAnswer).phase, MemoryDecisionPhase.saved);
    });

    test('failed for this id shows its reason', () {
      final state = approve(approvedButFailedAnswer);
      expect(state.phase, MemoryDecisionPhase.failed);
      expect(state.text, 'The entry changed since it was staged.');
    });

    test('a failure for another id does not fail this one', () {
      expect(approve(failedForOtherIdAnswer).phase, MemoryDecisionPhase.saved);
    });

    test('rejected', () {
      final state = parseMemoryDecisionAnswer(
        rejectedAnswer,
        id: id,
        approve: false,
      );
      expect(state.phase, MemoryDecisionPhase.rejected);
    });

    test('anything else is a failure with the whole text', () {
      for (final approving in [true, false]) {
        final state = parseMemoryDecisionAnswer(
          unknownIdAnswer,
          id: id,
          approve: approving,
        );
        expect(state.phase, MemoryDecisionPhase.failed);
        expect(state.text, unknownIdAnswer);
      }
      expect(
        parseMemoryDecisionAnswer(approvedAnswer, id: id, approve: false).phase,
        MemoryDecisionPhase.failed,
      );
      expect(
        approve('Approved 0 memory write(s).').phase,
        MemoryDecisionPhase.failed,
      );
    });
  });

  group('MemoryDecisions', () {
    late FakeChatTransport transport;
    late RecordingTracer tracer;
    late List<String> events;
    late BreadcrumbTrail trail;
    late bool stored;
    late MemoryDecisions decisions;

    setUp(() {
      transport = FakeChatTransport();
      tracer = RecordingTracer();
      events = [];
      trail = BreadcrumbTrail();
      stored = true;
      decisions = MemoryDecisions(
        available: () => stored,
        run: (command) async {
          final result = await transport.runSlashCommand(
            threadId: 'chat-thread',
            profile: 'work',
            command: command,
          );
          return result.output;
        },
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          serverAttributes: const {'hermes.version': 'test'},
          events: (name, [attributes = const {}]) =>
              events.add('$name $attributes'),
        ),
        breadcrumbs: Breadcrumbs.of(trail),
      );
      addTearDown(decisions.dispose);
    });

    SlashCommandResult answer(String output) =>
        SlashCommandResult(threadId: 'chat-thread', output: output);

    test('approve runs the command and ends saved', () async {
      transport.slashResult = answer(approvedAnswer);
      await decisions.decide(id, approve: true);
      expect(transport.slashRuns, ['/memory approve $id']);
      expect(decisions.stateOf(id).phase, MemoryDecisionPhase.saved);
    });

    test('reject runs the command and ends rejected', () async {
      transport.slashResult = answer(rejectedAnswer);
      await decisions.decide(id, approve: false);
      expect(transport.slashRuns, ['/memory reject $id']);
      expect(decisions.stateOf(id).phase, MemoryDecisionPhase.rejected);
    });

    test('a failure keeps the buttons and shows the text', () async {
      transport.slashResult = answer(approvedButFailedAnswer);
      await decisions.decide(id, approve: true);
      final state = decisions.stateOf(id);
      expect(state.phase, MemoryDecisionPhase.failed);
      expect(state.text, 'The entry changed since it was staged.');
      expect(state.canDecide, isTrue);
    });

    test('runs one decision per id at a time', () async {
      final gate = transport.slashGate = Completer<SlashCommandResult>();
      final first = decisions.decide(id, approve: true);
      expect(decisions.stateOf(id).phase, MemoryDecisionPhase.running);
      expect(decisions.stateOf(id).canDecide, isFalse);
      await decisions.decide(id, approve: false);
      gate.complete(answer(approvedAnswer));
      await first;
      expect(transport.slashRuns, ['/memory approve $id']);
      expect(decisions.stateOf(id).phase, MemoryDecisionPhase.saved);
    });

    test('a saved or rejected proposal cannot be decided again', () async {
      transport.slashResult = answer(approvedAnswer);
      await decisions.decide(id, approve: true);
      await decisions.decide(id, approve: false);
      expect(transport.slashRuns, hasLength(1));
    });

    test('a transport error is unreachable and keeps the buttons', () async {
      final unreachable = MemoryDecisions(
        available: () => true,
        run: (_) => throw StateError('socket'),
      );
      addTearDown(unreachable.dispose);
      await unreachable.decide(id, approve: true);
      final state = unreachable.stateOf(id);
      expect(state.phase, MemoryDecisionPhase.failed);
      expect(state.text, "Couldn't reach Hermes. Try again.");
      expect(state.canDecide, isTrue);
    });

    test('offers nothing without a stored thread', () async {
      stored = false;
      expect(decisions.available(), isFalse);
      await decisions.decide(id, approve: true);
      expect(transport.slashRuns, isEmpty);
    });

    test('notifies listeners as the state changes', () async {
      transport.slashResult = answer(approvedAnswer);
      var changes = 0;
      decisions.addListener(() => changes++);
      await decisions.decide(id, approve: true);
      expect(changes, 2);
    });

    test('records a span, an event and a crumb without ids or text', () async {
      transport.slashResult = answer(approvedAnswer);
      await decisions.decide(id, approve: true);
      transport.slashResult = answer(unknownIdAnswer);
      await decisions.decide('ffffffff', approve: false);
      final span = tracer.spans.first;
      expect(span.name, 'memory.proposals.decide');
      expect(span.ended, isTrue);
      expect(span.attributes, {
        'hermes.version': 'test',
        'choice': 'approve',
        'surface': 'tool_card',
        'outcome': 'saved',
      });
      expect(tracer.spans.last.attributes['outcome'], 'failed');
      expect(events.first, startsWith('memory.proposal_decided'));
      expect(events.first, contains('approve'));
      expect(events.first, contains('saved'));
      expect(events.first, contains('tool_card'));
      expect(
        trail.recent.map((crumb) => crumb.name),
        everyElement('memory.tool_card.decide'),
      );
      final exported = [
        ...tracer.spans.map((span) => '${span.attributes}'),
        ...events,
        ...trail.recent.map((crumb) => '${crumb.attributes}'),
      ].join(' ');
      expect(exported, isNot(contains(id)));
      expect(exported, isNot(contains('ffffffff')));
      expect(exported, isNot(contains('chat-thread')));
      expect(exported, isNot(contains('work')));
    });

    test('an unreachable decision is traced as such', () async {
      final spans = RecordingTracer();
      final unreachable = MemoryDecisions(
        available: () => true,
        run: (_) => throw StateError('socket'),
        telemetry: ConnectionTelemetry(tracer: spans),
      );
      addTearDown(unreachable.dispose);
      await unreachable.decide(id, approve: true);
      expect(spans.spans.single.attributes['outcome'], 'unreachable');
    });
  });
}
