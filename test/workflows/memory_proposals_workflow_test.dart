import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals_controller.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_proposals_screen.dart';
import 'package:hermes_app/src/memory/memory_settings_controller.dart';
import 'package:hermes_app/src/memory/memory_settings_repository.dart';

import '../memory/memory_fixtures.dart';
import '../memory/memory_proposal_fixtures.dart';
import '../memory/memory_proposal_support.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

final _pending =
    'Pending memory writes (4):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002 [auto]  background review consolidation (patch on memory): - patch span \'tabs\' -> \'spaces\' (rest of the entry is kept)\n'
    '      patchs entry: Prefers tabs in Go\n'
    '  aa000003 [auto]  background review consolidation (remove on user): - remove: Likes tea\n'
    '      removes entry: Likes tea, no sugar\n'
    '  aa000004  add to memory: ${'The hive server deploys with deploy.sh from ~/ops. ' * 3}\n';

/// Waiting for you: the memory and skill changes Hermes holds for approval,
/// their detail beside the list from 900 logical pixels, and a decision.
void main() {
  late ScriptedSlashTransport transport;
  late MemoryProposalsController proposals;
  late MemorySettingsController settings;

  setUp(() {
    transport = ScriptedSlashTransport()
      ..script['/memory pending'] = _pending
      ..script['/skills pending'] = skillsPending
      ..script['/skills diff cc000002'] = '# Pending skill write cc000002: patch\n\n--- a/SKILL.md\n+++ b/SKILL.md\n@@ -1,2 +1,2 @@\n name: git-helper\n-Run git status\n+Run git status -sb\n';
    final server = FakeHermesServer()
      ..on('GET', '/api/config', memorySettingsConfig(writeApproval: true))
      ..on('PUT', '/api/config', {'ok': true});
    proposals = MemoryProposalsController();
    settings = MemorySettingsController();
    addTearDown(proposals.dispose);
    addTearDown(settings.dispose);
    settings.bind(MemorySettingsRepository(server.client().raw), 'work');
    proposals.bind(
      MemoryProposalsRepository(MemoryProposalSession(transport)),
      'work',
    );
  });

  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('desktop-dark', desktopSize, Brightness.dark),
  ]) {
    testWidgets('$name: the inbox, a detail and a decision', (tester) async {
      final shots = ScreenshotRecorder('memory-proposals-$name');
      await pumpScreen(
        tester,
        shots,
        MemoryProposalsScreen(controller: proposals, settings: settings),
        size: size,
        brightness: brightness,
      );
      await tester.runAsync(() async {
        await proposals.whenIdle;
        await settings.whenIdle;
      });
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list');

      await tester.tap(find.byKey(const ValueKey('proposal-aa000002')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'replace-detail');

      transport.script['/memory approve aa000002'] = approvedPatch.replaceAll(
        'bb000003',
        'aa000002',
      );
      transport.script['/memory pending'] = _pending
          .replaceFirst(
            'Pending memory writes (4)',
            'Pending memory writes (3)',
          )
          .replaceFirst(RegExp(r"  aa000002 .*\n      patchs entry: .*\n"), '');
      await tester.tap(find.byKey(const Key('proposal-approve')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'saved');
      expect(find.text('Saved to Agent notes'), findsOneWidget);
    });
  }
}
