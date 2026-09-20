import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';

/// The Kanban tab exists only while the server has the plugin on.
void main() {
  late FakeHermesServer server;
  late FakeShareInbox inbox;
  late FakeNotificationService notifications;

  /// Boards built and torn down, in the order they happened.
  late List<String> boardLog;

  setUp(() {
    boardLog = [];
    inbox = FakeShareInbox();
    notifications = FakeNotificationService();
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
            create: (_) => ShareController(inbox)..start(),
          ),
          Provider<NotificationService>.value(value: notifications),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            kanbanBuilder: (_) => _Board(boardLog),
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

  Future<void> openKanban(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kanban'),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> flipPlugin(WidgetTester tester, {required bool on}) async {
    kanbanPlugin(on: on);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('a notification tap switches from Kanban to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    expect(selectedTab(tester), 1);

    notifications.tap('t2');
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  testWidgets('shared content switches from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedText('https://example.com')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('shared files switch from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedFile(path: '/tmp/report.pdf', name: 'report.pdf')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  testWidgets('the board is not built until its tab is opened', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));

    expect(boardLog, isEmpty);
    await openKanban(tester);
    expect(boardLog, ['open']);
  });

  testWidgets('the board and its local state survive a visit to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await tester.enterText(find.byType(TextField), 'deploy');

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chat'),
      ),
    );
    await tester.pumpAndSettle();
    await openKanban(tester);

    expect(find.text('deploy'), findsOneWidget);
    expect(boardLog, ['open']);
  });

  testWidgets('a plugin that goes off and on does not reopen the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    await flipPlugin(tester, on: false);
    await flipPlugin(tester, on: true);

    expect(selectedTab(tester), 0);
    expect(boardLog, ['open', 'close']);
  });
}

/// A stand-in for the Kanban page that records when it starts and stops.
class _Board extends StatefulWidget {
  const _Board(this.log);

  final List<String> log;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  @override
  void initState() {
    super.initState();
    widget.log.add('open');
  }

  @override
  void dispose() {
    widget.log.add('close');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Column(children: [Text('the board'), TextField()]);
}
