import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recording_tracer.dart';
import 'memory_proposal_fixtures.dart';
import 'memory_proposal_support.dart';

void main() {
  late ScriptedSlashTransport transport;
  late RecordingTracer tracer;
  late List<String> events;
  late MemoryProposalsRepository repository;

  setUp(() {
    transport = ScriptedSlashTransport();
    tracer = RecordingTracer();
    events = [];
    repository = MemoryProposalsRepository(
      MemoryProposalSession(transport),
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        serverAttributes: const {'hermes.version': 'test'},
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
      ),
    );
  });

  group('MemoryProposalSession', () {
    test('runs each command in a new session of the profile', () async {
      transport.script['/memory pending'] = noPendingMemory;
      final session = MemoryProposalSession(transport);
      expect(await session.run('work', '/memory pending'), noPendingMemory);
      await session.run('work', '/memory pending');
      expect(transport.asked, [
        (null, 'work', '/memory pending'),
        (null, 'work', '/memory pending'),
      ]);
    });
  });

  group('load', () {
    test('reads both kinds in parallel', () async {
      final memory = Completer<String>(), skills = Completer<String>();
      transport.script['/memory pending'] = memory;
      transport.script['/skills pending'] = skills;
      final loading = repository.load('work');
      await pumpEventQueue();
      expect(transport.slashRuns, ['/memory pending', '/skills pending']);
      skills.complete(skillsPending);
      memory.complete(chatAddCut);
      final snapshot = await loading;
      expect(snapshot.memory.status, ProposalReadStatus.ok);
      expect(snapshot.skills.status, ProposalReadStatus.ok);
      expect(snapshot.count, 3);
      expect(
        [for (final p in snapshot.proposals) p.kind],
        [ProposalKind.memory, ProposalKind.skill, ProposalKind.skill],
      );
    });

    test('a kind that fails leaves the other readable', () async {
      transport.script['/memory pending'] = StateError('socket');
      transport.script['/skills pending'] = skillsPending;
      final snapshot = await repository.load('work');
      expect(snapshot.memory.status, ProposalReadStatus.failed);
      expect(snapshot.skills.status, ProposalReadStatus.ok);
      expect(snapshot.count, 2);
    });

    test('a command the server does not know is unsupported', () async {
      transport.script['/memory pending'] = unknownCommand;
      transport.script['/skills pending'] = noPendingSkills;
      final snapshot = await repository.load('work');
      expect(snapshot.memory.status, ProposalReadStatus.unsupported);
      expect(snapshot.skills.status, ProposalReadStatus.ok);
      expect(snapshot.count, 0);
    });

    test('an answer nobody can read keeps its text', () async {
      transport.script['/memory pending'] = 'Memory is on fire.';
      transport.script['/skills pending'] = noPendingSkills;
      final snapshot = await repository.load('work');
      expect(snapshot.memory.status, ProposalReadStatus.unreadable);
      expect(snapshot.memory.raw, 'Memory is on fire.');
    });

    test('an empty answer is readable and empty', () async {
      transport.script['/memory pending'] = noPendingMemory;
      transport.script['/skills pending'] = noPendingSkills;
      final snapshot = await repository.load('work');
      expect(snapshot.memory.status, ProposalReadStatus.ok);
      expect(snapshot.count, 0);
    });
  });

  group('diff', () {
    test('runs /skills diff and drops the progress line and header', () async {
      transport.script['/skills diff cc000001'] = skillDiffCreate;
      final text = await repository.diff('work', 'cc000001');
      expect(transport.slashRuns, ['/skills diff cc000001']);
      expect(text, startsWith('---\nname: contract-check'));
    });

    test('a failure is traced and rethrown', () async {
      transport.script['/skills diff cc000001'] = StateError('socket');
      await expectLater(
        repository.diff('work', 'cc000001'),
        throwsA(isA<StateError>()),
      );
      expect(tracer.spans.single.name, 'memory.proposals.diff');
      expect(tracer.spans.single.attributes['outcome'], 'failed');
    });
  });

  group('telemetry', () {
    test('a read is one span per kind with counts only', () async {
      transport.script['/memory pending'] = mixedMemoryPending;
      transport.script['/skills pending'] = StateError('private socket text');
      await repository.load('private-profile');
      final spans = tracer.spans;
      expect(spans.map((s) => s.name), everyElement('memory.proposals.fetch'));
      expect(spans.every((s) => s.ended), isTrue);
      expect(spans.map((s) => s.attributes), [
        {
          'hermes.version': 'test',
          'kind': 'memory',
          'count': 6,
          'outcome': 'ok',
        },
        {'hermes.version': 'test', 'kind': 'skill', 'outcome': 'failed'},
      ]);
      final exported = [
        ...spans.map((s) => '${s.attributes}'),
        ...events,
      ].join();
      expect(exported, isNot(contains('private')));
      expect(exported, isNot(contains('aa000001')));
      expect(exported, isNot(contains('Prefers')));
    });

    test('unknown lines are logged once with their count', () async {
      transport.script['/memory pending'] =
          'Heads up\nMore news\n$mixedMemoryPending';
      transport.script['/skills pending'] = skillsPending;
      await repository.load('work');
      expect(events, [
        "memory.proposals.parse_lenient {kind: memory, unknown_lines: 2}",
      ]);
    });

    test('a clean read logs nothing', () async {
      transport.script['/memory pending'] = mixedMemoryPending;
      transport.script['/skills pending'] = skillsPending;
      await repository.load('work');
      expect(events, isEmpty);
    });

    test('an unsupported kind is traced as such', () async {
      transport.script['/memory pending'] = unknownCommand;
      transport.script['/skills pending'] = noPendingSkills;
      await repository.load('work');
      expect(tracer.spans.first.attributes['outcome'], 'unsupported');
    });
  });
}
