import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/navigation/connection_pages.dart';
import 'package:hermes_app/src/server_care/gateway_restart.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/replies_in_progress.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_check_controller.dart';
import 'package:hermes_app/src/server_care/server_screen.dart';
import 'package:hermes_app/src/server_care/update_page.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

const _old = 'old1111';
const _fresh = 'new2222';

/// The Update page, opened from the Server screen, over a scripted server.
void main() {
  late FakeHermesServer server;
  late ServerCareController care;
  late HermesUpdateRun run;
  late RepliesInProgress replies;
  late DateTime clock;
  // Which part of the update the server is in: the child runs, the dashboard
  // is down, the dashboard is back on new code.
  var stage = 'running';

  Map<String, dynamic> health(String commit, String version) => {
    'ok': true,
    'version': version,
    'commit': commit,
    'auth_required': true,
  };

  Map<String, dynamic> actionStatus({required bool running}) => {
    'name': 'hermes-update',
    'running': running,
    'exit_code': running ? null : 0,
    'pid': 1,
    'lines': ['=== hermes-update started 2026-11-14 09:00:00 ===', 'pulling'],
  };

  setUp(() {
    stage = 'running';
    clock = DateTime(2026, 11, 14, 9);
    server = FakeHermesServer()
      ..on('GET', '/api/status', {...statusHealthy(), 'active_agents': 2})
      ..on('GET', '/api/hermes/update/check', updateCheckBehind())
      ..on('POST', '/api/hermes/update', updateStarted())
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess())
      ..onRequest('GET', '/api/health', (o) {
        if (stage == 'down') {
          throw DioException.connectionError(requestOptions: o, reason: 'down');
        }
        return (
          status: 200,
          body: stage == 'up'
              ? health(_fresh, '0.23.0')
              : health(_old, '0.22.2'),
        );
      })
      ..onRequest('GET', '/api/actions/hermes-update/status', (o) {
        if (stage == 'down') {
          throw DioException.connectionError(requestOptions: o, reason: 'down');
        }
        return (status: 200, body: actionStatus(running: stage == 'running'));
      });
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform? platform,
    int running = 0,
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repositories = HermesRepositories(server.client());
    care = ServerCareController(
      repository: repositories.serverCare,
      profile: 'default',
    );
    addTearDown(care.dispose);
    final gateway = GatewayRestart(repository: repositories.serverCare);
    addTearDown(gateway.dispose);
    final check = ServerCheckController(repository: repositories.serverCare);
    addTearDown(check.dispose);
    run = HermesUpdateRun(
      repository: repositories.serverCare,
      care: care,
      now: () => clock,
      // Time moves with the waits, and the test steps them with `pump`.
      delay: (d) {
        clock = clock.add(d);
        return Future<void>.delayed(d);
      },
    );
    addTearDown(run.dispose);
    replies = RepliesInProgress()..attach(() => running);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(value: repositories),
          Provider<RepliesInProgress>.value(value: replies),
          ChangeNotifierProvider<ServerCareController>.value(value: care),
          ChangeNotifierProvider<GatewayRestart>.value(value: gateway),
          ChangeNotifierProvider<ServerCheckController>.value(value: check),
          ChangeNotifierProvider<HermesUpdateRun>.value(value: run),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: const ServerScreen(source: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openUpdate(WidgetTester tester) async {
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> askAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Update Hermes'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppAlertDialog),
        matching: find.text('Update'),
      ),
    );
    await tester.pump();
  }

  /// Lets the run take [steps] polls of two seconds.
  Future<void> poll(WidgetTester tester, [int steps = 3]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
  }

  /// Ends a run that is still going, and lets its last wait run out.
  Future<void> stop(WidgetTester tester) async {
    await run.reset();
    await tester.pump(const Duration(seconds: 30));
  }

  int posts() => server.requestsTo('POST', '/api/hermes/update').length;

  group('the question', () {
    testWidgets('counts the replies in this app and the conversations on '
        'messaging channels, and sends nothing before the answer', (
      tester,
    ) async {
      await pump(tester, running: 1);
      await openUpdate(tester);
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      expect(find.text('Update Hermes now?'), findsOneWidget);
      expect(
        find.text('1 reply in this app is still running and will stop.'),
        findsOneWidget,
      );
      expect(
        find.text('2 conversations on messaging channels will stop.'),
        findsOneWidget,
      );
      expect(posts(), 0);
      expect(run.phase, UpdatePhase.confirming);
    });

    testWidgets('leaves out a line whose count is zero', (tester) async {
      server.on('GET', '/api/status', {...statusHealthy(), 'active_agents': 0});
      await pump(tester);
      await openUpdate(tester);
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('in this app'), findsNothing);
      expect(find.textContaining('messaging channels'), findsNothing);
      expect(
        find.textContaining("Chats pause until it's back"),
        findsOneWidget,
      );
    });

    testWidgets('Cancel sends nothing and goes back to the check', (
      tester,
    ) async {
      await pump(tester);
      await openUpdate(tester);
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(posts(), 0);
      expect(run.phase, UpdatePhase.idle);
      expect(find.text('Update Hermes'), findsOneWidget);
    });

    testWidgets('on Apple platforms Cancel is first and the default', (
      tester,
    ) async {
      await pump(tester, platform: TargetPlatform.iOS);
      await openUpdate(tester);
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      final actions = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .toList();
      expect((actions.first.child as Text).data, 'Cancel');
      expect(actions.first.isDefaultAction, isTrue);
      expect(actions.any((a) => a.isDestructiveAction), isFalse);
    });

    testWidgets('on Android there are two text buttons and none is filled', (
      tester,
    ) async {
      await pump(tester, platform: TargetPlatform.android);
      await openUpdate(tester);
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(FilledButton)),
        findsNothing,
      );
    });
  });

  group('progress', () {
    testWidgets('shows each step while the update runs, one POST', (
      tester,
    ) async {
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      await poll(tester, 1);
      expect(find.text('Starting the update'), findsOneWidget);
      expect(find.text('Downloading and installing'), findsOneWidget);
      expect(run.phase, UpdatePhase.updating);
      stage = 'down';
      await poll(tester);
      expect(run.phase, UpdatePhase.restarting);
      expect(find.text('Restarting Hermes'), findsOneWidget);
      expect(posts(), 1);
      // The row on the Server screen says so, too.
      await back(tester);
      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('Starting the update'), findsNothing);
      await stop(tester);
    });

    testWidgets('leaving and returning shows the current phase', (
      tester,
    ) async {
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      await poll(tester, 1);
      await back(tester);
      stage = 'down';
      await poll(tester);
      await tester.tap(find.text('Updating…'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Restarting Hermes'), findsOneWidget);
      expect(find.text('Update Hermes'), findsNothing);
      await stop(tester);
    });

    testWidgets('a success reads from the receipt and then Done goes back to '
        'the check', (tester) async {
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      stage = 'down';
      await poll(tester, 2);
      stage = 'up';
      await poll(tester, 4);
      await tester.pumpAndSettle();
      expect(run.result, UpdateResult.success);
      expect(find.text('Hermes is up to date'), findsOneWidget);
      expect(find.text('Now running 0.23.0.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(run.phase, UpdatePhase.idle);
      // The check was asked again, since what it knew is stale.
      expect(
        server
            .requestsTo('GET', '/api/hermes/update/check')
            .where((r) => r.queryParameters['force'].toString() == 'true'),
        isNotEmpty,
      );
    });

    testWidgets('a refusal shows Hermes\' message and the command, and sends '
        'no more', (tester) async {
      server.on('POST', '/api/hermes/update', updateRefused());
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      await tester.pumpAndSettle();
      expect(find.text('Update the container image instead.'), findsOneWidget);
      expect(find.text('docker compose pull'), findsOneWidget);
      expect(find.text('Downloading and installing'), findsNothing);
      expect(posts(), 1);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(run.phase, UpdatePhase.idle);
    });

    testWidgets('a refused sign-in on the update request says nothing was '
        'started and offers a way out', (tester) async {
      server.on('POST', '/api/hermes/update', {'detail': 'no'}, status: 401);
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining("so the update wasn't started"),
        findsOneWidget,
      );
      expect(find.textContaining('may still be going'), findsNothing);
      expect(find.text('Check again'), findsNothing);
      expect(posts(), 1);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(run.phase, UpdatePhase.idle);
    });

    testWidgets('Try again after a failure asks the question again', (
      tester,
    ) async {
      server
        ..on('GET', '/api/hermes/update/receipt', {
          'summary': {
            'outcome': 'failed',
            'action_id': 'a' * 32,
            'followups': <Object>[],
          },
        })
        ..onRequest('GET', '/api/actions/hermes-update/status', (_) {
          return (
            status: 200,
            body: {...actionStatus(running: false), 'exit_code': 1},
          );
        });
      await pump(tester);
      await openUpdate(tester);
      await askAndConfirm(tester);
      await poll(tester, 2);
      await tester.pumpAndSettle();
      expect(find.text("The update didn't finish"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Update Hermes now?'), findsOneWidget);
      expect(posts(), 1);
    });
  });

  group('pushed the way the app does it', () {
    /// The providers sit below the Navigator, as in `AppShell`: a pushed route
    /// only sees what the opener carries along.
    Future<void> pumpBelowNavigator(
      WidgetTester tester,
      Widget Function(BuildContext) opener, {
      AuthController? auth,
    }) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repositories = HermesRepositories(server.client());
      care = ServerCareController(
        repository: repositories.serverCare,
        profile: 'default',
      );
      addTearDown(care.dispose);
      final check = ServerCheckController(repository: repositories.serverCare);
      addTearDown(check.dispose);
      final gateway = GatewayRestart(repository: repositories.serverCare);
      addTearDown(gateway.dispose);
      run = HermesUpdateRun(repository: repositories.serverCare, care: care);
      addTearDown(run.dispose);
      replies = RepliesInProgress()..attach(() => 1);
      // As in the app: every page above the home route goes when the
      // connection ends (navigation/connection_pages.dart).
      final pushedRoutes = PushedRoutes();
      if (auth != null) {
        final closer = ConnectionPageCloser(pushedRoutes)..bind(auth);
        addTearDown(closer.dispose);
      }
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HermesRepositories>.value(value: repositories),
            if (auth != null)
              ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            navigatorObservers: [pushedRoutes],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(),
            home: MultiProvider(
              providers: [
                Provider<RepliesInProgress>.value(value: replies),
                ChangeNotifierProvider<ServerCareController>.value(value: care),
                ChangeNotifierProvider<GatewayRestart>.value(value: gateway),
                ChangeNotifierProvider<ServerCheckController>.value(
                  value: check,
                ),
                ChangeNotifierProvider<HermesUpdateRun>.value(value: run),
              ],
              child: Builder(builder: opener),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> expectReplyLine(WidgetTester tester) async {
      await tester.tap(find.text('Update Hermes'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 reply in this app is still running and will stop.'),
        findsOneWidget,
      );
    }

    testWidgets('showServerScreen carries the reply count to the page', (
      tester,
    ) async {
      await pumpBelowNavigator(
        tester,
        (context) => TextButton(
          onPressed: () => showServerScreen(context, source: 'test'),
          child: const Text('open server'),
        ),
      );
      await tester.tap(find.text('open server'));
      await tester.pumpAndSettle();
      await openUpdate(tester);
      await expectReplyLine(tester);
    });

    testWidgets('showUpdatePage carries it too, and never opens a second '
        'page', (tester) async {
      await pumpBelowNavigator(
        tester,
        (context) => TextButton(
          onPressed: () => showUpdatePage(context),
          child: const Text('open update'),
        ),
      );
      await tester.tap(find.text('open update'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdatePage), findsOneWidget);
      // The banner's tap while the page is open leaves it alone.
      final context = tester.element(find.byType(UpdatePage));
      await showUpdatePage(context);
      await tester.pumpAndSettle();
      expect(find.byType(UpdatePage, skipOffstage: false), findsOneWidget);
      await expectReplyLine(tester);
    });

    testWidgets('the page opened from the banner goes when the session ends, '
        'and the run stays the shell\'s', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final auth = _EndingAuth();
      addTearDown(auth.dispose);
      await pumpBelowNavigator(
        tester,
        (context) => TextButton(
          onPressed: () => showUpdatePage(context),
          child: const Text('open update'),
        ),
        auth: auth,
      );
      await tester.tap(find.text('open update'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdatePage), findsOneWidget);
      final phase = run.phase;
      auth.end();
      await tester.pumpAndSettle();
      expect(find.byType(UpdatePage, skipOffstage: false), findsNothing);
      expect(find.text('open update'), findsOneWidget);
      // The run is owned by the shell: the page leaving did not touch it.
      expect(run.phase, phase);
    });
  });
}

class _EndingAuth extends AuthController {
  var _state = HermesConnectionState.ready;

  @override
  HermesConnectionState get state => _state;

  void end() {
    _state = HermesConnectionState.needsLogin;
    notifyListeners();
  }
}
