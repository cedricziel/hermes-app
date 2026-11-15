import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';

/// An iPhone SE at the largest accessibility text: nothing may overflow.
void main() {
  Future<void> pumpSmall(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
        home: home,
      ),
    );
    await tester.pump();
  }

  testWidgets('the skill job sheet scrolls in a 9/16 sheet', (tester) async {
    final job = SkillJob(
      title: 'Installing a skill with a rather long name',
      start: () async => const StartedJob(name: 'j', pid: 1),
      status: (_) async => JobStatus(
        running: false,
        exitCode: 0,
        pid: 1,
        lines: [
          for (var i = 1; i <= 9; i++)
            'Step $i of 9: copying files into the skill directory',
        ],
      ),
      wait: (_) async {},
    );
    addTearDown(job.dispose);
    await tester.runAsync(job.run);
    await pumpSmall(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 568 * 9 / 16,
            child: SkillJobSheet(job: job),
          ),
        ),
      ),
    );
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a kanban card keeps a long assignee inside its width', (
    tester,
  ) async {
    await pumpSmall(
      tester,
      const Scaffold(
        body: SizedBox(
          width: 200,
          child: KanbanCard(
            task: KanbanTask(
              id: 't1',
              title: 'Rotate keys',
              status: 'todo',
              assignee: 'a-very-long-assignee-profile-name-indeed',
              commentCount: 12,
              progressDone: 3,
              progressTotal: 8,
              warningCount: 2,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the iOS tab bar fits an app bar at large text', (tester) async {
    await pumpSmall(
      tester,
      DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Plugins'),
            bottom: const AdaptiveTabBar(
              labels: ['Installed', 'Catalog', 'Providers'],
            ),
          ),
          body: const TabBarView(children: [Text('1'), Text('2'), Text('3')]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
