import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:provider/provider.dart';

import '../hermes_plugin_manager_repository_test.dart' show providersHub;
import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work'), profileRow(name: 'other')],
      })
      ..on('GET', '/api/profiles/active', {
        'active': 'other',
        'current': 'other',
      })
      ..on('GET', '/api/learning/graph', memoryGraph);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> pumpDestination(WidgetTester tester, String profile) async {
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: HermesRepositories(server.client()),
        child: MaterialApp(home: MemoryDestination(profile: profile)),
      ),
    );
    await settle(tester);
  }

  testWidgets('opens on the named profile, not the active one', (tester) async {
    await pumpDestination(tester, 'work');

    expect(find.text('User preference'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/learning/graph').single.queryParameters,
      {'profile': 'work'},
    );
    expect(server.requestsTo('GET', '/api/profiles/active'), isEmpty);
  });

  testWidgets('the subtitle menu still switches profile', (tester) async {
    await pumpDestination(tester, 'work');

    await tester.tap(find.byKey(const Key('settings-subtitle-menu')));
    await settle(tester);
    await tester.tap(find.text('other').last);
    await settle(tester);

    expect(
      server.requestsTo('GET', '/api/learning/graph').last.queryParameters,
      {'profile': 'other'},
    );
    expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    expect(
      server
          .requestsTo('GET', '/api/config')
          .map((request) => request.queryParameters['profile']),
      containsAllInOrder(['work', 'other']),
    );
  });

  testWidgets('a profile the server no longer lists is unavailable', (
    tester,
  ) async {
    await pumpDestination(tester, 'gone');

    expect(find.text('This profile is no longer available.'), findsOneWidget);
    expect(find.text('Long memory'), findsNothing);
    expect(server.requestsTo('GET', '/api/learning/graph'), isEmpty);
  });

  testWidgets('the provider row opens Plugins on Providers for that profile', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server
      ..on('GET', '/api/memory', memoryStatus())
      ..on('GET', '/api/dashboard/plugins/hub', providersHub());
    await pumpDestination(tester, 'work');

    await tester.tap(find.text('Memory provider'));
    await settle(tester);

    expect(find.byType(PluginsScreen), findsOneWidget);
    expect(
      tester.widget<PluginsScreen>(find.byType(PluginsScreen)).initialTab,
      PluginsTab.providers,
    );
    expect(
      server
          .requestsTo('GET', '/api/dashboard/plugins/hub')
          .map((request) => request.queryParameters['profile']),
      everyElement('work'),
    );
    expect(server.requestsTo('GET', '/api/dashboard/plugins/catalog'), isEmpty);
  });
}
