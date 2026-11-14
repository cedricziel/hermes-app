import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart' show openSidebarMore;
import 'tools_screen_fixtures.dart';

/// Where Tools is offered: the chat sidebar and the phone drawer after MCP
/// servers and before Helper models, and the Mac Profiles page; nowhere on a
/// server without the routes.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work', description: 'Day job'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]))
      ..on('GET', '/api/model/auxiliary', {
        'tasks': <Object?>[],
        'main': {'provider': 'nous', 'model': 'hermes-4'},
      });
    routeTools(server, on: {'terminal'});
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = ProtectedCatalogAuth(server);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      withAppProviders(
        auth,
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void oldServer() => server.on('GET', '/api/tools/toolsets', {
    'detail': 'Not Found',
  }, status: 404);

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ThreadSidebar), matching: finder);

  group('the sidebar of a wide window', () {
    testWidgets('offers Tools after MCP servers and before Helper models', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1400, 900));
      await openSidebarMore(tester);

      final mcp = tester.getTopLeft(inSidebar(find.text('MCP servers'))).dy;
      final tools = tester.getTopLeft(inSidebar(find.text('Tools'))).dy;
      final helpers = tester
          .getTopLeft(inSidebar(find.text('Helper models')))
          .dy;
      expect(tools, greaterThan(mcp));
      expect(tools, lessThan(helpers));
    });

    testWidgets('opens the screen for the chat\'s profile', (tester) async {
      await pumpShell(tester, size: const Size(1400, 900));
      await openSidebarMore(tester);

      await tester.tap(inSidebar(find.text('Tools')));
      await tester.pumpAndSettle();

      expect(find.byType(ToolsScreen), findsOneWidget);
      expect(find.text('default · 3 on'), findsOneWidget);
      expect(
        server
            .requestsTo('GET', '/api/tools/toolsets')
            .map((r) => r.queryParameters['profile']),
        everyElement('default'),
      );
      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    });

    testWidgets('is not there on an old server, and nothing says why', (
      tester,
    ) async {
      oldServer();
      await pumpShell(tester, size: const Size(1400, 900));
      await openSidebarMore(tester);

      expect(find.text('Helper models'), findsOneWidget);
      expect(find.text('Tools'), findsNothing);
      expect(find.textContaining('tools settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is not there while the first read has failed', (tester) async {
      goOffline(server, 'GET', '/api/tools/toolsets');
      await pumpShell(tester, size: const Size(1400, 900));
      await openSidebarMore(tester);

      expect(find.text('Tools'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is read again on resume, and gone when the route is', (
      tester,
    ) async {
      await pumpShell(tester, size: const Size(1400, 900));
      await openSidebarMore(tester);
      expect(find.text('Tools'), findsOneWidget);
      final before = server.requestsTo('GET', '/api/tools/toolsets').length;

      oldServer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('GET', '/api/tools/toolsets').length,
        before + 1,
      );
      expect(find.text('Tools'), findsNothing);
    });
  });

  group('the drawer of a phone', () {
    Future<void> openDrawer(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('shell-menu')));
      await tester.pumpAndSettle();
    }

    testWidgets('offers Tools in the same place', (tester) async {
      await pumpShell(tester, size: const Size(390, 844));
      await openDrawer(tester);

      final drawer = find.byType(Drawer);
      double top(String label) => tester
          .getTopLeft(find.descendant(of: drawer, matching: find.text(label)))
          .dy;
      expect(top('Tools'), greaterThan(top('MCP servers')));
      expect(top('Tools'), lessThan(top('Helper models')));

      await tester.tap(
        find.descendant(of: drawer, matching: find.text('Tools')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget);
    });

    testWidgets('is not there on an old server', (tester) async {
      oldServer();
      await pumpShell(tester, size: const Size(390, 844));
      await openDrawer(tester);

      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('Tools')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('MCP servers'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the Mac Profiles page', () {
    Future<void> openProfiles(WidgetTester tester) async {
      await tester.tap(inSidebar(find.text('Profiles')));
      await tester.pumpAndSettle();
    }

    testWidgets('has a Tools row with how many are on, opening the screen', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      await openProfiles(tester);

      final row = find.byKey(const ValueKey('profile-section-tools'));
      expect(row, findsOneWidget);
      // Terminal, Web and Files are on: three of six.
      expect(
        find.descendant(of: row, matching: find.text('3 of 6 on')),
        findsOneWidget,
      );
      // After MCP servers, before Helper models.
      final mcp = tester.getTopLeft(
        find.byKey(const ValueKey('profile-section-mcp')),
      );
      final helpers = tester.getTopLeft(
        find.byKey(const ValueKey('profile-section-helperModels')),
      );
      expect(tester.getTopLeft(row).dy, greaterThan(mcp.dy));
      expect(tester.getTopLeft(row).dy, lessThan(helpers.dy));

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(ToolsScreen), findsOneWidget);
      expect(find.text('default · 3 on'), findsOneWidget);
    });

    testWidgets('counts the profile that is selected', (tester) async {
      server.on(
        'GET',
        '/api/tools/toolsets',
        toolsCatalog(withPlugin: false),
        query: {'profile': 'work'},
      );
      await pumpShell(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      await openProfiles(tester);

      await tester.tap(find.byKey(const ValueKey('profile-row-work')));
      await tester.pumpAndSettle();

      expect(
        server
            .requestsTo('GET', '/api/tools/toolsets')
            .any((r) => r.queryParameters['profile'] == 'work'),
        isTrue,
      );
      expect(find.text('2 of 5 on'), findsOneWidget);
    });

    testWidgets('has no Tools row on an old server', (tester) async {
      oldServer();
      await pumpShell(
        tester,
        size: const Size(1200, 800),
        platform: TargetPlatform.macOS,
      );
      await openProfiles(tester);

      expect(find.byKey(const ValueKey('profile-section-mcp')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-section-tools')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  test('Tools sits between MCP servers and Helper models in the sections', () {
    final names = ProfileSection.values.map((s) => s.name).toList();
    expect(names.indexOf('tools'), names.indexOf('mcp') + 1);
    expect(names.indexOf('helperModels'), names.indexOf('tools') + 1);
  });
}
