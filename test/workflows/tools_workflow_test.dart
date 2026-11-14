import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';
import '../support/protected_catalog_auth.dart';
import '../support/pump_chat.dart' show openSidebarMore;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart' show newAppLock, workflowPlatform;
import '../tools/tools_screen_fixtures.dart';

/// The Tools screen from the real shell: the entry in the sidebar or the
/// drawer, the list, a plain switch, the question before Terminal, the
/// details, and the states a list can be in. The widest layout starts at 900
/// logical pixels, where the details sit beside the list.
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
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]))
      ..on('GET', '/api/model/auxiliary', {
        'tasks': <Object?>[],
        'main': {'provider': 'nous', 'model': 'hermes-4'},
      });
    routeTools(server);
  });

  ThemeData theme(Brightness brightness, TargetPlatform? platform) =>
      withScreenshotFont(
        brightness == Brightness.dark
            ? buildHermesDarkTheme(platform: platform)
            : buildHermesLightTheme(platform: platform),
      );

  Widget app(
    Widget home, {
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
    Locale? locale,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme(brightness, platform ?? workflowPlatform),
    home: home,
  );

  /// The whole app shell on a server with Tools.
  Future<void> pumpShell(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
    Locale? locale,
  }) async {
    await shots.start(tester, size);
    final auth = ProtectedCatalogAuth(server);
    addTearDown(auth.dispose);
    // A loaded lock: an app whose lock has not loaded is still covered.
    final lock = await newAppLock(tester);
    await tester.pumpWidget(
      shots.frame(
        withAppProviders(
          auth,
          lock: lock,
          app(
            const AppShell(),
            brightness: brightness,
            platform: platform,
            locale: locale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The screen on its own, for states the shell's first read hides.
  Future<void> pumpScreen(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
    Locale? locale,
    bool settle = true,
  }) async {
    await shots.start(tester, size);
    await tester.pumpWidget(
      shots.frame(
        app(
          ToolsScreen(
            repository: HermesToolsRepository(
              server.client().raw,
              profile: 'work',
            ),
          ),
          brightness: brightness,
          platform: platform,
          locale: locale,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool phoneLayout(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).fullPage;

  /// Opens Tools from where the layout keeps it: the phone's drawer or the
  /// sidebar's More section.
  Future<void> openTools(WidgetTester tester) async {
    if (phoneLayout(tester)) {
      await tester.tap(find.byKey(const Key('shell-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('Tools')),
      );
    } else {
      await openSidebarMore(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text('Tools'),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  Finder row(String name) => find.byKey(ValueKey('tool-row-$name'));
  Finder switchOf(String name) =>
      find.descendant(of: row(name), matching: find.byType(ToolsSwitch));

  Future<void> tapSwitch(WidgetTester tester, String name) async {
    await tester.ensureVisible(switchOf(name));
    await tester.pump();
    await tester.tap(switchOf(name));
  }

  Iterable<RequestOptions> puts() => server.requests.where(
    (r) => r.method == 'PUT' && r.path.startsWith('/api/tools/toolsets/'),
  );

  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('tools-list')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final suffix = brightness == Brightness.dark ? '$name-dark' : name;

      testWidgets('$suffix: open Tools, switch, ask before Terminal', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('tools-$suffix');
        await pumpShell(tester, shots, size: size, brightness: brightness);
        await openTools(tester);
        await shots.capture(tester, 'list');

        await tapSwitch(tester, 'todo');
        await tester.pumpAndSettle();
        await scrollToTop(tester);
        expect(puts().map((r) => r.path), ['/api/tools/toolsets/todo']);
        expect(find.text('Applies from your next chat.'), findsOneWidget);
        await shots.capture(tester, 'switched');

        await tapSwitch(tester, 'terminal');
        await tester.pumpAndSettle();
        expect(find.text('Let Hermes run commands?'), findsOneWidget);
        // Nothing is sent while the question is open, and the switch is off.
        expect(puts(), hasLength(1));
        expect(tester.widget<ToolsSwitch>(switchOf('terminal')).value, isFalse);
        await shots.capture(tester, 'terminal-question');

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Let Hermes run commands?'), findsNothing);
        expect(puts(), hasLength(1));
        await shots.capture(tester, 'cancelled');

        final text = find.descendant(
          of: find.byKey(const Key('tools-list')),
          matching: find.text('Run commands on the machine where Hermes runs.'),
        );
        await tester.ensureVisible(text);
        await tester.pump();
        await tester.tap(text);
        await tester.pumpAndSettle();
        await shots.capture(tester, 'detail');

        // The detail's own tool names.
        await tester.tap(find.textContaining('What\'s inside'));
        await tester.pumpAndSettle();
        expect(find.text('process'), findsOneWidget);
        await shots.capture(tester, 'detail-inside');
      });

      testWidgets('$suffix: a lost answer ends in "Couldn\'t confirm"', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('tools-lost-$suffix');
        await pumpScreen(tester, shots, size: size, brightness: brightness);
        loseAnswer(server, 'PUT', '/api/tools/toolsets/todo');
        holdAnswer(server, 'GET', '/api/tools/toolsets');

        await tapSwitch(tester, 'todo');
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('May have changed. Checking…'), findsOneWidget);
        await shots.capture(tester, 'checking');

        await tester.pump(const Duration(seconds: 11));
        expect(find.textContaining('Couldn\'t confirm.'), findsOneWidget);
        expect(puts(), hasLength(1));
        await shots.capture(tester, 'couldnt-confirm');
      });

      testWidgets('$suffix: the states of the list', (tester) async {
        final shots = ScreenshotRecorder('tools-states-$suffix');
        final gate = holdAnswer(server, 'GET', '/api/tools/toolsets');
        await pumpScreen(
          tester,
          shots,
          size: size,
          brightness: brightness,
          settle: false,
        );
        expect(find.text('Loading tools…'), findsOneWidget);
        await shots.capture(tester, 'loading');
        server.on('GET', '/api/tools/toolsets', toolsCatalog());
        gate.complete();
        await tester.pumpAndSettle();

        goOffline(server, 'GET', '/api/tools/toolsets');
        await tester.fling(
          find.byKey(const Key('tools-list')),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.text('You\'re offline.'), findsOneWidget);
        expect(row('terminal'), findsOneWidget);
        await shots.capture(tester, 'offline');

        server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 500);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Couldn\'t load tools.'), findsOneWidget);
        expect(row('terminal'), findsOneWidget);
        await shots.capture(tester, 'couldnt-load');

        server.on('GET', '/api/tools/toolsets', {
          'detail': 'Not Found',
        }, status: 404);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(
          find.text('This server doesn\'t offer tools settings.'),
          findsOneWidget,
        );
        await shots.capture(tester, 'old-server');
      });
    }
  }

  testWidgets('Linux, narrow: a lost answer offers Try again', (tester) async {
    final shots = ScreenshotRecorder('tools-lost-linux');
    await pumpScreen(
      tester,
      shots,
      size: phoneSize,
      platform: TargetPlatform.linux,
    );
    loseAnswer(server, 'PUT', '/api/tools/toolsets/todo');
    holdAnswer(server, 'GET', '/api/tools/toolsets');

    await tapSwitch(tester, 'todo');
    await tester.pump(const Duration(seconds: 11));

    expect(find.text('Couldn\'t confirm.'), findsOneWidget);
    expect(puts(), hasLength(1));
    await shots.capture(tester, 'couldnt-confirm');
  });

  testWidgets('desktop: an old server has no entry', (tester) async {
    server.on('GET', '/api/tools/toolsets', {
      'detail': 'Not Found',
    }, status: 404);
    final shots = ScreenshotRecorder('tools-old-server');
    await pumpShell(tester, shots, size: desktopSize);
    await openSidebarMore(tester);
    await shots.capture(tester, 'sidebar');
    expect(find.text('Tools'), findsNothing);
  });

  testWidgets('phone: an old server has no entry in the drawer', (
    tester,
  ) async {
    server.on('GET', '/api/tools/toolsets', {
      'detail': 'Not Found',
    }, status: 404);
    final shots = ScreenshotRecorder('tools-old-server-phone');
    await pumpShell(tester, shots, size: phoneSize);
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'drawer');
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Tools')),
      findsNothing,
    );
  });

  testWidgets('phone, German: the list and the question', (tester) async {
    final shots = ScreenshotRecorder('tools-de');
    await pumpShell(tester, shots, size: phoneSize, locale: const Locale('de'));
    await tester.tap(find.byKey(const Key('shell-menu')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'drawer');
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Tools')),
    );
    await tester.pumpAndSettle();
    await shots.capture(tester, 'list');

    await tapSwitch(tester, 'terminal');
    await tester.pumpAndSettle();
    await shots.capture(tester, 'terminal-question');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });

  testWidgets('Mac: the Profiles page, the list beside its details', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('tools-mac');
    await pumpShell(
      tester,
      shots,
      size: desktopSize,
      platform: TargetPlatform.macOS,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Profiles'),
      ),
    );
    await tester.pumpAndSettle();
    await shots.capture(tester, 'profiles-page');

    await tester.tap(find.byKey(const ValueKey('profile-section-tools')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'list');

    await tapSwitch(tester, 'terminal');
    await tester.pumpAndSettle();
    await shots.capture(tester, 'terminal-question');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
