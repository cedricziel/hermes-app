import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_bodies.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/memory_proposals_controller.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposal_detail.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposals_list.dart';
import 'package:hermes_app/src/memory/widgets/memory_waiting_card.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _replace = MemoryProposal(
  id: 'aa000002',
  kind: ProposalKind.memory,
  action: ProposalAction.replace,
  background: true,
  summary: 'x',
  target: MemoryTab.agentNotes,
  replaced: ['Prefers tabs in Go'],
  newText: 'Prefers spaces',
);

const _add = MemoryProposal(
  id: 'aa000001',
  kind: ProposalKind.memory,
  action: ProposalAction.add,
  background: false,
  summary: 'x',
  target: MemoryTab.aboutYou,
  newText: 'Runs on a Mac',
);

const _skill = MemoryProposal(
  id: 'cc000001',
  kind: ProposalKind.skill,
  action: ProposalAction.skill,
  background: true,
  summary: "create 'git-helper' — Helps",
  skillName: 'git-helper',
  newText: "create 'git-helper' — Helps",
);

Widget _detail(
  MemoryProposal proposal, {
  MemoryDecisionState decision = MemoryDecisionState.idle,
  ProposalDiff? diff,
  VoidCallback? onApprove,
  VoidCallback? onReject,
  VoidCallback? onShowChanges,
}) => _app(
  MemoryProposalDetail(
    proposal: proposal,
    decision: decision,
    diff: diff,
    onApprove: onApprove,
    onReject: onReject,
    onShowChanges: onShowChanges,
  ),
);

Widget _list(
  ProposalsSnapshot? snapshot, {
  MemoryProposalsNotice? notice,
  bool? ask,
  void Function(MemoryProposal)? onOpen,
  VoidCallback? onRetry,
  VoidCallback? onRejectAll,
}) => MaterialApp(
  home: Scaffold(
    body: MemoryProposalsList(
      snapshot: snapshot,
      notice: notice,
      askBeforeSaving: ask,
      onAskBeforeSaving: (_) {},
      onOpen: onOpen ?? (_) {},
      onRetry: onRetry ?? () {},
      onRejectAll: onRejectAll ?? () {},
    ),
  ),
);

ProposalsSnapshot _both(
  List<MemoryProposal> memory,
  List<MemoryProposal> skills,
) => ProposalsSnapshot(
  memory: KindRead(ProposalReadStatus.ok, memory),
  skills: KindRead(ProposalReadStatus.ok, skills),
);

