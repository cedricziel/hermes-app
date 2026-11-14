import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/server_care/gateway_restart.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_check_controller.dart';
import 'package:hermes_app/src/server_care/server_check_page.dart';
import 'package:hermes_app/src/server_care/server_logs_page.dart';
import 'package:hermes_app/src/server_care/server_screen.dart';
import 'package:hermes_app/src/server_care/update_page.dart';
import 'package:hermes_app/src/server_care/usage_page.dart';
import 'package:hermes_app/src/server_care/widgets/server_split_view.dart';
import 'package:hermes_app/src/navigation/connection_pages.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

/// Counts the routes pushed, to tell a page beside the list from a pushed one.
class _Pushes extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

class _Auth extends AuthController {
  var _state = HermesConnectionState.ready;
  @override
  HermesConnectionState get state => _state;
  @override
  bool get protectedRequestsAllowed => true;

  void leave() {
    _state = HermesConnectionState.needsLogin;
    notifyListeners();
  }
}

/// The Server screen beside its pages on a wide window, and still pushing
/// them on a narrow one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late ServerCareController care;
  late GatewayRestart gateway;
  late ServerCheckController check;
  late HermesUpdateRun update;
  late AppLockController lock;
  final secureCalls = <Object?>[];
  late _Pushes pushes;
  late BreadcrumbTrail trail;
  const secureChannel = MethodChannel('hermes_app/secure_window');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    secureCalls.clear();
    pushes = _Pushes();
    trail = BreadcrumbTrail();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          secureCalls.add(call.arguments);
          return null;
        });
    server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on('GET', '/api/hermes/update/check', {
        ...updateCheckBehind(),
        'behind': 0,
        'update_available': false,
      })
      ..on('GET', '/api/analytics/usage', usage30(today: DateTime.now()))
      ..on('GET', '/api/logs', {'file': 'errors', 'lines': logsErrors});
    lock = AppLockController(
      authenticator: FakeDeviceAuthenticator(),
      coverWhenInactive: true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    lock.dispose();
  });

  /// Opens the screen the way the shell does, on a route above the providers.
  Future<void> pump(
    WidgetTester tester, {
    double width = 1000,
    TargetPlatform platform = TargetPlatform.android,
    _Auth? auth,
    double height = 1600,
    double textScale = 1,
    ValueNotifier<int>? stack,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repositories = HermesRepositories(server.client());
    care = ServerCareController(
      repository: repositories.serverCare,
      profile: 'default',
    );
    addTearDown(care.dispose);
    gateway = GatewayRestart(repository: repositories.serverCare, care: care);
    addTearDown(gateway.dispose);
    update = HermesUpdateRun(repository: repositories.serverCare);
    addTearDown(update.dispose);
    check = ServerCheckController(
      repository: repositories.serverCare,
      delay: (d) async {},
      onUnsupported: () => care.reportUnsupported(CarePart.check),
    );
    addTearDown(check.dispose);
    // As in the app: every page above the home route goes when the
    // connection ends (navigation/connection_pages.dart).
    final pushedRoutes = PushedRoutes();
    if (auth != null) {
      final closer = ConnectionPageCloser(pushedRoutes)..bind(auth);
      addTearDown(closer.dispose);
    }
    await tester.runAsync(lock.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(value: repositories),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          ChangeNotifierProvider<ServerCareController>.value(value: care),
          ChangeNotifierProvider<GatewayRestart>.value(value: gateway),
          ChangeNotifierProvider<HermesUpdateRun>.value(value: update),
          ChangeNotifierProvider<ServerCheckController>.value(value: check),
          ChangeNotifierProvider<AppLockController>.value(value: lock),
          if (auth != null)
            ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(
          navigatorObservers: [pushes, pushedRoutes],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          // As the Mac shell keeps it: a destination kept alive behind another.
          home: stack != null
              ? ValueListenableBuilder<int>(
                  valueListenable: stack,
                  builder: (context, index, _) => Scaffold(
                    body: IndexedStack(
                      index: index,
                      children: const [
                        ServerScreen(source: 'test'),
                        SizedBox.expand(),
                      ],
                    ),
                  ),
                )
              : Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          showServerScreen(context, source: 'test'),
                      child: const Text('open'),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (stack == null) await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  void test(String name, Future<void> Function(WidgetTester tester) body) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String row) async {
    await tester.tap(
      find.descendant(of: find.byType(GroupedRow), matching: find.text(row)),
    );
    await settle(tester);
  }

  group('on a wide window', () {
    test('shows the overview beside the Usage page by default', (tester) async {
      await pump(tester);
      expect(find.byType(ServerSplitView), findsOneWidget);
      expect(find.text('Everything looks good'), findsOneWidget);
      expect(find.byType(UsagePage), findsOneWidget);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(find.byType(UpdatePage), findsNothing);
      // The list is 340 wide, the page takes the rest.
      expect(tester.getSize(find.byType(ServerSplitView).first).width, 1000);
      expect(tester.getTopRight(find.text('Server').first).dx, lessThan(340));
      expect(tester.getTopLeft(find.byType(UsagePage)).dx, 341);
    });

    test('has one Back, for the list; the page beside it has none', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(AdaptiveBackButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AdaptiveBackButton)).dx,
        lessThan(340),
      );
    });

    test('the selected row is highlighted and announced as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      bool selected(String row) =>
          tester
              .getSemantics(find.widgetWithText(GroupedRow, row))
              .getSemanticsData()
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(selected('Usage'), isTrue);
      expect(selected('Logs'), isFalse);
      await select(tester, 'Logs');
      expect(selected('Usage'), isFalse);
      expect(selected('Logs'), isTrue);
      handle.dispose();
    });

    test('selecting a row swaps the page and pushes no route', (tester) async {
      await pump(tester);
      final before = pushes.count;
      await select(tester, 'Logs');
      expect(find.byType(ServerLogsPage), findsOneWidget);
      expect(find.byType(UsagePage), findsNothing);
      expect(find.text('Telegram failed'), findsOneWidget);
      expect(server.requestsTo('GET', '/api/logs').single.queryParameters, {
        'file': 'errors',
        'lines': 200,
        'profile': 'default',
      });
      await select(tester, 'Updates');
      expect(find.byType(UpdatePage), findsOneWidget);
      expect(find.text('Hermes is up to date'), findsOneWidget);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(pushes.count, before);
    });

    test('tapping the row of the page on screen keeps that page', (
      tester,
    ) async {
      await pump(tester);
      await select(tester, 'Logs');
      final state = tester.state(find.byType(ServerLogsPage));
      await select(tester, 'Logs');
      expect(tester.state(find.byType(ServerLogsPage)), same(state));
      expect(server.requestsTo('GET', '/api/logs'), hasLength(1));
    });

    test('the selection survives a refresh', (tester) async {
      await pump(tester);
      await select(tester, 'Logs');
      final state = tester.state(find.byType(ServerLogsPage));
      await tester.tap(find.byKey(const Key('server-refresh')));
      await settle(tester);
      expect(tester.state(find.byType(ServerLogsPage)), same(state));
      expect(find.text('Telegram failed'), findsOneWidget);
      expect(secureCalls, [true]);
    });

    test('leaving Logs releases the secure window and drops its lines', (
      tester,
    ) async {
      await pump(tester);
      await select(tester, 'Logs');
      expect(secureCalls, [true]);
      await select(tester, 'Usage');
      expect(secureCalls, [true, false]);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(find.text('Telegram failed'), findsNothing);
      // Coming back reads again: nothing was kept.
      await select(tester, 'Logs');
      expect(server.requestsTo('GET', '/api/logs'), hasLength(2));
      expect(secureCalls, [true, false, true]);
    });

    test('closing the screen releases the secure window', (tester) async {
      await pump(tester);
      await select(tester, 'Logs');
      Navigator.of(tester.element(find.byType(ServerScreen))).pop();
      await tester.pumpAndSettle();
      expect(secureCalls, [true, false]);
    });

    test('the end of the connection removes the screen and its Logs', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.dispose);
      await pump(tester, auth: auth);
      await select(tester, 'Logs');
      expect(find.text('Telegram failed'), findsOneWidget);
      auth.leave();
      await tester.pumpAndSettle();
      expect(find.byType(ServerScreen), findsNothing);
      expect(find.text('Telegram failed'), findsNothing);
      expect(secureCalls, [true, false]);
    });

    test('App Lock covering drops the lines of the Logs page', (tester) async {
      await pump(tester);
      await select(tester, 'Logs');
      await tester.runAsync(() => lock.setEnabled(true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(lock.covered, isTrue);
      expect(find.text('Telegram failed'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(lock.unlock);
      await settle(tester);
      expect(find.text('Telegram failed'), findsOneWidget);
      // The page reads again after unlocking, as it always did, and holds the
      // window throughout.
      expect(server.requestsTo('GET', '/api/logs'), hasLength(2));
      expect(secureCalls, [true]);
    });

    test('a page for a part the server lacks gives way to the next one', (
      tester,
    ) async {
      server.on('GET', '/api/analytics/usage', {
        'detail': 'Not Found',
      }, status: 404);
      await pump(tester);
      // Usage found out it has no route: the row goes and Updates shows.
      expect(find.byType(UsagePage), findsNothing);
      expect(find.byType(UpdatePage), findsOneWidget);
      expect(find.byType(ServerScreen), findsOneWidget);
      expect(find.text('Usage'), findsNothing);
    });

    test('says so when the server has no page to offer', (tester) async {
      server
        ..on('GET', '/api/analytics/usage', null, status: 404)
        ..on('GET', '/api/logs', null, status: 404)
        ..on('GET', '/api/hermes/update/check', null, status: 404);
      await pump(tester);
      await settle(tester);
      expect(
        find.text('Nothing more to show for this server.'),
        findsOneWidget,
      );
      expect(find.byType(ServerScreen), findsOneWidget);
    });

    test('never opens Logs by itself, even when it is all the server has', (
      tester,
    ) async {
      server
        ..on('GET', '/api/analytics/usage', null, status: 404)
        ..on('GET', '/api/hermes/update/check', null, status: 404);
      await pump(tester);
      await settle(tester);
      expect(
        find.text('Nothing more to show for this server.'),
        findsOneWidget,
      );
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(server.requestsTo('GET', '/api/logs'), isEmpty);
      expect(secureCalls, isEmpty);
      // The row is still there for the person to pick.
      await select(tester, 'Logs');
      expect(find.byType(ServerLogsPage), findsOneWidget);
      expect(secureCalls, [true]);
    });

    test('a picked Logs page that the server stops offering never gives way '
        'to Logs, only to the empty state', (tester) async {
      server
        ..on('GET', '/api/analytics/usage', null, status: 404)
        ..on('GET', '/api/hermes/update/check', null, status: 404);
      await pump(tester);
      await select(tester, 'Logs');
      care.reportUnsupported(CarePart.logs);
      await settle(tester);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(secureCalls, [true, false]);
    });

    test('a destination kept alive behind another builds no page', (
      tester,
    ) async {
      final stack = ValueNotifier<int>(0);
      addTearDown(stack.dispose);
      await pump(tester, stack: stack);
      await select(tester, 'Logs');
      expect(find.byType(ServerLogsPage), findsOneWidget);
      expect(secureCalls, [true]);
      stack.value = 1;
      await settle(tester);
      expect(find.byType(ServerLogsPage, skipOffstage: false), findsNothing);
      expect(find.text('Telegram failed', skipOffstage: false), findsNothing);
      expect(secureCalls, [true, false]);
      stack.value = 0;
      await settle(tester);
      // The pane was torn down for real: showing it again does not read the
      // logs by itself, it lands on the default.
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(find.byType(UsagePage), findsOneWidget);
      expect(server.requestsTo('GET', '/api/logs'), hasLength(1));
      expect(secureCalls, [true, false]);
    });

    test('a failed status read hides the version the Update page falls back '
        'to', (tester) async {
      server.on('GET', '/api/hermes/update/check', {
        ...updateCheckBehind(),
        'current_version': null,
        'behind': 0,
        'update_available': false,
      });
      await pump(tester);
      await select(tester, 'Updates');
      expect(
        find.descendant(
          of: find.byType(UpdatePage),
          matching: find.textContaining('0.22.2'),
        ),
        findsOneWidget,
      );
      server.on('GET', '/api/status', {}, status: 500);
      await tester.runAsync(care.refresh);
      await settle(tester);
      expect(care.failure, isNotNull);
      expect(find.byType(UpdatePage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(UpdatePage),
          matching: find.textContaining('0.22.2'),
        ),
        findsNothing,
      );
    });

    group('server check', () {
      const header = '=== doctor started 2026-11-14 09:00:00 ===';

      void checkAnswers() => server
        ..on('POST', '/api/ops/doctor', {
          'ok': true,
          'pid': 1,
          'name': 'doctor',
        })
        ..on('GET', '/api/actions/doctor/status', {
          'name': 'doctor',
          'running': false,
          'exit_code': 1,
          'lines': [header, ...doctorProblems],
        });

      void storeUnreadable() => server.on('GET', '/api/status', {
        ...statusHealthy(),
        'components': {
          'gateway': {'status': 'ok', 'state': 'running'},
          'storage': {'status': 'error', 'reason': 'corrupt'},
        },
      });

      int runs() => server.requestsTo('POST', '/api/ops/doctor').length;

      test('the row selects the page beside the list and runs nothing', (
        tester,
      ) async {
        checkAnswers();
        await pump(tester);
        expect(find.byType(ServerCheckPage), findsNothing);
        final before = pushes.count;
        await select(tester, 'Run a check');
        expect(find.byType(ServerCheckPage), findsOneWidget);
        expect(find.byType(UsagePage), findsNothing);
        expect(pushes.count, before);
        expect(runs(), 0);
        expect(secureCalls, [true]);
        expect(find.byType(AdaptiveBackButton), findsOneWidget);
      });

      test('switching away releases the secure window', (tester) async {
        checkAnswers();
        await pump(tester);
        await select(tester, 'Run a check');
        expect(secureCalls, [true]);
        await select(tester, 'Logs');
        expect(find.byType(ServerCheckPage), findsNothing);
        // Logs holds it before Check lets go, so it never opens in between.
        expect(secureCalls, [true]);
        await select(tester, 'Usage');
        expect(secureCalls, [true, false]);
      });

      test('is never the default, even when it is all the server has', (
        tester,
      ) async {
        server
          ..on('GET', '/api/analytics/usage', null, status: 404)
          ..on('GET', '/api/hermes/update/check', null, status: 404);
        checkAnswers();
        await pump(tester);
        await settle(tester);
        expect(
          find.text('Nothing more to show for this server.'),
          findsOneWidget,
        );
        expect(find.byType(ServerCheckPage), findsNothing);
        expect(runs(), 0);
        expect(secureCalls, isEmpty);
      });

      test("the headline's Run a check selects it and starts a run", (
        tester,
      ) async {
        checkAnswers();
        storeUnreadable();
        await pump(tester);
        final before = pushes.count;
        await tester.tap(find.widgetWithText(FilledButton, 'Run a check'));
        await settle(tester);
        expect(find.byType(ServerCheckPage), findsOneWidget);
        expect(runs(), 1);
        expect(pushes.count, before);
        expect(find.text('Telegram token rejected (401)'), findsOneWidget);
      });

      test('a Usage page in the pane offers Run a check', (tester) async {
        checkAnswers();
        storeUnreadable();
        server.on('GET', '/api/analytics/usage', null, status: 503);
        await pump(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(UsagePage),
            matching: find.widgetWithText(FilledButton, 'Run a check'),
          ),
        );
        await settle(tester);
        expect(find.byType(ServerCheckPage), findsOneWidget);
        expect(runs(), 1);
      });

      test('a missing route empties the pane instead of popping the screen', (
        tester,
      ) async {
        checkAnswers();
        await pump(tester);
        await select(tester, 'Run a check');
        care.reportUnsupported(CarePart.check);
        await settle(tester);
        expect(find.byType(ServerCheckPage), findsNothing);
        expect(find.byType(ServerScreen), findsOneWidget);
        expect(find.byType(UsagePage), findsOneWidget);
        expect(secureCalls, [true, false]);
      });

      test('hidden behind another destination it is dropped, and shown '
          'again it does not run a second check', (tester) async {
        checkAnswers();
        storeUnreadable();
        final stack = ValueNotifier<int>(0);
        addTearDown(stack.dispose);
        await pump(tester, stack: stack);
        await tester.tap(find.widgetWithText(FilledButton, 'Run a check'));
        await settle(tester);
        expect(runs(), 1);
        expect(secureCalls, [true]);
        stack.value = 1;
        await settle(tester);
        expect(find.byType(ServerCheckPage, skipOffstage: false), findsNothing);
        expect(secureCalls, [true, false]);
        stack.value = 0;
        await settle(tester);
        expect(find.byType(ServerCheckPage), findsNothing);
        expect(find.byType(UsagePage), findsOneWidget);
        expect(secureCalls, [true, false]);
        expect(runs(), 1);
      });
    });

    test('an iPad counts as wide from 700 points', (tester) async {
      tester.view.physicalSize = const Size(744, 1133);
      await pump(
        tester,
        width: 744,
        height: 1133,
        platform: TargetPlatform.iOS,
      );
      expect(find.byType(ServerSplitView), findsOneWidget);
      expect(find.byType(UsagePage), findsOneWidget);
    });

    test('at the largest text the panes still hold', (tester) async {
      await pump(tester, textScale: 2, height: 4000);
      expect(tester.takeException(), isNull);
      await select(tester, 'Logs');
      expect(tester.takeException(), isNull);
    });

    test('the Mac never splits: pages push with the toolbar Back', (
      tester,
    ) async {
      for (final width in [1000.0, 1500.0]) {
        await pump(tester, platform: TargetPlatform.macOS, width: width);
        expect(find.byType(ServerSplitView), findsNothing);
        expect(find.byType(UsagePage), findsNothing);
        final before = pushes.count;
        await select(tester, 'Logs');
        expect(find.byType(ServerLogsPage), findsOneWidget);
        expect(pushes.count, before + 1);
        Navigator.of(tester.element(find.byType(ServerLogsPage))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('on a narrow window', () {
    test('a page still pushes and the list stays whole', (tester) async {
      await pump(tester, width: 420);
      expect(find.byType(ServerSplitView), findsNothing);
      expect(find.byType(UsagePage), findsNothing);
      final before = pushes.count;
      await select(tester, 'Logs');
      expect(find.byType(ServerLogsPage), findsOneWidget);
      expect(pushes.count, before + 1);
      expect(find.byType(AdaptiveBackButton), findsOneWidget);
    });

    test('an iPad in Split View is narrow', (tester) async {
      await pump(tester, width: 600, platform: TargetPlatform.iOS);
      expect(find.byType(ServerSplitView), findsNothing);
    });
  });

  group('a kept pick', () {
    int logReads() => server.requestsTo('GET', '/api/logs').length;

    Future<void> resize(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpAndSettle();
      await settle(tester);
    }

    test('a route pushed over the screen keeps the pane page as it was', (
      tester,
    ) async {
      await pump(tester);
      await select(tester, 'Logs');
      final state = tester.state(find.byType(ServerLogsPage));
      final navigator = Navigator.of(tester.element(find.byType(ServerScreen)));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('over it')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('over it'), findsOneWidget);
      navigator.pop();
      await settle(tester);
      expect(tester.state(find.byType(ServerLogsPage)), same(state));
      expect(logReads(), 1);
      expect(secureCalls, [true]);
    });

    test('narrowing drops a Logs pick, widening lands on the default', (
      tester,
    ) async {
      await pump(tester);
      await select(tester, 'Logs');
      await resize(tester, 420);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(secureCalls, [true, false]);
      await resize(tester, 1000);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(find.byType(UsagePage), findsOneWidget);
      expect(logReads(), 1);
      expect(secureCalls, [true, false]);
    });

    test('narrowing keeps an Update pick for when the window widens', (
      tester,
    ) async {
      await pump(tester);
      await select(tester, 'Updates');
      await resize(tester, 420);
      expect(find.byType(UpdatePage), findsNothing);
      await resize(tester, 1000);
      expect(find.byType(UpdatePage), findsOneWidget);
    });

    test('a Check pick is forgotten too, with no second check', (tester) async {
      server
        ..on('POST', '/api/ops/doctor', {
          'ok': true,
          'pid': 1,
          'name': 'doctor',
        })
        ..on('GET', '/api/actions/doctor/status', {
          'name': 'doctor',
          'running': false,
          'exit_code': 1,
          'lines': [
            '=== doctor started 2026-11-14 09:00:00 ===',
            ...doctorProblems,
          ],
        });
      await pump(tester);
      await select(tester, 'Run a check');
      check.run(profile: 'default').ignore();
      await settle(tester);
      for (final width in [420.0, 1000.0, 420.0, 1000.0]) {
        await resize(tester, width);
      }
      expect(find.byType(ServerCheckPage), findsNothing);
      expect(server.requestsTo('POST', '/api/ops/doctor'), hasLength(1));
      expect(secureCalls, [true, false]);
    });

    test('a pick does not come back on another profile', (tester) async {
      await pump(tester);
      await select(tester, 'Logs');
      expect(logReads(), 1);
      care.profileChanged('work');
      await settle(tester);
      expect(find.byType(ServerLogsPage), findsNothing);
      expect(find.byType(UsagePage), findsOneWidget);
      await resize(tester, 420);
      await resize(tester, 1000);
      await tester.runAsync(lock.load);
      await tester.runAsync(() => lock.setEnabled(true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(lock.unlock);
      await settle(tester);
      // The page followed the switch for the moment before the pane dropped
      // it; nothing was read for the old profile again, and nothing since.
      final reads = server
          .requestsTo('GET', '/api/logs')
          .map((r) => r.queryParameters['profile'])
          .toList();
      expect(reads.where((p) => p == 'default'), hasLength(1));
      expect(reads.length, lessThanOrEqualTo(2));
    });

    test('Usage records its opening once per pick', (tester) async {
      final stack = ValueNotifier<int>(0);
      addTearDown(stack.dispose);
      await pump(tester, stack: stack);
      int opened() => trail.recent
          .where((r) => r.name == 'server_care.usage.opened')
          .length;
      expect(opened(), 1);
      stack.value = 1;
      await settle(tester);
      stack.value = 0;
      await settle(tester);
      await resize(tester, 420);
      await resize(tester, 1000);
      expect(opened(), 1);
      // Another page and then Usage again is a new pick.
      await select(tester, 'Logs');
      await select(tester, 'Usage');
      expect(opened(), 2);
    });

    test('a Copy question closes with the Logs page', (tester) async {
      await pump(tester);
      await select(tester, 'Logs');
      await tester.tap(find.byKey(const Key('logs-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy shown lines'));
      await tester.pumpAndSettle();
      expect(find.text('Copy these log lines?'), findsOneWidget);
      await select(tester, 'Usage');
      expect(find.text('Copy these log lines?'), findsNothing);
      expect(find.byType(ServerScreen), findsOneWidget);
    });

    test('a restart, an update and a check that ran send nothing again '
        'when the window changes size', (tester) async {
      server
        ..on('POST', '/api/gateway/start', {
          'ok': true,
          'pid': 2,
          'name': 'gateway-start',
        })
        ..on('GET', '/api/actions/gateway-start/status', {
          'name': 'gateway-start',
          'running': false,
          'exit_code': 0,
          'lines': <String>[],
        })
        ..on('POST', '/api/hermes/update', {
          'ok': true,
          'pid': 1,
          'name': 'hermes-update',
          'action_id': 'a' * 32,
        })
        ..on('GET', '/api/actions/hermes-update/status', {
          'name': 'hermes-update',
          'running': false,
          'exit_code': 0,
          'lines': <String>[],
        })
        ..on('POST', '/api/ops/doctor', {
          'ok': true,
          'pid': 1,
          'name': 'doctor',
        })
        ..on('GET', '/api/actions/doctor/status', {
          'name': 'doctor',
          'running': false,
          'exit_code': 0,
          'lines': ['=== doctor started 2026-11-14 09:00:00 ==='],
        })
        ..on('GET', '/api/status', {
          ...statusHealthy(),
          'gateway_running': false,
          'gateway_state': 'stopped',
        });
      Future<void> quiet(WidgetTester tester) async {
        // An update that restarts animates for ever: settle by time.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      }

      await pump(tester);
      await tester.tap(find.text('Start gateway').first);
      // The gateway is up by the time its run reads the status again.
      server.on('GET', '/api/status', statusHealthy());
      await quiet(tester);
      update.start().ignore();
      await quiet(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(GroupedRow),
          matching: find.text('Run a check'),
        ),
      );
      await quiet(tester);
      check.run(profile: 'default').ignore();
      await quiet(tester);
      int posts(String path) => server.requestsTo('POST', path).length;
      expect(posts('/api/gateway/start'), 1);
      expect(posts('/api/hermes/update'), 1);
      expect(posts('/api/ops/doctor'), 1);
      for (final width in [420.0, 1000.0, 420.0, 1000.0]) {
        tester.view.physicalSize = Size(width, 1600);
        await quiet(tester);
      }
      expect(posts('/api/gateway/start'), 1);
      expect(posts('/api/hermes/update'), 1);
      expect(posts('/api/ops/doctor'), 1);
      update.reset().ignore();
      // The gateway waits up to 90 s for the status to say it is back.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
    });
  });
}
