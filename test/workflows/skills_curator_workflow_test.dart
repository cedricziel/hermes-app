import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/curator/curator_config.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/skills/widgets/curator_run_confirmation.dart';

import '../skills/curator_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _statusPath = '/api/actions/curator-run/status';
const _newHeader = '=== curator-run started 2026-11-15 03:37:50 ===';

/// The skill curator on the Skills screen: the Installed tab with its
/// section, pausing the scheduled passes, a confirmed run followed to its
/// end (the list then reads again and the archived skill is gone), on a
/// phone and a desktop window, light and dark, and at twice the text size.
void main() {
  late FakeHermesServer server;
  late int skillReads;

  /// The log on open and just before the POST (the first pass), the new
  /// header with the pass still going, and then the finished pass.
  void logs() {
    final first = recordedStatusFinished['lines']! as List<Object?>;
    final answers = <Object?>[
      recordedStatusFinished,
      recordedStatusFinished,
      {
        ...recordedStatusRunning,
        'lines': [...first, '', _newHeader],
      },
      recordedStatusArchived,
    ];
    var i = 0;
    server.onRequest('GET', _statusPath, (_) {
      final body = answers[i < answers.length ? i : answers.length - 1];
      i++;
      return (status: 200, body: body);
    });
  }

  setUp(() {
    skillReads = 0;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/config', recordedConfigCurator);
    // The pass archives one skill, so the list after it has one fewer.
    server.onRequest('GET', '/api/skills', (_) {
      final after =
          skillReads++ > 0 &&
          server.requestsTo('POST', '/api/curator/run').isNotEmpty;
      return (
        status: 200,
        body: [
          skillRow(
            name: 'apple-notes',
            description: 'Read and write Apple Notes',
            category: 'apple',
            usage: 14,
          ),
          skillRow(
            name: 'pr-review',
            description: 'Review a pull request',
            category: 'github',
            provenance: 'agent',
          ),
          if (!after)
            skillRow(
              name: 'old-agent-notes',
              description: 'Notes the agent made once and never used again',
              category: 'github',
              provenance: 'agent',
            ),
        ],
      );
    });
    serveRecordedCurator(server, status: recordedCuratorRan);
    // The server keeps the pause the app set.
    server.onRequest(
      'GET',
      '/api/curator',
      (_) => (
        status: 200,
        body: {
          ...recordedCuratorRan,
          'paused': server.requestsTo('PUT', '/api/curator/paused').isNotEmpty,
        },
      ),
    );
    logs();
  });

  Future<void> pumpSkills(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    double? textScale,
  }) async {
    if (textScale != null) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await pumpScreen(
      tester,
      shots,
      SkillsScreen(
        repository: HermesSkillsRepository(server.client().raw),
        hubRepository: HermesSkillsHubRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        chatProfile: 'default',
        curatorRepository: HermesCuratorRepository(server.client()),
        curatorConfig: CuratorConfigReader(server.client()),
      ),
      size: size,
      brightness: brightness,
    );
  }

  Future<void> frames(WidgetTester tester, int milliseconds) async {
    for (var spent = 0; spent < milliseconds; spent += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final runNow = find.text('Run now');
  final confirmRun = find.descendant(
    of: find.byType(CuratorRunConfirmation),
    matching: find.text('Run now'),
  );

  Future<void> scrollToSection(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Pause scheduled passes'));
    await tester.ensureVisible(runNow.first);
    await tester.pumpAndSettle();
  }

  final variants = [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
    ('desktop-dark', desktopSize, Brightness.dark),
  ];

  for (final (name, size, brightness) in variants) {
    testWidgets('$name: pause, then a confirmed run to its end', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('skills-curator-$name');
      await pumpSkills(tester, shots, size: size, brightness: brightness);
      await shots.capture(tester, 'installed-with-curator');

      // Pause the scheduled passes.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'paused');

      // Run now asks first and sends nothing yet.
      await scrollToSection(tester);
      await tester.tap(runNow.first);
      await tester.pumpAndSettle();
      expect(find.text('Run the curator now?'), findsOneWidget);
      expect(server.requestsTo('POST', '/api/curator/run'), isEmpty);
      await shots.capture(tester, 'confirmation');

      // Confirm: one POST, the pass runs.
      await tester.tap(confirmRun);
      await tester.pump();
      await frames(tester, 3000);
      expect(server.requestsTo('POST', '/api/curator/run'), hasLength(1));
      await shots.capture(tester, 'running');

      // The pass ends: finished, the list has read again, output on tap.
      await frames(tester, 6000);
      await tester.pumpAndSettle();
      expect(find.text('The pass finished'), findsOneWidget);
      expect(find.text('old-agent-notes'), findsNothing);
      await shots.capture(tester, 'finished');

      await tester.ensureVisible(find.textContaining('Show output'));
      await tester.tap(find.textContaining('Show output'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'output');
    });
  }

  testWidgets('phone at 2x text: the stacked row, the confirmation, the end', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('skills-curator-phone-2x');
    await pumpSkills(tester, shots, size: phoneSize, textScale: 2.0);
    await shots.capture(tester, 'installed-with-curator');

    await scrollToSection(tester);
    await shots.capture(tester, 'run-row');
    await tester.tap(runNow.first);
    await tester.pumpAndSettle();
    await shots.capture(tester, 'confirmation');

    await tester.tap(confirmRun);
    await tester.pump();
    await frames(tester, 9000);
    await tester.pumpAndSettle();
    expect(find.text('The pass finished'), findsOneWidget);
    await shots.capture(tester, 'finished');
  });
}
