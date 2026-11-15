import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/checkpoint_list_body.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/platform_refresh.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/cron/jobs', [cronJobRow()])
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': <Object?>[],
      });
  });

  Widget app(TargetPlatform platform, Widget home) => MaterialApp(
    theme: buildHermesLightTheme().copyWith(platform: platform),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  final platforms = {
    TargetPlatform.macOS: findsNothing,
    TargetPlatform.iOS: findsOneWidget,
  };

  for (final entry in platforms.entries) {
    final platform = entry.key;
    final matcher = entry.value;

    testWidgets('PlatformRefresh on $platform', (tester) async {
      await pump(
        tester,
        app(
          platform,
          PlatformRefresh(
            onRefresh: () async {},
            child: ListView(children: const [Text('row')]),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), matcher);
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('schedules list on $platform', (tester) async {
      final controller = SchedulesController(
        repository: HermesCronRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        now: () => DateTime.utc(2026, 9, 20, 12),
      );
      addTearDown(controller.dispose);
      unawaited(controller.refresh());
      await pump(
        tester,
        app(
          platform,
          Scaffold(
            body: SchedulesList(
              controller: controller,
              onSelect: (_) {},
              macLayout: platform == TargetPlatform.macOS,
            ),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), matcher);
    });

    testWidgets('kanban workers on $platform', (tester) async {
      await pump(
        tester,
        app(
          platform,
          KanbanWorkersScreen(
            repository: KanbanRepository(server.client()),
            board: 'ops',
            onChanged: () {},
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), matcher);
    });

    testWidgets('checkpoint list on $platform', (tester) async {
      await pump(
        tester,
        app(
          platform,
          Scaffold(
            body: CheckpointListBody(
              status: CheckpointListStatus.empty,
              onRefresh: () async {},
            ),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), matcher);
    });
  }
}
