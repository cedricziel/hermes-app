import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/screens/login_screen.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/memory_token_store.dart';
import 'support/screenshot_recorder.dart';
import 'support/workflow_app.dart';

/// A gated dashboard on a loopback socket whose session a test can end: it
/// can reject the access token (a 401), refuse the refresh, or rotate the
/// pair, and it records every request it gets.
class _Dashboard {
  _Dashboard._(this._server);

  static Future<_Dashboard> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dashboard = _Dashboard._(server);
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  final requests = <String>[];
  String validAccess = 'access-1';
  bool refuseRefresh = false;
  int refreshes = 0;
  String updateStage = 'idle';

  String get url => 'http://127.0.0.1:${_server.port}';

  int count(String method, String path) =>
      requests.where((r) => r == '$method $path').length;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    final body = await utf8.decoder.bind(request).join();
    (int, Object?) answer() {
      switch (path) {
        case '/api/status':
          return (
            200,
            {
              'auth_required': true,
              'auth_flows': ['native_pkce'],
              'version': '0.22.2',
            },
          );
        case '/api/auth/providers':
          return (
            200,
            {
              'providers': [
                {'name': 'oidc', 'display_name': 'Company SSO'},
              ],
            },
          );
        case '/auth/native/refresh':
          if (refuseRefresh) return (401, {'detail': 'refresh failed'});
          refreshes++;
          validAccess = 'access-${refreshes + 1}';
          return (
            200,
            {
              'access_token': validAccess,
              'refresh_token': 'refresh-${refreshes + 1}',
              'expires_at': 4102444800,
              'user_id': 'u1',
              'provider': 'oidc',
            },
          );
      }
      final bearer = request.headers.value('authorization');
      if (bearer != 'Bearer $validAccess') {
        return (401, {'detail': 'expired'});
      }
      switch (path) {
        case '/api/auth/me':
          return (
            200,
            {
              'user_id': 'u1',
              'email': 'ada@example.com',
              'display_name': 'Ada',
              'org_id': 'acme',
              'provider': 'oidc',
            },
          );
        case '/api/profiles':
          return (200, profileListBody([profileRow(name: 'work')]));
        case '/api/profiles/active':
          return (200, activeProfileBody(active: 'work'));
        case '/api/sessions':
          return (200, sessionListBody([]));
        case '/api/hermes/update':
          return (
            200,
            {
              'ok': true,
              'pid': 1,
              'name': 'hermes-update',
              'action_id': 'a' * 32,
            },
          );
        case '/api/actions/hermes-update/status':
          return (
            200,
            {
              'name': 'hermes-update',
              'running': true,
              'exit_code': null,
              'lines': <String>[],
            },
          );
      }
      return (404, {'detail': 'Not Found'});
    }

    final (status, json) = answer();
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(json));
    await request.response.close();
    if (body.isEmpty) return;
  }
}

/// What a settings screen holds: a controller-like write sent through the
/// repository it was given, and a flag set when the page is disposed.
class _Probe {
  bool disposed = false;

  /// The page's own Save callback, taken while the page was on screen.
  late VoidCallback save;
  Future<Object?>? lastWrite;

  /// Makes the page push a route when its dialog resolves, like code that
  /// goes on after `await showDialog`.
  bool pushLate = false;
}

/// A store whose session another engine replaces with a newer pair of the
/// same account just as the expiry deletes the old one.
class _RescuingStore extends MemoryTokenStore {
  _RescuingStore(super.session);

  String? rescueWith;

  @override
  Future<bool> replace(HermesSession expected, HermesSession? next) {
    final rescue = rescueWith;
    if (rescue != null && next == null) {
      rescueWith = null;
      session = HermesSession(
        accessToken: rescue,
        refreshToken: 'refresh-rescued',
        expiresAt: 4102444800,
        provider: expected.provider,
        userId: expected.userId,
        serverUrl: expected.serverUrl,
        mintedAt: DateTime.now().millisecondsSinceEpoch + 60000,
      );
    }
    return super.replace(expected, next);
  }
}

class _StalePage extends StatefulWidget {
  const _StalePage(this.probe, this.repository);

  final _Probe probe;
  final HermesToolsRepository repository;

  @override
  State<_StalePage> createState() => _StalePageState();
}

class _StalePageState extends State<_StalePage> {
  void _save() {
    widget.probe.lastWrite = widget.repository.switchToolset(
      'web',
      enabled: true,
    );
  }

