import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';

import 'memory_proposal_fixtures.dart';

void main() {
  group('parseMemoryPending', () {
    MemoryProposal only(String answer) {
      final parsed = parseMemoryPending(answer);
      expect(parsed.proposals, hasLength(1));
      return parsed.proposals.single;
    }

    test('an empty answer lists nothing and is not unreadable', () {
      for (final answer in [noPendingMemory, 'No pending anything.', '']) {
        final parsed = parseMemoryPending(answer);
        expect(parsed.proposals, isEmpty, reason: answer);
        expect(parsed.unreadable, isFalse, reason: answer);
      }
    });

    test('a chat add cut at 120 characters may be shortened', () {
      final proposal = only(chatAddCut);
      expect(proposal.id, 'aa000001');
      expect(proposal.action, ProposalAction.add);
      expect(proposal.target, MemoryTab.aboutYou);
      expect(proposal.background, isFalse);
      expect(proposal.newText, 'x' * 120);
      expect(proposal.mayBeShortened, isTrue);
      expect(proposal.replaced, isEmpty);
    });

    test('a short chat add is whole', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals.first;
      expect(proposal.action, ProposalAction.add);
      expect(proposal.targetLabel, 'About you');
      expect(proposal.newText, 'Runs on a Mac');
      expect(proposal.mayBeShortened, isFalse);
    });

    test('a chat replace spans two lines and shows the pinned entry', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals[1];
      expect(proposal.action, ProposalAction.replace);
      expect(proposal.target, MemoryTab.agentNotes);
      expect(proposal.background, isFalse);
      expect(proposal.replaced, ['Prefers tabs in Go']);
      expect(proposal.newText, 'Prefers spaces');
      expect(proposal.mayBeShortened, isFalse);
    });

    test('a background patch reads as a replace of the whole entry', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals[2];
      expect(proposal.id, 'aa000003');
      expect(proposal.background, isTrue);
      expect(proposal.action, ProposalAction.replace);
      expect(proposal.target, MemoryTab.agentNotes);
      expect(proposal.replaced, ['Prefers tabs in Go']);
      expect(proposal.newText, 'spaces');
    });

    test('a background remove has no new text', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals[3];
      expect(proposal.background, isTrue);
      expect(proposal.action, ProposalAction.remove);
      expect(proposal.target, MemoryTab.aboutYou);
      expect(proposal.replaced, ['Likes tea, no sugar']);
      expect(proposal.newText, isNull);
    });

    test('a batch keeps its raw summary under a Change badge', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals[4];
      expect(proposal.action, ProposalAction.change);
      expect(proposal.target, MemoryTab.aboutYou);
      expect(proposal.summary, contains("- patch span 'b' -> 'c'"));
      expect(proposal.replaced, ['b entry']);
    });

    test('a replace with no pinned entry carries Hermes warning', () {
      final proposal = parseMemoryPending(mixedMemoryPending).proposals[5];
      expect(proposal.id, 'aa000006');
      expect(proposal.replaced, isEmpty);
      expect(proposal.warning, contains('unpinned legacy target'));
      expect(proposal.newText, 'new');
    });

    test('a chat patch reads the new span', () {
      final proposal = only(chatPatchPending);
      expect(proposal.action, ProposalAction.replace);
      expect(proposal.target, MemoryTab.aboutYou);
      expect(proposal.replaced, ['Lives in Berlin']);
      expect(proposal.newText, 'Hamburg');
    });

    test('a background summary cut at 200 characters may be shortened', () {
      final proposal = only(backgroundReplaceCut);
      expect(proposal.action, ProposalAction.replace);
      expect(proposal.background, isTrue);
      expect(proposal.mayBeShortened, isTrue);
      expect(proposal.newText, startsWith('y'));
    });

    test('new text ending in an ellipsis may be shortened', () {
      final proposal = only(
        'Pending memory writes (1):\n'
        '  1a2b3c4d  add to memory: Uses deploy.sh from…\n',
      );
      expect(proposal.newText, 'Uses deploy.sh from…');
      expect(proposal.mayBeShortened, isTrue);
    });

    test('the spec scenario: a background replace', () {
      final proposal = only(
        'Pending memory writes (1):\n'
        '  1a2b3c4d [auto]  background review consolidation (replace on memory): Prefers spaces\n'
        '      replaces entry: Prefers tabs in Go\n',
      );
      expect(proposal.action, ProposalAction.replace);
      expect(proposal.targetLabel, 'Agent notes');
      expect(proposal.background, isTrue);
      expect(proposal.replaced, ['Prefers tabs in Go']);
      expect(proposal.newText, 'Prefers spaces');
    });

    test('an unknown line before the first proposal is counted and kept', () {
      final parsed = parseMemoryPending(
        'Heads up: something new\n$mixedMemoryPending',
      );
      expect(parsed.proposals, hasLength(6));
      expect(parsed.unknownLines, ['Heads up: something new']);
      expect(parsed.unreadable, isFalse);
    });

    test('an unreadable action and target keep the raw summary', () {
      final proposal = only(
        'Pending memory writes (1):\n'
        '  1a2b3c4d  tidy up the notes somehow\n',
      );
      expect(proposal.id, '1a2b3c4d');
      expect(proposal.action, ProposalAction.change);
      expect(proposal.target, isNull);
      expect(proposal.targetLabel, isNull);
      expect(proposal.summary, 'tidy up the notes somehow');
      expect(proposal.newText, isNull);
    });

    test('a multi-line matched entry continues the entry', () {
      final proposal = only(
        'Pending memory writes (1):\n'
        '  1a2b3c4d [auto]  background review consolidation (remove on memory): - remove: one\n'
        '      removes entry: one\n'
        'two\n',
      );
      expect(proposal.replaced, ['one\ntwo']);
    });

    test('a text with no proposal that is not empty is unreadable', () {
      final parsed = parseMemoryPending(unknownCommand);
      expect(parsed.proposals, isEmpty);
      expect(parsed.unreadable, isTrue);
      expect(parsed.raw, unknownCommand);
      expect(parsed.unknownLines, isNotEmpty);
    });

    test('a progress line is skipped, not counted', () {
      final parsed = parseMemoryPending(
        '⏳ Processing memory command...\n$chatAddCut',
      );
      expect(parsed.proposals, hasLength(1));
      expect(parsed.unknownLines, isEmpty);
    });

    test('never throws on random or truncated input', () {
      final random = Random(7);
      const alphabet = ' \n:[]()-0123456789abcdefMPR…⏳\'"';
      for (var i = 0; i < 500; i++) {
        final text = String.fromCharCodes([
          for (var n = random.nextInt(200); n > 0; n--)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        expect(() => parseMemoryPending(text), returnsNormally);
        expect(() => parseSkillsPending(text), returnsNormally);
      }
      for (var cut = 0; cut <= mixedMemoryPending.length; cut += 3) {
        final text = mixedMemoryPending.substring(0, cut);
        expect(() => parseMemoryPending(text), returnsNormally);
      }
    });
  });

  group('parseSkillsPending', () {
    test('an empty answer behind the progress line', () {
      final parsed = parseSkillsPending(noPendingSkills);
      expect(parsed.proposals, isEmpty);
      expect(parsed.unreadable, isFalse);
    });

    test('a create and a patch', () {
      final parsed = parseSkillsPending(skillsPending);
      expect(parsed.unknownLines, isEmpty);
      final [create, patch] = parsed.proposals;
      expect(create.kind, ProposalKind.skill);
      expect(create.action, ProposalAction.skill);
      expect(create.skillName, 'contract-check');
      expect(create.targetLabel, 'contract-check');
      expect(create.background, isTrue);
      expect(create.newText, contains('Checks things'));
      expect(patch.skillName, 'git-helper');
      expect(patch.background, isFalse);
      expect(patch.id, 'cc000002');
    });

    test('a skill without a quoted name is still decidable', () {
      final parsed = parseSkillsPending(
        'Pending skills writes (1):\n  cc000003  something odd\n',
      );
      expect(parsed.proposals.single.id, 'cc000003');
      expect(parsed.proposals.single.skillName, isNull);
    });
  });
}
