import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_chat_transport.dart';
import '../support/recording_tracer.dart';
import 'memory_proposal_fixtures.dart';
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

    test('the lines Hermes adds about the entry are not failures', () {
      for (final (answer, entry) in [
        (approvedReplace, 'bb000002'),
        (approvedPatch, 'bb000003'),
        (approvedRemove, 'bb000004'),
      ]) {
        expect(
          parseMemoryDecisionAnswer(answer, id: entry, approve: true).phase,
          MemoryDecisionPhase.saved,
          reason: answer,
        );
      }
    });

    test('a pinned entry that changed fails with Hermes reason', () {
      final state = parseMemoryDecisionAnswer(
        approvedPinnedChanged,
        id: 'aa000003',
        approve: true,
      );
      expect(state.phase, MemoryDecisionPhase.failed);
      expect(state.text, startsWith('Entry changed since it was staged'));
    });

    test('a skill answer behind its progress line', () {
      expect(
        parseMemoryDecisionAnswer(
          rejectedSkill,
          id: 'cc000001',
          approve: false,
          kind: ProposalKind.skill,
        ).phase,
        MemoryDecisionPhase.rejected,
      );
      expect(
        parseMemoryDecisionAnswer(
          '⏳ Processing skills command...\nApproved 1 skills write(s).',
          id: 'cc000001',
          approve: true,
          kind: ProposalKind.skill,
        ).phase,
        MemoryDecisionPhase.saved,
      );
      expect(
        parseMemoryDecisionAnswer(
          rejectedSkill,
          id: 'cc000001',
          approve: false,
        ).phase,
        MemoryDecisionPhase.failed,
      );
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
        'kind': 'memory',
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

    test('a skill proposal is decided with /skills', () async {
      transport.slashResult = answer(
        '⏳ Processing skills command...\nApproved 1 skills write(s).',
      );
      await decisions.decide(
        'cc000001',
        approve: true,
        kind: ProposalKind.skill,
      );
      transport.slashResult = answer(rejectedSkill);
      await decisions.decide(
        'cc000002',
        approve: false,
        kind: ProposalKind.skill,
      );
      expect(transport.slashRuns, [
        '/skills approve cc000001',
        '/skills reject cc000002',
      ]);
      expect(decisions.stateOf('cc000001').phase, MemoryDecisionPhase.saved);
    });

    group('in the inbox', () {
      late MemoryDecisions inbox;

      setUp(() {
        inbox = MemoryDecisions(
          available: () => true,
          surface: 'inbox',
          run: (command) async =>
              (await transport.runSlashCommand(command: command)).output,
          telemetry: ConnectionTelemetry(
            tracer: tracer,
            events: (name, [attributes = const {}]) =>
                events.add('$name $attributes'),
          ),
          breadcrumbs: Breadcrumbs.of(trail),
        );
        addTearDown(inbox.dispose);
      });

      MemoryProposal proposal(
        String id, [
        ProposalKind kind = ProposalKind.memory,
      ]) => MemoryProposal(
        id: id,
        kind: kind,
        action: ProposalAction.add,
        background: false,
        summary: 'secret text',
      );

      test('names its surface on the span, event and crumb', () async {
        transport.slashResult = answer(approvedAnswer);
        await inbox.decide(id, approve: true);
        expect(
          tracer.spans.single.attributes,
          containsPair('surface', 'inbox'),
        );
        expect(tracer.spans.single.attributes, containsPair('kind', 'memory'));
        expect(events.single, contains('inbox'));
        expect(trail.recent.single.name, 'memory.inbox.decide');
        expect(trail.recent.single.attributes, {'choice': 'approve'});
      });

      test('decideAll sends one command per id and never all', () async {
        transport.slashResult = answer(approvedAnswer);
        await inbox.decideAll([
          proposal('aaaaaaa1'),
          proposal('aaaaaaa2'),
          proposal('cccccccc', ProposalKind.skill),
        ], approve: true);
        expect(transport.slashRuns, [
          '/memory approve aaaaaaa1',
          '/memory approve aaaaaaa2',
          '/skills approve cccccccc',
        ]);
        expect(transport.slashRuns.join(), isNot(contains('all')));
      });

      test('decideAll goes on after a refusal by Hermes', () async {
        transport.slashResult = answer(unknownIdAnswer);
        await inbox.decideAll([
          proposal('aaaaaaa1'),
          proposal('aaaaaaa2'),
        ], approve: false);
        expect(transport.slashRuns, hasLength(2));
        expect(inbox.stateOf('aaaaaaa1').phase, MemoryDecisionPhase.failed);
      });

      test('decideAll stops at the first transport error', () async {
        final runs = <String>[];
        final broken = MemoryDecisions(
          available: () => true,
          surface: 'inbox',
          run: (command) async {
            runs.add(command);
            throw StateError('socket');
          },
        );
        addTearDown(broken.dispose);
        await broken.decideAll([
          proposal('aaaaaaa1'),
          proposal('aaaaaaa2'),
        ], approve: true);
        expect(runs, ['/memory approve aaaaaaa1']);
        expect(broken.stateOf('aaaaaaa1').phase, MemoryDecisionPhase.failed);
        expect(broken.stateOf('aaaaaaa2').phase, MemoryDecisionPhase.idle);
      });

      test(
        'decideAll is one span and one event with the bulk choice',
        () async {
          transport.slashResult = answer(rejectedAnswer);
          await inbox.decideAll([
            proposal('aaaaaaa1'),
            proposal('aaaaaaa2'),
            proposal('aaaaaaa3'),
          ], approve: false);
          expect(tracer.spans, hasLength(1));
          expect(tracer.spans.single.attributes['choice'], 'reject_all');
          expect(tracer.spans.single.attributes['outcome'], 'rejected');
          expect(events, hasLength(1));
          expect(events.single, contains('reject_all'));
          expect(trail.recent.single.attributes, {'choice': 'reject_all'});
          final exported = [
            ...tracer.spans.map((span) => '${span.attributes}'),
            ...events,
            ...trail.recent.map((crumb) => '${crumb.attributes}'),
          ].join(' ');
          expect(exported, isNot(contains('aaaaaaa')));
          expect(exported, isNot(contains('secret')));
        },
      );

      test('decideAll with nothing to decide does nothing', () async {
        await inbox.decideAll(const [], approve: true);
        expect(transport.slashRuns, isEmpty);
        expect(tracer.spans, isEmpty);
      });
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
