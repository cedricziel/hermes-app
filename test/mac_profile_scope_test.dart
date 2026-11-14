import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/screens/home_screen.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profiles_view.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../widgetbook/catalog_auth.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/protected_catalog_auth.dart';

/// Profile scope in a Mac window: the switcher at the top of the sidebar, the
/// Profiles page, and the account footer.
void main() {
  late FakeHermesServer server;
  var signOuts = 0;

  setUp(() {
    signOuts = 0;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true, skillCount: 7),
          profileRow(name: 'work', description: 'Day job', skillCount: 12),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('POST', '/api/profiles/active', {'ok': true})
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'd1', title: 'Home chat')]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'w1', title: 'Office chat')]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.test/mcp'),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(id: 'telegram', name: 'Telegram', enabled: true),
          platformRow(id: 'slack', name: 'Slack'),
        ]),
      )
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(id: 'telegram', name: 'Telegram', enabled: true),
          platformRow(id: 'slack', name: 'Slack', enabled: true),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/learning/graph',
        {
          'nodes': [
            for (final i in [1, 2, 3])
              {
                'id': 'memory:memory:$i:d',
                'kind': 'memory',
                'label': 'Note $i',
              },
            {'id': 'skill', 'kind': 'skill', 'label': 'Skill'},
          ],
        },
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/learning/graph',
        {'detail': 'down'},
        status: 500,
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/model/auxiliary',
        {'detail': 'down'},
        status: 500,
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/dashboard/plugins/hub',
        {
          'plugins': [
            {'name': 'netbox', 'runtime_status': 'enabled'},
          ],
        },
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/dashboard/plugins/hub',
        {
          'plugins': [
            {'name': 'netbox', 'runtime_status': 'enabled'},
            {'name': 'jira', 'runtime_status': 'enabled'},
            {'name': 'linear', 'runtime_status': 'disabled'},
          ],
        },
        query: {'profile': 'work'},
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
    MacCommandRegistry? registry,
    BreadcrumbTrail? trail,
    AppLockController? lock,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _CountingAuth(server, () => signOuts++);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      withAppProviders(
        auth,
        lock: lock,
        Provider<Breadcrumbs>.value(
          value: trail == null ? Breadcrumbs.none : Breadcrumbs.of(trail),
          child: MaterialApp(
            theme: buildHermesLightTheme(platform: platform),
            home: registry == null
                ? const AppShell()
                : MacCommandScope.root(
                    registry: registry,
                    child: const AppShell(),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ThreadSidebar), matching: finder);

  testWidgets('the switcher sits above the destinations', (tester) async {
    await pump(tester);
    final switcher = find.byKey(const Key('mac-profile-switcher'));
    expect(switcher, findsOneWidget);
    expect(
      tester.getTopLeft(switcher).dy,
      lessThan(tester.getTopLeft(inSidebar(find.text('Chat'))).dy),
    );
    expect(inSidebar(find.text('Profiles')), findsOneWidget);
  });

  testWidgets('switching selects a local recipient and lists its chats', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Home chat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mac-profile-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('work').last);
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    expect(
      server.requests.where(
        (r) =>
            r.method != 'GET' &&
            (r.path == '/api/profiles' ||
                r.path.startsWith('/api/profiles/') ||
                r.path.startsWith('/api/config')),
      ),
      isEmpty,
    );
    expect(find.text('Office chat'), findsOneWidget);
    expect(find.text('Home chat'), findsNothing);
  });

  testWidgets('the sidebar has no management rows on macOS', (tester) async {
    await pump(tester);
    expect(inSidebar(find.text('More')), findsNothing);
    expect(inSidebar(find.text('Skills')), findsNothing);
  });

  testWidgets('other platforms keep them and have no switcher', (tester) async {
    await pump(tester, platform: TargetPlatform.windows);
    expect(find.byKey(const Key('mac-profile-switcher')), findsNothing);
    expect(inSidebar(find.text('More')), findsOneWidget);
  });

  testWidgets('the Profiles page counts what a profile holds', (tester) async {
    await pump(tester);
    await tester.tap(inSidebar(find.text('Profiles')));
    await tester.pumpAndSettle();
    expect(find.text('2 profiles on hermes.example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-row-work')));
    await tester.pumpAndSettle();

    String? countIn(ProfileSection section) {
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey('profile-section-${section.name}')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      return texts.length > 2 ? texts.last : null;
    }

    expect(countIn(ProfileSection.skills), '12');
    expect(countIn(ProfileSection.memory), '3');
    expect(countIn(ProfileSection.mcp), '1');
    expect(countIn(ProfileSection.helperModels), isNull);
    expect(countIn(ProfileSection.messaging), '2');
    expect(countIn(ProfileSection.plugins), '2');

    await tester.tap(find.byKey(const ValueKey('profile-row-default')));
    await tester.pumpAndSettle();
    expect(countIn(ProfileSection.memory), isNull);
    expect(countIn(ProfileSection.messaging), '1');
    expect(countIn(ProfileSection.plugins), '1');

    await tester.tap(find.byKey(const Key('mac-profile-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('work').last);
    await tester.pumpAndSettle();
    expect(countIn(ProfileSection.messaging), '1');
    expect(countIn(ProfileSection.plugins), '1');
  });

  testWidgets('the Profiles page opens the plugins of the selected profile', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(inSidebar(find.text('Profiles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-row-work')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-section-plugins')));
    await tester.pumpAndSettle();

    expect(find.text('jira'), findsOneWidget);
  });

  testWidgets('the Profiles page opens the memory of the selected profile', (
    tester,
  ) async {
    final trail = BreadcrumbTrail();
    await pump(tester, trail: trail);
    await tester.tap(inSidebar(find.text('Profiles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-row-work')));
    await tester.pumpAndSettle();

    final sections = [for (final s in ProfileSection.values) s.name];
    expect(sections.indexOf('memory'), sections.indexOf('skills') + 1);

    await tester.tap(find.byKey(const ValueKey('profile-section-memory')));
    await tester.pumpAndSettle();
    // The nodes name no memorySource, so they are listed under Agent notes.
    await tester.tap(find.text('Agent notes'));
    await tester.pumpAndSettle();

    expect(find.text('Note 1'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/learning/graph').last.queryParameters,
      {'profile': 'work'},
    );
    expect(
      trail.recent
          .where((crumb) => crumb.name == 'nav.memory')
          .map((crumb) => crumb.attributes),
      [
        {'from': 'profiles_page'},
      ],
    );
  });

  testWidgets('the account footer opens Settings', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mac-account-footer')).first);
    await tester.pumpAndSettle();
    expect(find.text('Signed in to the dashboard'), findsOneWidget);

    await tester.tap(find.text('Settings…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-appearance')), findsOneWidget);
    expect(find.text('About Hermes'), findsOneWidget);
  });

  testWidgets('Settings in the menu bar opens the settings list', (
    tester,
  ) async {
    final registry = MacCommandRegistry();
    addTearDown(registry.dispose);
    await pump(tester, registry: registry);

    expect(registry.invoke(MacCommand.settings), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-appearance')), findsOneWidget);
  });

  testWidgets('Settings in the menu bar opens the settings list on an iPad', (
    tester,
  ) async {
    final registry = MacCommandRegistry();
    addTearDown(registry.dispose);
    await pump(tester, platform: TargetPlatform.iOS, registry: registry);

    expect(registry.invoke(MacCommand.settings), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-appearance')), findsOneWidget);
  });

  group('account commands in the menu bar', () {
    testWidgets('Connection Details opens the connection page', (tester) async {
      final registry = MacCommandRegistry();
      addTearDown(registry.dispose);
      await pump(tester, registry: registry);

      expect(registry.invoke(MacCommand.connectionDetails), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Sign Out asks first, and Cancel keeps the user signed in', (
      tester,
    ) async {
      final registry = MacCommandRegistry();
      addTearDown(registry.dispose);
      await pump(tester, registry: registry);

      expect(registry.invoke(MacCommand.signOut), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Sign out of the dashboard?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(signOuts, 0);

      registry.invoke(MacCommand.signOut);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(signOuts, 1);
    });

    testWidgets('an iPad offers the same commands', (tester) async {
      final registry = MacCommandRegistry();
      addTearDown(registry.dispose);
      await pump(tester, platform: TargetPlatform.iOS, registry: registry);

      expect(registry.invoke(MacCommand.connectionDetails), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(HomeScreen))).pop();
      await tester.pumpAndSettle();

      expect(registry.invoke(MacCommand.signOut), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Sign out of the dashboard?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(signOuts, 0);
    });

    testWidgets('the footer asks the same before signing out', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('mac-account-footer')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of the dashboard?'), findsOneWidget);
      await tester.tap(find.text('Sign Out').last);
      await tester.pumpAndSettle();
      expect(signOuts, 1);
    });
  });

  group('server care', () {
    /// The status is not read while App Lock still covers the app, which it
    /// does until it has loaded its setting.
    Future<AppLockController> loadedLock(WidgetTester tester) async {
      final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await tester.runAsync(lock.load);
      return lock;
    }

    void statusWithGatewayOff() => server.on('GET', '/api/status', {
      'version': '0.22.2',
      'gateway_running': false,
      'gateway_state': 'stopped',
      'components': {
        'platforms': {'configured': 1, 'connected': 0},
      },
      'profiles': ['default', 'work'],
    });

    testWidgets('the Mac sidebar lists Server after Profiles with its '
        'caption', (tester) async {
      statusWithGatewayOff();
      await pump(tester, lock: await loadedLock(tester));
      final labels = [
        for (final label in ['Chat', 'Profiles', 'Server'])
          tester.getTopLeft(inSidebar(find.text(label))).dy,
      ];
      expect(labels, orderedEquals([...labels]..sort()));
      expect(inSidebar(find.text('Needs attention')), findsOneWidget);
    });

    testWidgets('the Mac sidebar row has no caption while the server is fine', (
      tester,
    ) async {
      server.on('GET', '/api/status', {
        'version': '0.22.2',
        'gateway_running': true,
        'gateway_state': 'running',
      });
      await pump(tester, lock: await loadedLock(tester));
      expect(inSidebar(find.text('Server')), findsOneWidget);
      expect(inSidebar(find.text('Needs attention')), findsNothing);
    });

    testWidgets('the Mac sidebar row says Updating… while an update runs, and '
        'the restart banner sits above the destination', (tester) async {
      server
        ..on('GET', '/api/status', {
          'version': '0.22.2',
          'gateway_running': true,
          'gateway_state': 'running',
        })
        ..on('POST', '/api/hermes/update', {
          'ok': true,
          'pid': 1,
          'name': 'hermes-update',
          'action_id': 'a' * 32,
        })
        // The window is wide, so the Server page shows Usage beside its list;
        // a server that answers (here with a state, not a chart) keeps it there
        // for the whole test.
        ..on('GET', '/api/analytics/usage', {'detail': 'busy'}, status: 503)
        // The dashboard is gone for as long as the test looks.
        ..onRequest('GET', '/api/health', (o) {
          throw DioException.connectionError(requestOptions: o, reason: 'down');
        })
        ..onRequest('GET', '/api/actions/hermes-update/status', (o) {
          throw DioException.connectionError(requestOptions: o, reason: 'down');
        });
      await pump(tester, lock: await loadedLock(tester));
      final run = tester
          .element(find.byType(ThreadSidebar))
          .read<HermesUpdateRun>();
      expect(inSidebar(find.text('Updating…')), findsNothing);
      expect(
        find.text(
          'Hermes is restarting after the update. Chats '
          "continue when it's back.",
        ),
        findsNothing,
      );

      run.start().ignore();
      await tester.pump(const Duration(seconds: 3));
      expect(run.phase, UpdatePhase.restarting);
      expect(inSidebar(find.text('Updating…')), findsOneWidget);
      expect(
        find.text(
          "Hermes is restarting after the update. Chats continue when it's back.",
        ),
        findsOneWidget,
      );

      // Leaving and returning: the caption holds on another destination, too.
      await tester.tap(inSidebar(find.text('Server')));
      await tester.pump(const Duration(seconds: 1));
      // The Server page says it on the Updates row, the sidebar in its caption.
      expect(find.text('Updating…'), findsAtLeastNWidgets(2));
      expect(
        find.text(
          "Hermes is restarting after the update. Chats continue when it's back.",
        ),
        findsOneWidget,
      );
      await run.reset();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Updating…'), findsNothing);
    });

    testWidgets('a server without the status route has no Server row or menu '
        'item', (tester) async {
      server.on('GET', '/api/status', {'detail': 'Not Found'}, status: 404);
      await pump(tester, lock: await loadedLock(tester));
      expect(inSidebar(find.text('Server')), findsNothing);
    });

    testWidgets('opening Server shows the headline from the status', (
      tester,
    ) async {
      statusWithGatewayOff();
      await pump(tester, lock: await loadedLock(tester));
      await tester.tap(inSidebar(find.text('Server')));
      await tester.pumpAndSettle();
      expect(find.text('The messaging gateway is off'), findsOneWidget);
    });

    testWidgets('the account menu offers Server after Connection details, '
        'with the mark', (tester) async {
      statusWithGatewayOff();
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        platform: TargetPlatform.android,
        lock: await loadedLock(tester),
      );
      expect(
        find.bySemanticsLabel(RegExp('Account, server needs attention')),
        findsOne,
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      final connection = tester.getTopLeft(find.text('Connection details')).dy;
      final server = tester
          .getTopLeft(find.text('Server · needs attention'))
          .dy;
      final about = tester.getTopLeft(find.text('About')).dy;
      expect(connection, lessThan(server));
      expect(server, lessThan(about));
      handle.dispose();
    });

    testWidgets('the account menu says only Server while the server is fine', (
      tester,
    ) async {
      server.on('GET', '/api/status', {
        'version': '0.22.2',
        'gateway_running': true,
        'gateway_state': 'running',
      });
      await pump(
        tester,
        platform: TargetPlatform.android,
        lock: await loadedLock(tester),
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Server · needs attention'), findsNothing);
    });
  });
}

class _CountingAuth extends ProtectedCatalogAuth {
  _CountingAuth(super.server, this.onSignOut);

  final VoidCallback onSignOut;

  @override
  Future<void> signOut() async => onSignOut();
}
