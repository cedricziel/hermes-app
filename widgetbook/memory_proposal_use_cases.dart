import 'package:flutter/material.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/memory_proposals_controller.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposal_detail.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposals_list.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposals_split.dart';
import 'package:hermes_app/src/memory/widgets/memory_waiting_card.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode memoryProposalsNode() => WidgetbookComponent(
  name: 'Memory proposals',
  useCases: [
    for (final (state, count) in [('one', 1), ('three', 3)])
      ...onEachPlatform(
        'Waiting card, $state',
        (_) => Scaffold(
          body: GroupedListView(
            children: [MemoryWaitingCard(count: count, onTap: () {})],
          ),
        ),
      ),
    for (final (state, proposal, decision, diff) in [
      ('Add', _add, MemoryDecisionState.idle, null),
      ('Replace', _replace, MemoryDecisionState.idle, null),
      ('Remove', _remove, MemoryDecisionState.idle, null),
      ('Replace, shortened', _shortened, MemoryDecisionState.idle, null),
      ('Batch', _batch, MemoryDecisionState.idle, null),
      ('Unpinned', _unpinned, MemoryDecisionState.idle, null),
      ('Skill', _skill, MemoryDecisionState.idle, null),
      (
        'Skill, loading changes',
        _skill,
        MemoryDecisionState.idle,
        const ProposalDiff(loading: true),
      ),
      (
        'Skill, changes shown',
        _skillPatch,
        MemoryDecisionState.idle,
        const ProposalDiff(text: _patchDiff),
      ),
      (
        'Skill, new skill shown',
        _skill,
        MemoryDecisionState.idle,
        const ProposalDiff(text: _createBody),
      ),
      (
        'Skill, changes failed',
        _skill,
        MemoryDecisionState.idle,
        const ProposalDiff(failed: true),
      ),
      (
        'Deciding',
        _replace,
        const MemoryDecisionState(MemoryDecisionPhase.running),
        null,
      ),
      (
        'Failed',
        _replace,
        const MemoryDecisionState(
          MemoryDecisionPhase.failed,
          'Entry changed since it was staged, so this write was not applied: '
          "'Prefers tabs in Go' is no longer in memory as reviewed.",
        ),
        null,
      ),
    ])
      ...onEachPlatform(
        'Detail, $state',
        (_) => Scaffold(
          body: frame(
            MemoryProposalDetail(
              proposal: proposal,
              decision: decision,
              diff: diff,
              onApprove: () {},
              onReject: () {},
              onShowChanges: () {},
            ),
          ),
        ),
      ),
    for (final (state, snapshot, notice, selected, ask) in [
      ('List', _snapshot(), null, null, false),
      ('List, selected', _snapshot(), null, 'aa000002', true),
      ('List, loading', null, null, null, false),
      (
        'List, nothing waiting',
        _snapshot(memory: const [], skills: const []),
        null,
        null,
        false,
      ),
      (
        'List, saved',
        _snapshot(),
        const MemoryProposalsNotice(
          'Saved to About you',
          detail: 'Hermes uses it from the next chat.',
        ),
        null,
        false,
      ),
      (
        'List, failed decision',
        _snapshot(),
        const MemoryProposalsNotice(
          "Entry changed since it was staged. Hermes read the list again.",
          isError: true,
        ),
        null,
        false,
      ),
      (
        'List, skills unreadable',
        ProposalsSnapshot(
          memory: KindRead(ProposalReadStatus.ok, [_add]),
          skills: const KindRead(ProposalReadStatus.failed),
        ),
        null,
        null,
        false,
      ),
      (
        'List, answer not understood',
        const ProposalsSnapshot(
          memory: KindRead(
            ProposalReadStatus.unreadable,
            [],
            'Memory is not available right now.',
          ),
          skills: KindRead(ProposalReadStatus.ok),
        ),
        null,
        null,
        false,
      ),
      (
        'List, unsupported server',
        const ProposalsSnapshot(
          memory: KindRead(ProposalReadStatus.unsupported),
          skills: KindRead(ProposalReadStatus.unsupported),
        ),
        null,
        null,
        false,
      ),
    ])
      ...onEachPlatform(
        state,
        (_) => Scaffold(
          body: MemoryProposalsList(
            snapshot: snapshot,
            selectedId: selected,
            notice: notice,
            askBeforeSaving: ask,
            onAskBeforeSaving: (_) {},
            onOpen: (_) {},
            onRetry: () {},
            onRejectAll: () {},
          ),
        ),
      ),
    ...onEachPlatform(
      'List, settings not read',
      (_) => Scaffold(
        body: MemoryProposalsList(
          snapshot: _snapshot(),
          onOpen: (_) {},
          onRetry: () {},
          onRejectAll: () {},
        ),
      ),
    ),
    ...onEachPlatform(
      'List, deciding all',
      (_) => Scaffold(
        body: MemoryProposalsList(
          snapshot: _snapshot(),
          deciding: true,
          askBeforeSaving: true,
          onAskBeforeSaving: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRejectAll: () {},
        ),
      ),
    ),
    ...onEachPlatform(
      'Side by side',
      (_) => Scaffold(
        body: MemoryProposalsSplit(
          detailKey: _replace.id,
          list: MemoryProposalsList(
            snapshot: _snapshot(),
            selectedId: _replace.id,
            askBeforeSaving: true,
            onAskBeforeSaving: (_) {},
            onOpen: (_) {},
            onRetry: () {},
            onRejectAll: () {},
          ),
          detail: MemoryProposalDetail(
            proposal: _replace,
            onApprove: () {},
            onReject: () {},
          ),
        ),
      ),
    ),
  ],
);