void main() {
  group('MemoryWaitingCard', () {
    testWidgets('says how many changes wait and that nothing is saved', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(MemoryWaitingCard(count: 2, onTap: () => taps++)),
      );
      expect(find.text('2 changes waiting for you'), findsOneWidget);
      expect(find.text('Not saved until you approve them'), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-waiting-card')));
      expect(taps, 1);
    });

    testWidgets('reads in the singular for one', (tester) async {
      await tester.pumpWidget(_app(const MemoryWaitingCard(count: 1)));
      expect(find.text('1 change waiting for you'), findsOneWidget);
    });
  });

  group('MemoryProposalDetail', () {
    testWidgets('a replace shows the old entry struck through and the new', (
      tester,
    ) async {
      await tester.pumpWidget(_detail(_replace));
      expect(find.text('Replace'), findsOneWidget);
      expect(
        find.text('Agent notes · from a background review'),
        findsOneWidget,
      );
      final old = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, '− Prefers tabs in Go'),
      );
      expect(old.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('+ Prefers spaces'), findsOneWidget);
    });

    testWidgets('a chat add says so and has no entry to strike', (
      tester,
    ) async {
      await tester.pumpWidget(_detail(_add));
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('About you · from a chat'), findsOneWidget);
      expect(find.textContaining('−'), findsNothing);
    });

    testWidgets('a target Hermes did not name leaves it out', (tester) async {
      await tester.pumpWidget(
        _detail(
          const MemoryProposal(
            id: 'aa000009',
            kind: ProposalKind.memory,
            action: ProposalAction.change,
            background: false,
            summary: 'tidy up somehow',
          ),
        ),
      );
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('from a chat'), findsOneWidget);
      expect(find.text('tidy up somehow'), findsOneWidget);
    });

    testWidgets('names a skill and offers its changes', (tester) async {
      var asked = 0;
      await tester.pumpWidget(_detail(_skill, onShowChanges: () => asked++));
      expect(find.text('Skill'), findsOneWidget);
      expect(
        find.text('git-helper · from a background review'),
        findsOneWidget,
      );
      await tester.tap(find.text('Show changes'));
      expect(asked, 1);
    });

    testWidgets('shows a skill diff once it is read', (tester) async {
      await tester.pumpWidget(
        _detail(
          _skill,
          diff: const ProposalDiff(
            text: '--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1 +1 @@\n-old\n+new\n',
          ),
        ),
      );
      expect(find.byType(ToolDiffBody), findsOneWidget);
      expect(find.text('Show changes'), findsNothing);
    });

    testWidgets('shows plain text for an answer that is not a diff', (
      tester,
    ) async {
      await tester.pumpWidget(
        _detail(_skill, diff: const ProposalDiff(text: 'name: git-helper')),
      );
      expect(find.byType(ToolDiffBody), findsNothing);
      expect(find.text('name: git-helper'), findsOneWidget);
    });

    testWidgets('a diff that failed can be asked for again', (tester) async {
      await tester.pumpWidget(
        _detail(
          _skill,
          diff: const ProposalDiff(failed: true),
          onShowChanges: () {},
        ),
      );
      expect(find.text("Couldn't load. Try again"), findsOneWidget);
    });

    testWidgets('the shortening note shows only for text that may be cut', (
      tester,
    ) async {
      await tester.pumpWidget(_detail(_add));
      expect(find.text(kProposalShortenedNote), findsNothing);
      await tester.pumpWidget(
        _detail(
          const MemoryProposal(
            id: 'aa000008',
            kind: ProposalKind.memory,
            action: ProposalAction.add,
            background: false,
            summary: 'x',
            target: MemoryTab.aboutYou,
            newText: 'Something long…',
            mayBeShortened: true,
          ),
        ),
      );
      expect(
        find.text(
          'Long new text is shortened in this list; approving applies all of it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Approve and Reject call back', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _detail(
          _add,
          onApprove: () => calls.add('approve'),
          onReject: () => calls.add('reject'),
        ),
      );
      await tester.tap(find.text('Approve'));
      await tester.tap(find.text('Reject'));
      expect(calls, ['approve', 'reject']);
    });

    testWidgets('both buttons wait while a decision runs', (tester) async {
      await tester.pumpWidget(
        _detail(
          _add,
          decision: const MemoryDecisionState(MemoryDecisionPhase.running),
          onApprove: () {},
          onReject: () {},
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('proposal-approve')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('proposal-reject')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a failure shows Hermes text and keeps the buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _detail(
          _add,
          decision: const MemoryDecisionState(
            MemoryDecisionPhase.failed,
            'Entry changed since it was staged.',
          ),
          onApprove: () {},
          onReject: () {},
        ),
      );
      expect(find.text('Entry changed since it was staged.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('proposal-approve')))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('MemoryProposalsList', () {
    testWidgets('introduces the inbox and offers Ask before saving', (
      tester,
    ) async {
      await tester.pumpWidget(_list(_both([_add], []), ask: true));
      expect(find.text(kProposalsIntro), findsOneWidget);
      expect(find.text('Ask before saving'), findsOneWidget);
      expect(
        find.text(
          'Off: Hermes saves new entries itself and only asks before a background review replaces or removes one',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('the switch is disabled while the settings are unread', (
      tester,
    ) async {
      await tester.pumpWidget(_list(_both([_add], [])));
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('a row shows its badge, target and origin and opens', (
      tester,
    ) async {
      MemoryProposal? opened;
      await tester.pumpWidget(
        _list(_both([_replace], [_skill]), onOpen: (p) => opened = p),
      );
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Skill'), findsOneWidget);
      expect(
        find.text('Agent notes · from a background review'),
        findsOneWidget,
      );
      await tester.tap(find.text('Prefers spaces'));
      expect(opened?.id, 'aa000002');
    });

    testWidgets('Reject all calls back and waits while one runs', (
      tester,
    ) async {
      var rejected = 0;
      await tester.pumpWidget(
        _list(_both([_add], []), onRejectAll: () => rejected++),
      );
      await tester.tap(find.text('Reject all'));
      expect(rejected, 1);
    });

    testWidgets('says nothing is waiting for an empty list', (tester) async {
      await tester.pumpWidget(_list(_both([], [])));
      expect(find.text('Nothing is waiting'), findsOneWidget);
      expect(find.text('Reject all'), findsNothing);
    });

    testWidgets('shows a saved banner and a failure banner', (tester) async {
      await tester.pumpWidget(
        _list(
          _both([_add], []),
          notice: const MemoryProposalsNotice(
            'Saved to About you',
            detail: 'Hermes uses it from the next chat.',
          ),
        ),
      );
      expect(find.text('Saved to About you'), findsOneWidget);
      expect(find.text('Hermes uses it from the next chat.'), findsOneWidget);
      await tester.pumpWidget(
        _list(
          _both([_add], []),
          notice: const MemoryProposalsNotice('Entry changed.', isError: true),
        ),
      );
      expect(find.text('Entry changed.'), findsOneWidget);
    });

    testWidgets('an answer nobody can read shows its text and retries', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.unreadable, [], 'Odd text.'),
            skills: KindRead(ProposalReadStatus.ok),
          ),
          onRetry: () => retries++,
        ),
      );
      expect(
        find.text("Hermes answered in a way the app doesn't understand"),
        findsOneWidget,
      );
      expect(find.text('Odd text.'), findsOneWidget);
      expect(find.text('Nothing is waiting'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('a kind that could not be read does not hide the other', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list(
          ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.ok, [_add]),
            skills: const KindRead(ProposalReadStatus.failed),
          ),
        ),
      );
      expect(find.text("Couldn't read Skill changes"), findsOneWidget);
      expect(find.text('Runs on a Mac'), findsOneWidget);
    });

    testWidgets('an older server says it cannot read changes', (tester) async {
      await tester.pumpWidget(
        _list(
          const ProposalsSnapshot(
            memory: KindRead(ProposalReadStatus.unsupported),
            skills: KindRead(ProposalReadStatus.unsupported),
          ),
        ),
      );
      expect(find.text("Can't read changes on this server"), findsOneWidget);
      expect(find.text('Nothing is waiting'), findsNothing);
    });

    testWidgets('shows progress before the first read ends', (tester) async {
      await tester.pumpWidget(_list(null));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
