import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/checkpoint_list_body.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/platform_refresh.dart';

import 'hermes_plugin_manager_repository_test.dart'
    show catalogBody, catalogRow, hubBody, hubRow;
import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/mac_commands_builder.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/dashboard/plugins/hub', hubBody([hubRow('netbox')]))
      ..on(
        'GET',
        '/api/dashboard/plugins/catalog',
        catalogBody([catalogRow('zeta')]),
      )
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
      if (platform == TargetPlatform.iOS) {
        await tester.drag(find.text('row'), const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await tester.pumpAndSettle();
      }
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

    for (final tab in PluginsTab.values) {
      testWidgets('plugins $tab on $platform', (tester) async {
        await pump(
          tester,
          app(
            platform,
            PluginsScreen(
              repository: HermesPluginManagerRepository(server.client().raw),
              initialTab: tab,
            ),
          ),
        );
        expect(find.byType(RefreshIndicator), matcher);
        final refresh = find.byKey(const Key('plugins-refresh'));
        expect(
          refresh,
          platform == TargetPlatform.macOS ? findsOneWidget : findsNothing,
        );
      });
    }

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

    testWidgets('loaded checkpoint list on $platform', (tester) async {
      await pump(
        tester,
        app(
          platform,
          Scaffold(
            body: CheckpointListBody(
              status: CheckpointListStatus.loaded,
              items: const [
                CheckpointListItem(
                  checkpoint: Checkpoint(
                    hash: 'aaa111bbb222',
                    reason: CheckpointReason.beforeEdit,
                  ),
                ),
              ],
              onRefresh: () async {},
            ),
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

  testWidgets('iOS: pulling a short checkpoint list calls refresh', (
    tester,
  ) async {
    var refreshed = 0;
    await pump(
      tester,
      app(
        TargetPlatform.iOS,
        Scaffold(
          body: CheckpointListBody(
            status: CheckpointListStatus.empty,
            onRefresh: () async => refreshed++,
          ),
        ),
      ),
    );
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  group('View > Reload on the Mac', () {
    Future<MacCommandRegistry> pumpMac(WidgetTester tester, Widget home) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(
            platform: TargetPlatform.macOS,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: macCommandsBuilder(commands),
          home: home,
        ),
      );
      await tester.pumpAndSettle();
      return commands;
    }

    testWidgets('reloads the active workers', (tester) async {
      final commands = await pumpMac(
        tester,
        KanbanWorkersScreen(
          repository: KanbanRepository(server.client()),
          board: 'ops',
          onChanged: () {},
        ),
      );
      const path = '/api/plugins/kanban/workers/active';
      final before = server.requestsTo('GET', path).length;
      expect(commands.handlerFor(MacCommand.reload)?.enabled, isTrue);
      expect(commands.invoke(MacCommand.reload), isTrue);
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', path).length, before + 1);
    });

    testWidgets('reloads the Plugins tab in front', (tester) async {
      final commands = await pumpMac(
        tester,
        PluginsScreen(
          repository: HermesPluginManagerRepository(server.client().raw),
        ),
      );
      const path = '/api/dashboard/plugins/hub';
      final before = server.requestsTo('GET', path).length;
      expect(commands.invoke(MacCommand.reload), isTrue);
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', path).length, before + 1);
    });
  });
}
