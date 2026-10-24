import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals_controller.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_proposals_screen.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/memory_settings_controller.dart';
import 'package:hermes_app/src/memory/memory_settings_repository.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposal_detail.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposals_list.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';
import 'memory_proposal_support.dart';

const _two =
    'Pending memory writes (2):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002 [auto]  background review consolidation (remove on memory): - remove: tabs\n'
    '      removes entry: Prefers tabs in Go\n';

const _approved = 'Approved 1 memory write(s).';

void main() {
  late ScriptedSlashTransport transport;
  late FakeHermesServer server;
  late MemoryProposalsController proposals;
  late MemorySettingsController settings;
  late MemoryController memory;
  late BreadcrumbTrail trail;

  setUp(() {
    transport = ScriptedSlashTransport()
      ..script['/memory pending'] = _two
      ..script['/skills pending'] =
          '⏳ Processing skills command...\nNo pending skills writes.';
    server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/config', memorySettingsConfig(writeApproval: true))
      ..on('PUT', '/api/config', {'ok': true});
    trail = BreadcrumbTrail();
    proposals = MemoryProposalsController(breadcrumbs: Breadcrumbs.of(trail));
    settings = MemorySettingsController();
    memory = MemoryController();
    addTearDown(proposals.dispose);
    addTearDown(settings.dispose);
    addTearDown(memory.dispose);
  });

  Future<void> bind(WidgetTester tester) async {
    await tester.runAsync(() async {
      memory.bind(MemoryRepository(server.client().raw), 'work');
      settings.bind(MemorySettingsRepository(server.client().raw), 'work');
      proposals.bind(
        MemoryProposalsRepository(MemoryProposalSession(transport)),
        'work',
      );
      await pumpEventQueue();
      await settings.whenIdle;
      await proposals.whenIdle;
    });
  }

  Future<void> pumpMemory(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    Size size = const Size(400, 900),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await bind(tester);
    await tester.pumpWidget(
      Provider<Breadcrumbs>.value(
        value: Breadcrumbs.of(trail),
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: MemoryScreen(
            controller: memory,
            settings: settings,
            proposals: proposals,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openInbox(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('memory-waiting-card')));
    await tester.pumpAndSettle();
  }

  group('the waiting card', () {
    testWidgets('shows the count and opens the inbox', (tester) async {
      await pumpMemory(tester);
      expect(find.text('2 changes waiting for you'), findsOneWidget);
      expect(find.text('Not saved until you approve them'), findsOneWidget);
      await openInbox(tester);
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.text(kProposalsIntro), findsOneWidget);
    });

    testWidgets('is hidden when nothing waits', (tester) async {
      transport.script['/memory pending'] = 'No pending memory writes.';
      await pumpMemory(tester);
      expect(find.byKey(const Key('memory-waiting-card')), findsNothing);
    });

    testWidgets('is hidden while the changes could not be read', (
      tester,
    ) async {
      transport.script['/memory pending'] = StateError('socket');
      transport.script['/skills pending'] = StateError('socket');
      await pumpMemory(tester);
      expect(find.byKey(const Key('memory-waiting-card')), findsNothing);
      expect(find.text('User preference'), findsOneWidget);
    });

    testWidgets('is left out without an inbox', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await bind(tester);
      await tester.pumpWidget(
        MaterialApp(home: MemoryScreen(controller: memory)),
      );
      expect(find.byKey(const Key('memory-waiting-card')), findsNothing);
    });

    testWidgets('opening the inbox leaves a crumb with the count only', (
      tester,
    ) async {
      await pumpMemory(tester);
      await openInbox(tester);
      final crumb = trail.recent.singleWhere(
        (crumb) => crumb.name == 'memory.inbox.opened',
      );
      expect(crumb.attributes, {'count': 2});
    });
  });

  group('the layout', () {
    testWidgets('a phone opens a proposal as a page', (tester) async {
      await pumpMemory(tester);
      await openInbox(tester);
      expect(find.byType(MemoryProposalDetail), findsNothing);
      await tester.tap(find.text('Runs on a Mac'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryProposalPage), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('a wide window shows the first proposal beside the list', (
      tester,
    ) async {
      await pumpMemory(tester, size: const Size(1000, 800));
      await openInbox(tester);
      expect(find.byType(MemoryProposalDetail), findsOneWidget);
      expect(
        tester
            .widget<MemoryProposalDetail>(find.byType(MemoryProposalDetail))
            .proposal
            .id,
        'aa000001',
      );
      await tester.tap(find.text('Prefers tabs in Go'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MemoryProposalDetail>(find.byType(MemoryProposalDetail))
            .proposal
            .id,
        'aa000002',
      );
      expect(find.byType(MemoryProposalPage), findsNothing);
    });

    testWidgets('a full-screen iPad is wide from 700 points', (tester) async {
      await pumpMemory(
        tester,
        platform: TargetPlatform.iOS,
        size: const Size(744, 1024),
      );
      await openInbox(tester);
      expect(find.byType(MemoryProposalDetail), findsOneWidget);
    });

    testWidgets('an iPhone is not', (tester) async {
      await pumpMemory(
        tester,
        platform: TargetPlatform.iOS,
        size: const Size(430, 932),
      );
      await openInbox(tester);
      expect(find.byType(MemoryProposalDetail), findsNothing);
    });
  });

  group('deciding', () {
    testWidgets('Approve saves, says where and reads the list again', (
      tester,
    ) async {
      transport.script['/memory approve aa000001'] = _approved;
      await pumpMemory(tester, size: const Size(1000, 800));
      await openInbox(tester);
      final reads = transport.slashRuns
          .where((c) => c == '/memory pending')
          .length;
      transport.script['/memory pending'] =
          'Pending memory writes (1):\n'
          '  aa000002 [auto]  background review consolidation (remove on memory): - remove: tabs\n'
          '      removes entry: Prefers tabs in Go\n';
      await tester.tap(find.byKey(const Key('proposal-approve')));
      await tester.pumpAndSettle();
      expect(transport.slashRuns, contains('/memory approve aa000001'));
      expect(
        transport.slashRuns.where((c) => c == '/memory pending').length,
        greaterThan(reads),
      );
      expect(find.text('Saved to About you'), findsOneWidget);
      expect(find.text('Hermes uses it from the next chat.'), findsOneWidget);
      expect(find.text('Runs on a Mac'), findsNothing);
      expect(trail.recent.map((c) => c.name), contains('memory.inbox.decide'));
      final decide = trail.recent.firstWhere(
        (c) => c.name == 'memory.inbox.decide',
      );
      expect(decide.attributes, {'choice': 'approve'});
    });

    testWidgets('a pinned entry that changed shows Hermes text', (
      tester,
    ) async {
      transport.script['/memory approve aa000001'] = 'Approved 0 memory write(s).\nFailed:\n  aa000001: Entry changed since it was staged.';
      await pumpMemory(tester, size: const Size(1000, 800));
      await openInbox(tester);
      final reads = transport.slashRuns
          .where((c) => c == '/memory pending')
          .length;
      await tester.tap(find.byKey(const Key('proposal-approve')));
      await tester.pumpAndSettle();
      expect(find.text('Entry changed since it was staged.'), findsWidgets);
      expect(
        transport.slashRuns.where((c) => c == '/memory pending').length,
        reads + 1,
      );
    });

    testWidgets('a rejection on the phone page closes it', (tester) async {
      transport.script['/memory reject aa000001'] =
          "Rejected pending memory write 'aa000001'.";
      await pumpMemory(tester);
      await openInbox(tester);
      await tester.tap(find.text('Runs on a Mac'));
      await tester.pumpAndSettle();
      transport.script['/memory pending'] =
          'Pending memory writes (1):\n'
          '  aa000002  add to memory: Other\n';
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryProposalPage), findsNothing);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('Approve all in the bar decides each listed id', (
      tester,
    ) async {
      transport.script['/memory approve aa000001'] = _approved;
      transport.script['/memory approve aa000002'] = _approved;
      await pumpMemory(tester);
      await openInbox(tester);
      transport.script['/memory pending'] = 'No pending memory writes.';
      await tester.tap(find.byKey(const Key('proposals-approve-all')));
      await tester.pumpAndSettle();
      expect(transport.slashRuns.where((c) => c.contains('approve')), [
        '/memory approve aa000001',
        '/memory approve aa000002',
      ]);
      expect(find.text('Saved 2 changes'), findsOneWidget);
      expect(find.text('Nothing is waiting'), findsOneWidget);
    });

    testWidgets('Reject all asks first', (tester) async {
      transport.script['/memory reject aa000001'] =
          "Rejected pending memory write 'aa000001'.";
      transport.script['/memory reject aa000002'] =
          "Rejected pending memory write 'aa000002'.";
      await pumpMemory(tester);
      await openInbox(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('proposals-reject-all')),
        200,
      );
      await tester.tap(find.byKey(const Key('proposals-reject-all')));
      await tester.pumpAndSettle();
      expect(find.text('Reject all changes?'), findsOneWidget);
      expect(transport.slashRuns.where((c) => c.contains('reject')), isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(transport.slashRuns.where((c) => c.contains('reject')), isEmpty);

      await tester.tap(find.byKey(const Key('proposals-reject-all')));
      await tester.pumpAndSettle();
      transport.script['/memory pending'] = 'No pending memory writes.';
      await tester.tap(find.text('Reject all').last);
      await tester.pumpAndSettle();
      expect(transport.slashRuns.where((c) => c.contains('reject')), [
        '/memory reject aa000001',
        '/memory reject aa000002',
      ]);
      final crumbs = trail.recent.where((c) => c.name == 'memory.inbox.decide');
      expect(crumbs.single.attributes, {'choice': 'reject_all'});
    });
  });

  group('Ask before saving', () {
    testWidgets('writes memory.write_approval and shows the new value', (
      tester,
    ) async {
      await pumpMemory(tester);
      await openInbox(tester);
      final row = find.byKey(const Key('proposals-ask-before-saving'));
      await tester.scrollUntilVisible(row, 200);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row, matching: find.byType(Switch)),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(settings.settings!.writeApproval, isFalse);
      final put = server.requestsTo('PUT', '/api/config').single;
      expect(put.queryParameters['profile'], 'work');
      expect(put.data.toString(), contains('write_approval'));
    });

    testWidgets('goes back when the server does not take it', (tester) async {
      server.on('PUT', '/api/config', {'detail': 'no'}, status: 500);
      await pumpMemory(tester);
      await openInbox(tester);
      final row = find.byKey(const Key('proposals-ask-before-saving'));
      await tester.scrollUntilVisible(row, 200);
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(settings.settings!.writeApproval, isTrue);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row, matching: find.byType(Switch)),
            )
            .value,
        isTrue,
      );
    });
  });
}
