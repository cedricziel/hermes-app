import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bot_screen/install/bot_screen_installs.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_share_inbox.dart';
import 'bot_screen_repository_test.dart' show statusJson;

const _key = '/home/u/.hermes/profiles/work';

/// An install the user started is hosted by the shell, so the password
/// question reaches them wherever they are in the app.
void main() {
  late FakeGateway gateway;
  late FakeHermesServer server;
  late BreadcrumbTrail trail;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) =>
        statusJson(extra: {'installed': false});
    gateway.handlers['display.install'] = (_) => {
      'started': true,
      'command': 'sudo apt-get install -y x',
      'profile_key': _key,
    };
    server = FakeHermesServer()
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'default', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First chat')]),
      );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<BotScreenInstalls> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(create: (_) => _Auth()),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox())..start(),
          ),
          Provider<HermesRepositories>.value(
            value: HermesRepositories(server.client()),
          ),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            cron: HermesCronRepository(server.client().raw),
            kanbanBuilder: (_) => const Center(child: Text('the board')),
            gatewayConnect: gateway.connect,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(ChatScreen)).read<BotScreenInstalls>();
  }

  Future<void> startInstall(
    WidgetTester tester,
    BotScreenInstalls installs,
  ) async {
    await tester.runAsync(() async {
      await installs.start('work', profileKey: _key);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  Future<void> sudo(WidgetTester tester, {String key = _key}) async {
    gateway.serverRequest('srq-1', 'display.install.sudo', '', {
      'profile_key': key,
    });
    await settle(tester);
  }

  Future<void> openBoard(WidgetTester tester) async {
    await tester.tap(find.text('Kanban'));
    await tester.pumpAndSettle();
    expect(find.text('the board'), findsOne);
  }

  Map<String, Object?> answer() =>
      gateway.responses.firstWhere((r) => r['id'] == 'srq-1');

  final prompt = find.text('Sudo password');

  testWidgets('the password question appears over another tab and answers '
      'once', (tester) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);
    await openBoard(tester);

    await sudo(tester);

    expect(prompt, findsOne);
    expect(find.text('the board'), findsOne);
    expect(find.textContaining('Hermes on hermes.example.com'), findsOne);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);

    await tester.enterText(find.byType(EditableText), 'hunter2');
    await tester.pump();
    await tester.tap(find.text('Install'));
    await settle(tester);

    expect(answer()['result'], {'value': 'hunter2'});
    expect(prompt, findsNothing);
    expect(find.text('hunter2'), findsNothing);
    expect([
      for (final c in trail.recent) '${c.name} ${c.attributes}',
    ], contains('bot_screen.install.password {outcome: answered}'));
    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'].join(),
      isNot(contains('hunter2')),
    );
  });

  testWidgets('Cancel answers an empty value', (tester) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);

    await sudo(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(answer()['result'], {'value': ''});
    expect([
      for (final c in trail.recent) '${c.name} ${c.attributes}',
    ], contains('bot_screen.install.password {outcome: cancelled}'));
  });

  testWidgets('dismissing the question answers an empty value', (tester) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);

    await sudo(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    expect(prompt, findsNothing);
    expect(answer()['result'], {'value': ''});
  });

  testWidgets('the question closes when the install ends first', (
    tester,
  ) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);
    await sudo(tester);
    expect(prompt, findsOne);

    gateway.event('display.install.done', '', {
      'profile_key': _key,
      'code': -1,
      'status': statusJson(extra: {'installed': false}),
    });
    await settle(tester);

    expect(prompt, findsNothing);
    expect(installs.stateFor('work'), isA<InstallEnded>());
  });

  testWidgets('a request for an install nobody started is refused and shows '
      'nothing', (tester) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);

    await sudo(tester, key: '/another/profile');

    expect(prompt, findsNothing);
    expect(answer()['error'], isNotNull);
  });

  testWidgets('a request after the install ended is refused at once', (
    tester,
  ) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);
    gateway.event('display.install.done', '', {
      'profile_key': _key,
      'code': 0,
      'status': statusJson(),
    });
    await settle(tester);

    await sudo(tester);

    expect(prompt, findsNothing);
    expect(answer()['error'], isNotNull);
  });

  testWidgets('the install is still known after the chat left the screen', (
    tester,
  ) async {
    final installs = await pumpShell(tester);
    await startInstall(tester, installs);
    expect(installs.stateFor('work'), isA<InstallRunning>());

    await openBoard(tester);

    expect(installs.stateFor('work'), isA<InstallRunning>());
  });

  testWidgets('every platform builds the question', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final installs = await pumpShell(tester);
      await startInstall(tester, installs);
      await sudo(tester);

      expect(prompt, findsOne);
      expect(find.byType(CupertinoTextField), findsOne);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}

class _Auth extends AuthController {
  @override
  HermesConnectionState get state => HermesConnectionState.ready;

  @override
  bool get protectedRequestsAllowed => true;

  @override
  String? get baseUrl => 'https://hermes.example.com:9119';
}