  @override
  void dispose() {
    widget.probe.disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(title: const Text('Stale settings page')),
      body: Column(
        children: [
          TextButton(onPressed: _save, child: const Text('Stale save')),
          TextButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              unawaited(
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    title: const Text('Stale dialog'),
                    content: PopupMenuButton<int>(
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 1, child: Text('Stale menu item')),
                      ],
                      child: const Text('Open stale menu'),
                    ),
                  ),
                ).then((_) {
                  if (!widget.probe.pushLate) return;
                  unawaited(
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Late route')),
                      ),
                    ),
                  );
                }),
              );
            },
            child: const Text('Open stale dialog'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late _Dashboard dashboard;
  late AuthController auth;
  late _RescuingStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = await _Dashboard.start();
    store = _RescuingStore(
      const HermesSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: 4102444800,
        provider: 'oidc',
        userId: 'u1',
      ),
    );
    auth = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      login: (baseUrl, {provider, httpClient, cancelled}) =>
          Completer<HermesSession>().future,
    );
  });

  tearDown(() async {
    await dashboard.close();
  });

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (done()) return;
    }
    throw TestFailure('condition never held');
  }

  NavigatorState rootNavigator(WidgetTester tester) =>
      Navigator.of(tester.element(find.byType(AppShell)), rootNavigator: true);

  /// Opens the shell, then a settings page, a dialog that cannot be dismissed
  /// and a popup menu above it: four routes on the root navigator.
  Future<_Probe> openStack(WidgetTester tester) async {
    await pumpWorkflowApp(
      tester,
      ScreenshotRecorder('connection-pages'),
      auth: auth,
    );
    await tester.runAsync(auth.bootstrap);
    await pumpUntil(tester, () => find.byType(AppShell).evaluate().isNotEmpty);
    final probe = _Probe();
    final repository = HermesRepositories.forAuth(
      auth,
      null,
    )!.tools.forProfile('work');
    final navigator = rootNavigator(tester);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => _StalePage(probe, repository)),
      ),
    );
    await tester.pumpAndSettle();
    probe.save = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Stale save'))
        .onPressed!;
    await tester.tap(find.text('Open stale dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open stale menu'));
    await tester.pumpAndSettle();
    expect(find.text('Stale menu item'), findsOneWidget);
    return probe;
  }

  void expectOnlyHome(WidgetTester tester, Finder home, _Probe probe) {
    expect(home, findsOneWidget);
    expect(find.text('Stale settings page', skipOffstage: false), findsNothing);
    expect(find.text('Stale dialog'), findsNothing);
    expect(find.text('Stale menu item'), findsNothing);
    expect(probe.disposed, isTrue, reason: 'the stale page was unmounted');
    expect(
      Navigator.of(tester.element(home), rootNavigator: true).canPop(),
      isFalse,
      reason: 'the home is the only route on the root navigator',
    );
  }

  /// Presses the page's Save and waits for its write to end.
  Future<void> press(WidgetTester tester, _Probe probe) async {
    await tester.runAsync(() async {
      probe.save();
      await probe.lastWrite;
    });
  }

  /// Presses the Save callback of the page that is already gone. This guards
  /// that the old Dio is the real stop for a late callback, not the closer.
  Future<void> expectLateWriteSendsNothing(_Probe probe) async {
    final before = dashboard.requests.length;
    probe.save();
    await probe.lastWrite;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      dashboard.requests.skip(before).where((r) => r.startsWith('PUT ')),
      isEmpty,
      reason: 'a late callback of the stale page reaches no server',
    );
  }

  testWidgets('signing out closes pushed pages, dialogs and menus', (
    tester,
  ) async {
    final probe = await openStack(tester);
    await tester.runAsync(auth.signOut);
    await pumpUntil(
      tester,
      () => find.byType(LoginScreen, skipOffstage: false).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    expectOnlyHome(
      tester,
      find.byType(LoginScreen, skipOffstage: false),
      probe,
    );
    await tester.runAsync(() => expectLateWriteSendsNothing(probe));
    await letSocketsIdle(tester);
  });

  testWidgets('changing the server closes pushed pages, dialogs and menus', (
    tester,
  ) async {
    final probe = await openStack(tester);
    await tester.runAsync(auth.changeServer);
    await pumpUntil(
      tester,
      () => find
          .byType(ServerSetupScreen, skipOffstage: false)
          .evaluate()
          .isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    expectOnlyHome(
      tester,
      find.byType(ServerSetupScreen, skipOffstage: false),
      probe,
    );
    await tester.runAsync(() => expectLateWriteSendsNothing(probe));
    await letSocketsIdle(tester);
  });

  testWidgets('an expired session closes pushed pages, dialogs and menus', (
    tester,
  ) async {
    final probe = await openStack(tester);
    dashboard
      ..validAccess = 'revoked'
      ..refuseRefresh = true;
    // The stale page's own write is what meets the 401.
    await press(tester, probe);
    await pumpUntil(
      tester,
      () => find.byType(LoginScreen, skipOffstage: false).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(auth.sessionExpired, isTrue);
    expectOnlyHome(
      tester,
      find.byType(LoginScreen, skipOffstage: false),
      probe,
    );
    await tester.runAsync(() => expectLateWriteSendsNothing(probe));
    await letSocketsIdle(tester);
  });

  testWidgets('a token refresh closes nothing (the refresh does not notify)', (
    tester,
  ) async {
    final probe = await openStack(tester);
    final shell = tester.state(find.byType(AppShell, skipOffstage: false));
    final generation = auth.ownerGeneration;
    // The access token is rejected once; the refresh mints a new pair.
    dashboard.validAccess = 'rotated-away';
    await press(tester, probe);
    await tester.pump(const Duration(seconds: 1));
    expect(dashboard.refreshes, 1);
    expect(auth.ownerGeneration, generation);
    expect(auth.state, HermesConnectionState.ready);
    expect(find.text('Stale menu item'), findsOneWidget);
    expect(find.text('Stale dialog'), findsOneWidget);
    expect(
      find.text('Stale settings page', skipOffstage: false),
      findsOneWidget,
    );
    expect(probe.disposed, isFalse);
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
    expect(
      tester.state(find.byType(AppShell, skipOffstage: false)),
      same(shell),
    );
    await letSocketsIdle(tester);
  });

  /// The one path that notifies while the state is ready and the account
  /// is the same: the session expires, then a newer pair of the account that
  /// another engine stored is found while the old one is deleted.
  Future<int> expireAndRescue(WidgetTester tester, _Probe probe) async {
    var notifications = 0;
    auth.addListener(() => notifications++);
    dashboard
      ..validAccess = 'revoked'
      ..refuseRefresh = true;
    store.rescueWith = 'access-rescued';
    await press(tester, probe);
    dashboard
      ..validAccess = 'access-rescued'
      ..refuseRefresh = false;
    await pumpUntil(tester, () => notifications >= 2);
    await tester.pump(const Duration(seconds: 1));
    return notifications;
  }

  testWidgets('an expiry the stored session rescues closes nothing', (
    tester,
  ) async {
    final probe = await openStack(tester);
    final shell = tester.state(find.byType(AppShell, skipOffstage: false));
    final generation = auth.ownerGeneration;
    final notifications = await expireAndRescue(tester, probe);
    expect(notifications, greaterThanOrEqualTo(2));
    expect(auth.state, HermesConnectionState.ready);
    expect(auth.sessionExpired, isFalse);
    expect(auth.ownerGeneration, generation);
    expect(find.text('Stale menu item'), findsOneWidget);
    expect(find.text('Stale dialog'), findsOneWidget);
    expect(
      find.text('Stale settings page', skipOffstage: false),
      findsOneWidget,
    );
    expect(probe.disposed, isFalse);
    expect(
      tester.state(find.byType(AppShell, skipOffstage: false)),
      same(shell),
      reason: 'an expiry that does not move the owner keeps the shell',
    );
    await letSocketsIdle(tester);
  });

  testWidgets('a running update survives an expiry the stored session '
      'rescues, with its page open', (tester) async {
    final probe = await openStack(tester);
    final run = tester
        .element(find.byType(ChatScreen, skipOffstage: false))
        .read<HermesUpdateRun>();
    run.start().ignore();
    await pumpUntil(tester, () => run.phase == UpdatePhase.updating);
    await expireAndRescue(tester, probe);
    // The run goes on by itself (this dashboard has no health route, so it
    // moves on to waiting for a restart); it is neither reset nor finished.
    expect(run.phase, isIn([UpdatePhase.updating, UpdatePhase.restarting]));
    expect(
      find.text('Stale settings page', skipOffstage: false),
      findsOneWidget,
    );
    await tester.runAsync(run.reset);
    await letSocketsIdle(tester);
  });

  testWidgets('a route pushed once a closed dialog resolved is closed too', (
    tester,
  ) async {
    final probe = await openStack(tester)
      ..pushLate = true;
    dashboard
      ..validAccess = 'revoked'
      ..refuseRefresh = true;
    await press(tester, probe);
    await pumpUntil(
      tester,
      () => find.byType(LoginScreen, skipOffstage: false).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Late route', skipOffstage: false), findsNothing);
    expectOnlyHome(
      tester,
      find.byType(LoginScreen, skipOffstage: false),
      probe,
    );
    await letSocketsIdle(tester);
  });
}
