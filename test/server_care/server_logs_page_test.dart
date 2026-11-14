import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/server_logs_page.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

/// A widget test that puts the platform override back before the framework
/// checks that no debug variable was left changed.
void pageTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late ServerCareController care;
  late FakeDeviceAuthenticator device;
  late AppLockController lock;
  final secureCalls = <Object?>[];
  String? clipboard;

  const secureChannel = MethodChannel('hermes_app/secure_window');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    secureCalls.clear();
    clipboard = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      secureCalls.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    trail = BreadcrumbTrail();
    server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on('GET', '/api/logs', {'file': 'errors', 'lines': logsErrors});
    care = ServerCareController(
      repository: ServerCareRepository(server.client()),
      profile: 'default',
    );
    device = FakeDeviceAuthenticator();
    lock = AppLockController(authenticator: device, coverWhenInactive: false);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    care.dispose();
    lock.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    double width = 400,
    bool withLock = false,
    CareLogFile file = CareLogFile.errors,
    bool pushed = false,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(care.refresh);
    final page = ServerLogsPage(initialFile: file);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(
            value: HermesRepositories(server.client()),
          ),
          ChangeNotifierProvider<ServerCareController>.value(value: care),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          if (withLock)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: pushed
              ? Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiProvider(
                            providers: [
                              ChangeNotifierProvider<
                                ServerCareController
                              >.value(value: care),
                            ],
                            child: page,
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                )
              : page,
        ),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('open'));
    }
    await tester.pumpAndSettle();
  }

  List<Map<String, dynamic>> reads() => server
      .requestsTo('GET', '/api/logs')
      .map((r) => r.queryParameters)
      .toList();

  pageTest('reads the errors file for the profile and shows its lines', (
    tester,
  ) async {
    await pump(tester);
    expect(reads(), [
      {'file': 'errors', 'lines': 200, 'profile': 'default'},
    ]);
    expect(find.text('Logs'), findsWidgets);
    expect(find.text('default · newest first'), findsOneWidget);
    expect(find.text('Telegram failed'), findsOneWidget);
    expect(find.text('retrying'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    // The newest entry is on top.
    expect(
      tester.getTopLeft(find.text('retrying')).dy,
      lessThan(tester.getTopLeft(find.text('Telegram failed')).dy),
    );
  });

  pageTest('the opening breadcrumb names the file and nothing else', (
    tester,
  ) async {
    await pump(tester, file: CareLogFile.gateway);
    expect(reads().single['file'], 'gateway');
    final crumbs = trail.recent.where(
      (r) => r.name == 'server_care.logs.opened',
    );
    expect(crumbs.single.attributes, {'file': 'gateway'});
  });

  pageTest('the tabs, the level menu and the search send their choices', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    expect(reads().last['file'], 'agent');

    await tester.tap(find.text('All levels'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warnings and errors'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(reads().last['level'], 'WARNING');

    await tester.enterText(find.byType(TextField), 'timeout');
    await tester.pump(const Duration(milliseconds: 300));
    expect(reads().last.containsKey('search'), isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(reads().last, {
      'file': 'agent',
      'level': 'WARNING',
      'search': 'timeout',
      'lines': 200,
      'profile': 'default',
    });
  });

  pageTest('an empty log and a filtered one say so', (tester) async {
    server.on('GET', '/api/logs', {'lines': []});
    await pump(tester);
    expect(find.text('Nothing logged yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('No lines match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(reads().last.containsKey('search'), isFalse);
  });

  pageTest('offline and refused reads say so, with a retry', (tester) async {
    server.on('GET', '/api/logs', {
      'detail': 'The log is locked.',
    }, status: 400);
    await pump(tester);
    expect(find.text('The log is locked.'), findsOneWidget);
    server.on('GET', '/api/logs', {'lines': logsErrors});
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram failed'), findsOneWidget);
  });

  pageTest('Show older lines asks for 500', (tester) async {
    server.on('GET', '/api/logs', {
      'lines': [
        for (var i = 0; i < 200; i++)
          '2026-11-14 09:12:03,114 INFO a.b: line $i',
      ],
    });
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text('Show older lines'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Show older lines'));
    await tester.pumpAndSettle();
    expect(reads().last['lines'], 500);
  });

  group('copy', () {
    Future<void> openCopy(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('logs-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy shown lines'));
      await tester.pumpAndSettle();
    }

    pageTest('asks first, and copies nothing on Cancel', (tester) async {
      await pump(tester);
      await openCopy(tester);
      expect(find.text('Copy these log lines?'), findsOneWidget);
      expect(find.textContaining('Logs can contain private details'), findsOne);
      expect(clipboard, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(clipboard, isNull);
    });

    pageTest('copies the shown lines, as shown, after Copy', (tester) async {
      await pump(tester);
      await openCopy(tester);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard!.split('\n'), [
        '2026-11-14 09:12:04,001 WARNING agent.loop: retrying',
        '2026-11-14 09:12:03,114 ERROR [sess_ab12] gateway.run: Telegram failed',
        'Traceback (most recent call last):',
        '  File "x.py", line 1, in <module>',
        'ValueError: boom',
      ]);
      expect(find.text('Log lines copied'), findsOneWidget);
    });
  });

  group('privacy', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      pageTest('draws no text while inactive on $platform', (tester) async {
        await pump(tester, platform: platform);
        expect(find.text('Telegram failed'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(Text), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        expect(find.byType(Text), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('Telegram failed'), findsOneWidget);
        // Coming back did not read again.
        expect(reads(), hasLength(1));
      });
    }

    pageTest('a desktop keeps drawing while inactive', (tester) async {
      await pump(tester, platform: TargetPlatform.macOS, width: 1000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Telegram failed'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    pageTest('the Android window is secure only while the page is up', (
      tester,
    ) async {
      await pump(tester, pushed: true);
      expect(secureCalls, [true]);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(secureCalls, [true, false]);
    });

    pageTest('App Lock covering drops the lines and unlocking reads again', (
      tester,
    ) async {
      await tester.runAsync(lock.load);
      await pump(tester, withLock: true);
      expect(find.text('Telegram failed'), findsOneWidget);
      // Lock: the app leaves the screen and App Lock is on.
      await tester.runAsync(() => lock.setEnabled(true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(lock.covered, isTrue);
      expect(find.text('Telegram failed'), findsNothing);
      expect(reads(), hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(lock.unlock);
      await tester.pumpAndSettle();
      expect(lock.covered, isFalse);
      expect(find.text('Telegram failed'), findsOneWidget);
      expect(reads(), hasLength(2));
    });

    pageTest('lines are not kept in preferences', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final keys = await tester.runAsync(SharedPreferencesAsync().getKeys);
      expect(keys, isEmpty);
    });
  });

  pageTest('a server without the route closes the page', (tester) async {
    server.on('GET', '/api/logs', {'detail': 'Not Found'}, status: 404);
    await pump(tester, pushed: true);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(care.offers(CarePart.logs), isFalse);
  });

  pageTest('a profile switch reads the new profile', (tester) async {
    await pump(tester);
    care.profileChanged('work');
    await tester.pumpAndSettle();
    expect(reads().last['profile'], 'work');
  });
}