ProposalsSnapshot _snapshot({
  List<MemoryProposal>? memory,
  List<MemoryProposal>? skills,
}) => ProposalsSnapshot(
  memory: KindRead(
    ProposalReadStatus.ok,
    memory ?? [_add, _replace, _remove, _shortened, _batch],
  ),
  skills: KindRead(ProposalReadStatus.ok, skills ?? [_skill, _skillPatch]),
);

const _add = MemoryProposal(
  id: 'aa000001',
  kind: ProposalKind.memory,
  action: ProposalAction.add,
  background: false,
  summary: 'add to user profile: Runs on a Mac',
  target: MemoryTab.aboutYou,
  newText: 'Runs on a Mac',
);

const _replace = MemoryProposal(
  id: 'aa000002',
  kind: ProposalKind.memory,
  action: ProposalAction.replace,
  background: true,
  summary: 'background review consolidation (replace on memory): - replace: Prefers spaces',
  target: MemoryTab.agentNotes,
  replaced: ['Prefers tabs in Go'],
  newText: 'Prefers spaces',
);

const _remove = MemoryProposal(
  id: 'aa000003',
  kind: ProposalKind.memory,
  action: ProposalAction.remove,
  background: true,
  summary:
      'background review consolidation (remove on user): - remove: Likes tea',
  target: MemoryTab.aboutYou,
  replaced: ['Likes tea, no sugar'],
);

const _shortened = MemoryProposal(
  id: 'aa000004',
  kind: ProposalKind.memory,
  action: ProposalAction.add,
  background: false,
  summary: 'add to memory: long',
  target: MemoryTab.agentNotes,
  newText: 'The hive server deploys with deploy.sh from ~/ops; it needs SSH agent forwarding, a recent Node, and the staging key loaded before the script is run or the push',
  mayBeShortened: true,
);

const _batch = MemoryProposal(
  id: 'aa000005',
  kind: ProposalKind.memory,
  action: ProposalAction.change,
  background: false,
  summary: "apply 2 op(s) to user profile: - add: A\n- patch span 'b' -> 'c' (rest of the entry is kept)",
  target: MemoryTab.aboutYou,
  replaced: ['b entry'],
);

const _unpinned = MemoryProposal(
  id: 'aa000006',
  kind: ProposalKind.memory,
  action: ProposalAction.replace,
  background: false,
  summary: 'replace in memory: entry matching: old\nwhole entry becomes: new',
  target: MemoryTab.agentNotes,
  newText: 'new',
  warning:
      'replace: unpinned legacy target — reject and recreate before approving',
);

const _skill = MemoryProposal(
  id: 'cc000001',
  kind: ProposalKind.skill,
  action: ProposalAction.skill,
  background: true,
  summary: "create 'git-helper' — Helps with git (60 chars)",
  skillName: 'git-helper',
  newText: "create 'git-helper' — Helps with git (60 chars)",
);

const _skillPatch = MemoryProposal(
  id: 'cc000002',
  kind: ProposalKind.skill,
  action: ProposalAction.skill,
  background: false,
  summary: "patch 'deploy' SKILL.md (+2/-1 lines)",
  skillName: 'deploy',
  newText: "patch 'deploy' SKILL.md (+2/-1 lines)",
);

const _patchDiff =
    '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,3 +1,4 @@\n name: deploy\n-Run deploy.sh\n+Run ship.sh\n+Then check the logs\n';

const _createBody =
    '---\nname: git-helper\ndescription: Helps with git\n---\nUse git status first.\n';
