import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../server_care/server_care_fixtures.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart' show letSocketsIdle;

/// Server care through the real shell: the account menu's Server entry with
/// its attention dot (phone) or the sidebar row with its caption (Mac), the
/// status, the Update page and Usage, in light and dark.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'default', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'd1', title: 'Plan the release')]),
      )
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]))
      ..on('GET', '/api/status', {
        ...statusHealthy(),
        'gateway_running': false,
        'gateway_state': 'stopped',
        'disk': {'pressure': 'elevated', 'free_mb': 8600, 'used_percent': 91.0},
      })
      ..on('GET', '/api/hermes/update/check', updateCheckBehind())
      ..on('GET', '/api/analytics/usage', usage30());
  });

  /// Lets the fake server answer (it runs on real time) and the screen draw.
  Future<void> answered(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpShell(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    required TargetPlatform platform,
    required Brightness brightness,
  }) async {
    await shots.start(tester, size);
    // The status is not read until App Lock has loaded its setting.
    final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    final auth = CatalogAuth(server: server, gated: true);
    addTearDown(auth.dispose);
    final theme = brightness == Brightness.dark
        ? buildHermesDarkTheme(platform: platform)
        : buildHermesLightTheme(platform: platform);
    await tester.pumpWidget(
      shots.frame(
        withAppProviders(
          auth,
          lock: lock,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: withScreenshotFont(theme),
            home: const AppShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await answered(tester);
  }

  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openUsage(WidgetTester tester, ScreenshotRecorder shots) async {
    await tester.scrollUntilVisible(
      find.text('Usage'),
      300,
      scrollable: find
          .ancestor(
            of: find.text('Messaging gateway'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Usage'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Usage'));
    await tester.pump(const Duration(milliseconds: 600));
    await answered(tester);
    await shots.capture(tester, 'usage');
  }

  for (final (name, brightness) in [
    ('phone', Brightness.light),
    ('phone-dark', Brightness.dark),
  ]) {
    testWidgets('$name: account menu, status, update and usage', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('server-care-$name');
      await pumpShell(
        tester,
        shots,
        size: const Size(390, 844),
        platform: TargetPlatform.android,
        brightness: brightness,
      );
      await tester.tap(findAppIcon(AppIcons.menu).first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      // The drawer's account button carries the attention dot.
      await shots.capture(tester, 'drawer');
      await tester.tap(find.byTooltip('Account'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await shots.capture(tester, 'account-menu');
      expect(find.text('Server · needs attention'), findsOneWidget);

      await tester.ensureVisible(find.text('Server · needs attention'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Server · needs attention'));
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'status');
      expect(find.text('The messaging gateway is off'), findsOneWidget);

      await tester.tap(find.textContaining('Update available'));
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'update');
      expect(find.text("What's new"), findsOneWidget);
      await back(tester);

      await openUsage(tester, shots);
      await letSocketsIdle(tester);
    });
  }

  Map<String, dynamic> gatewayStatus({
    required bool running,
    String? state,
    Object? shared,
  }) => {
    ...statusHealthy(),
    'gateway_running': running,
    'gateway_state': state ?? (running ? 'running' : 'stopped'),
    'active_agents': running ? 2 : 0,
    'gateway_shared_with': ?shared,
  };

  Map<String, dynamic> action(String name, {required bool running}) => {
    'name': name,
    'running': running,
    'exit_code': running ? null : 0,
    'pid': 1,
    'lines': ['=== $name started 2026-11-14 09:00:00 ===', 'ok'],
  };

  Future<void> openServer(WidgetTester tester) async {
    await tester.tap(findAppIcon(AppIcons.menu).first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.textContaining('Server'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('Server').first);
    await tester.pump(const Duration(milliseconds: 600));
    await answered(tester);
  }

  /// Runs the fake clock and the fake server until [text] is on screen.
  Future<void> until(WidgetTester tester, String text) async {
    for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
      await answered(tester);
      await tester.pump(const Duration(seconds: 2));
    }
    await answered(tester);
  }

  testWidgets('phone: restart the gateway, with the question, to done', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('server-care-gateway-restart');
    server
      ..on('GET', '/api/status', {
        ...gatewayStatus(running: true, shared: ['default', 'work']),
        'disk': {'pressure': 'elevated', 'free_mb': 8600, 'used_percent': 91.0},
      })
      ..on('POST', '/api/gateway/restart', {
        'ok': true,
        'pid': 1,
        'name': 'gateway-restart',
      })
      ..on(
        'GET',
        '/api/actions/gateway-restart/status',
        action('gateway-restart', running: true),
      );
    await pumpShell(
      tester,
      shots,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      brightness: Brightness.light,
    );
    await openServer(tester);
    await tester.scrollUntilVisible(
      find.text('Restart gateway'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await shots.capture(tester, 'gateway-idle');

    await tester.tap(find.text('Restart gateway'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await shots.capture(tester, 'question');
    expect(find.text('Restart the messaging gateway?'), findsOneWidget);
    expect(find.textContaining('This gateway is shared'), findsOneWidget);
    // Two text buttons, Cancel first; nothing is filled.
    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester.getTopLeft(find.text('Cancel')).dx,
      lessThan(tester.getTopLeft(find.text('Restart for all')).dx),
    );
    await tester.tap(find.text('Restart for all'));
    await tester.pump(const Duration(milliseconds: 600));
    await answered(tester);
    expect(server.requestsTo('POST', '/api/gateway/restart'), hasLength(1));
    // The child runs and the gateway is down: progress in the headline and
    // the row.
    server.on(
      'GET',
      '/api/status',
      gatewayStatus(
        running: false,
        state: 'starting',
        shared: ['default', 'work'],
      ),
    );
    await answered(tester);
    await tester.pump(const Duration(seconds: 2));
    await answered(tester);
    await shots.capture(tester, 'restarting');
    expect(find.text('Waiting for the gateway…'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pump(const Duration(milliseconds: 600));
    await shots.capture(tester, 'restarting-headline');
    expect(find.text('Restarting the messaging gateway…'), findsOneWidget);

    // It comes back.
    server
      ..on(
        'GET',
        '/api/actions/gateway-restart/status',
        action('gateway-restart', running: false),
      )
      ..on(
        'GET',
        '/api/status',
        gatewayStatus(running: true, shared: ['default', 'work']),
      );
    await until(tester, 'Running again');
    expect(find.text('Running again'), findsOneWidget);
    await shots.capture(tester, 'done');
    expect(find.text('Running again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await letSocketsIdle(tester);
  });

  testWidgets('phone: start a gateway that is off, no question', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('server-care-gateway-start');
    server
      ..on('POST', '/api/gateway/start', {
        'ok': true,
        'pid': 2,
        'name': 'gateway-start',
      })
      ..on(
        'GET',
        '/api/actions/gateway-start/status',
        action('gateway-start', running: true),
      );
    await pumpShell(
      tester,
      shots,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
      brightness: Brightness.light,
    );
    await openServer(tester);
    await shots.capture(tester, 'off');
    await tester.tap(find.text('Start gateway').first);
    await tester.pump(const Duration(milliseconds: 600));
    await answered(tester);
    expect(find.text('Restart the messaging gateway?'), findsNothing);
    expect(server.requestsTo('POST', '/api/gateway/start'), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await answered(tester);
    await shots.capture(tester, 'starting');
    expect(find.text('Starting the messaging gateway…'), findsOneWidget);

    server
      ..on(
        'GET',
        '/api/actions/gateway-start/status',
        action('gateway-start', running: false),
      )
      ..on('GET', '/api/status', gatewayStatus(running: true));
    await until(tester, 'Running again');
    expect(find.text('Running again'), findsOneWidget);
    await shots.capture(tester, 'done');
    await tester.pump(const Duration(seconds: 6));
    await letSocketsIdle(tester);
  });

  for (final (name, brightness) in [
    ('mac', Brightness.light),
    ('mac-dark', Brightness.dark),
  ]) {
    testWidgets('$name: sidebar row, status and usage', (tester) async {
      final shots = ScreenshotRecorder('server-care-$name');
      await pumpShell(
        tester,
        shots,
        size: const Size(1160, 760),
        platform: TargetPlatform.macOS,
        brightness: brightness,
      );
      await shots.capture(tester, 'sidebar');
      expect(find.text('Needs attention'), findsWidgets);

      await tester.tap(find.text('Server').first);
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'status');
      expect(find.text('The messaging gateway is off'), findsOneWidget);

      await openUsage(tester, shots);
      await letSocketsIdle(tester);
    });
  }
}
