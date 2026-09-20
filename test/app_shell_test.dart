import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// The Kanban tab exists only while the server has the plugin on.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
  });

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            kanbanBuilder: (_) => const Text('the board'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void kanbanPlugin({required bool on}) => server.on(
    'GET',
    '/api/dashboard/plugins',
    on
        ? [
            {'name': 'kanban'},
          ]
        : <Object?>[],
  );

  testWidgets('shows no navigation while the plugin is off', (tester) async {
    kanbanPlugin(on: false);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('offers a Kanban tab in a bottom bar on a phone', (tester) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kanban'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('the board'), findsOneWidget);
  });

  testWidgets('offers a Kanban tab in a rail on a wide screen', (tester) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(1400, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('drops the tab when the plugin is turned off', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);

    kanbanPlugin(on: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('ignores a slower answer that a newer check has superseded', (
    tester,
  ) async {
    final first = Completer<FakeResponse>();
    var calls = 0;
    server.onRequest('GET', '/api/dashboard/plugins', (_) {
      calls++;
      return calls == 1 ? first.future : (status: 200, body: <Object?>[]);
    });
    await pumpShell(tester, size: const Size(400, 800));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    first.complete((
      status: 200,
      body: [
        {'name': 'kanban'},
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });
}
