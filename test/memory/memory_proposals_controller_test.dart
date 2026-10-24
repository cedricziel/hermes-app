import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals_controller.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';

import 'memory_proposal_fixtures.dart';
import 'memory_proposal_support.dart';

const twoMemory =
    'Pending memory writes (2):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002 [auto]  background review consolidation (remove on memory): - remove: tabs\n'
    '      removes entry: Prefers tabs in Go\n';

void main() {
  late ScriptedSlashTransport transport;
  late MemoryProposalsController controller;
  late MemoryProposalsRepository repository;

  MemoryProposalsController bound([String profile = 'work']) {
    controller.bind(repository, profile);
    return controller;
  }

  setUp(() {
    transport = ScriptedSlashTransport()
      ..script['/memory pending'] = twoMemory
      ..script['/skills pending'] = noPendingSkills;
    repository = MemoryProposalsRepository(MemoryProposalSession(transport));
    controller = MemoryProposalsController();
    addTearDown(controller.dispose);
  });

  test(
    'binding reads the profile once and selects the first proposal',
    () async {
      bound();
      expect(controller.loading, isTrue);
      await controller.whenIdle;
      expect(controller.loading, isFalse);
      expect(controller.waiting, 2);
      expect(controller.selected?.id, 'aa000001');
      expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
    },
  );

  test(
    'waiting is unknown until a read worked and empty when nothing waits',
    () async {
      expect(controller.waiting, isNull);
      transport.script['/memory pending'] = StateError('socket');
      transport.script['/skills pending'] = StateError('socket');
      bound();
      await controller.whenIdle;
      expect(controller.waiting, isNull);
      transport.script['/memory pending'] = noPendingMemory;
      await controller.load();
      expect(controller.waiting, 0);
    },
  );

  test(
    'approving runs the command, says where it was saved and reads again',
    () async {
      bound();
      await controller.whenIdle;
      transport.script['/memory approve aa000001'] =
          'Approved 1 memory write(s).';
      transport.script['/memory pending'] =
          'Pending memory writes (1):\n'
          '  aa000002 [auto]  background review consolidation (remove on memory): - remove: tabs\n'
          '      removes entry: Prefers tabs in Go\n';
      await controller.decide(
        controller.snapshot!.proposals.first,
        approve: true,
      );
      expect(transport.slashRuns, contains('/memory approve aa000001'));
      expect(
        transport.slashRuns.where((c) => c == '/memory pending'),
        hasLength(2),
      );
      expect(controller.notice?.title, 'Saved to About you');
      expect(controller.notice?.detail, 'Hermes uses it from the next chat.');
      expect(controller.notice?.isError, isFalse);
      expect(controller.waiting, 1);
      expect(controller.selected?.id, 'aa000002');
    },
  );

  test('a rejection says Rejected', () async {
    bound();
    await controller.whenIdle;
    transport.script['/memory reject aa000002'] =
        "Rejected pending memory write 'aa000002'.";
    await controller.decide(
      controller.snapshot!.proposals.last,
      approve: false,
    );
    expect(controller.notice?.title, 'Rejected');
  });

  test('a failure shows Hermes text and reads the list again', () async {
    bound();
    await controller.whenIdle;
    transport.script['/memory approve aa000001'] = 'Approved 0 memory write(s).\nFailed:\n  aa000001: Entry changed since it was staged.';
    await controller.decide(
      controller.snapshot!.proposals.first,
      approve: true,
    );
    expect(controller.notice?.title, 'Entry changed since it was staged.');
    expect(controller.notice?.isError, isTrue);
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test(
    'Approve all decides the listed ids one by one, then reads again',
    () async {
      bound();
      await controller.whenIdle;
      transport.script['/memory approve aa000001'] =
          'Approved 1 memory write(s).';
      transport.script['/memory approve aa000002'] =
          'Approved 1 memory write(s).';
      transport.script['/memory pending'] = noPendingMemory;
      await controller.decideAll(approve: true);
      expect(transport.slashRuns.where((c) => c.contains('approve')), [
        '/memory approve aa000001',
        '/memory approve aa000002',
      ]);
      expect(controller.notice?.title, 'Saved 2 changes');
      expect(controller.waiting, 0);
      expect(controller.deciding, isFalse);
    },
  );

  test('Reject all says how many and a refusal is shown', () async {
    bound();
    await controller.whenIdle;
    transport.script['/memory reject aa000001'] =
        "Rejected pending memory write 'aa000001'.";
    transport.script['/memory reject aa000002'] =
        "No pending memory write with id 'aa000002'.";
    await controller.decideAll(approve: false);
    expect(controller.notice?.isError, isTrue);
    expect(
      controller.notice?.title,
      "No pending memory write with id 'aa000002'.",
    );
  });

  test(
    'a lost connection stops Approve all and reads the list again',
    () async {
      bound();
      await controller.whenIdle;
      transport.script['/memory approve aa000001'] = StateError('socket');
      await controller.decideAll(approve: true);
      expect(transport.slashRuns.where((c) => c.contains('approve')), [
        '/memory approve aa000001',
      ]);
      expect(controller.notice?.isError, isTrue);
      expect(controller.notice?.title, "Couldn't reach Hermes. Try again.");
    },
  );

  test(
    'a skill proposal is approved with /skills and shown as Skill saved',
    () async {
      transport.script['/skills pending'] = skillsPending;
      bound();
      await controller.whenIdle;
      final skill = controller.snapshot!.skills.proposals.first;
      transport.script['/skills approve cc000001'] =
          '⏳ Processing skills command...\nApproved 1 skills write(s).';
      await controller.decide(skill, approve: true);
      expect(controller.notice?.title, 'Skill saved');
    },
  );

  test('a late answer of another profile is dropped', () async {
    final slow = Completer<String>();
    transport.script['/memory pending'] = slow;
    bound('work');
    await pumpEventQueue();
    transport.script['/memory pending'] = noPendingMemory;
    bound('home');
    await pumpEventQueue();
    slow.complete(twoMemory);
    await pumpEventQueue();
    expect(controller.waiting, 0);
    expect(controller.snapshot!.proposals, isEmpty);
  });

  test(
    'a decision that finishes after a profile change shows nothing',
    () async {
      bound('work');
      await controller.whenIdle;
      final gate = Completer<String>();
      transport.script['/memory approve aa000001'] = gate;
      final deciding = controller.decide(
        controller.snapshot!.proposals.first,
        approve: true,
      );
      await pumpEventQueue();
      transport.script['/memory pending'] = noPendingMemory;
      bound('home');
      await pumpEventQueue();
      gate.complete('Approved 1 memory write(s).');
      await deciding;
      expect(controller.notice, isNull);
      expect(controller.waiting, 0);
    },
  );

  test('unbinding clears every text', () async {
    transport.script['/skills pending'] = skillsPending;
    transport.script['/skills diff cc000001'] = skillDiffCreate;
    bound();
    await controller.whenIdle;
    await controller.showChanges(controller.snapshot!.skills.proposals.first);
    expect(controller.diffOf('cc000001')?.text, isNotNull);
    controller.bind(null, null);
    expect(controller.snapshot, isNull);
    expect(controller.selected, isNull);
    expect(controller.notice, isNull);
    expect(controller.diffOf('cc000001'), isNull);
    expect(controller.waiting, isNull);
  });

  test('Show changes loads the diff of a skill once', () async {
    transport.script['/skills pending'] = skillsPending;
    transport.script['/skills diff cc000001'] = skillDiffCreate;
    bound();
    await controller.whenIdle;
    final skill = controller.snapshot!.skills.proposals.first;
    await controller.showChanges(skill);
    expect(
      controller.diffOf('cc000001')?.text,
      startsWith('---\nname: contract-check'),
    );
    await controller.showChanges(skill);
    expect(
      transport.slashRuns.where((c) => c.startsWith('/skills diff')),
      hasLength(1),
    );
  });

  test('a diff that fails can be asked for again', () async {
    transport.script['/skills pending'] = skillsPending;
    transport.script['/skills diff cc000001'] = StateError('socket');
    bound();
    await controller.whenIdle;
    final skill = controller.snapshot!.skills.proposals.first;
    await controller.showChanges(skill);
    expect(controller.diffOf('cc000001')?.failed, isTrue);
    transport.script['/skills diff cc000001'] = skillDiffCreate;
    await controller.showChanges(skill);
    expect(controller.diffOf('cc000001')?.text, isNotNull);
  });

  test('reading again keeps the list on screen while it reads, and a failed read shows as failed', () async {
    bound();
    await controller.whenIdle;
    transport.script['/memory pending'] = StateError('socket');
    transport.script['/skills pending'] = StateError('socket');
    final reading = controller.load();
    expect(controller.snapshot, isNotNull);
    await reading;
    expect(controller.snapshot!.memory.status, ProposalReadStatus.failed);
  });

  test('states of a decision are those of MemoryDecisions', () async {
    bound();
    await controller.whenIdle;
    expect(
      controller.decisions?.stateOf('aa000001').phase,
      MemoryDecisionPhase.idle,
    );
  });
}
