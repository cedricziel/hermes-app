import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/skills/skill_editor_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';

void main() {
  late _Fixture h;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    HttpOverrides.global = null;
    h = await _Fixture.start();
  });

  testWidgets('bot handoff preserves a dirty editor until Save', (
    tester,
  ) async {
    await h.mount(tester);
    await h.edit(tester);

    await h.finish(tester, h.open(tester));

    expect(find.byType(SkillEditorScreen), findsOneWidget);
    expect(find.text('Unsaved skill'), findsOneWidget);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(h.selected(tester)?.id, 't1');
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillEditorScreen), findsOneWidget);
    await tester.tap(find.text('Save'));
    await h.wait(tester, () => h.selected(tester)?.id == 'bot-tip');
    await tester.pumpAndSettle();

    expect(find.byType(SkillEditorScreen), findsNothing);
    final context = h.selected(tester)!.botContext!;
    expect(context.bot.name, 'writer');
    expect(context.rootId, 'bot-root');
    expect(context.storedId, 'bot-tip');
    expect(context.peers.single.name, 'writer');
    expect(context.protocolEnabled, isTrue);
    expect(h.methods.where((method) => method == 'prompt.submit'), isEmpty);
  });

  testWidgets('departure during bot roster lookup starts no canonical lookup', (
    tester,
  ) async {
    await h.mount(tester);
    h.rosterGate = Completer<void>();
    final opening = h.open(tester);
    await h.wait(tester, () => h.rosterHeld);

    h.auth.retire();
    h.rosterGate!.complete();
    await h.finish(tester, opening);

    expect(h.methods.where((method) => method == 'session.list'), isEmpty);
    expect(h.selected(tester)?.id, 't1');
    expect(
      find.text('Could not open the bot chat. Retry from Bots.'),
      findsNothing,
    );
  });

  testWidgets('a newer notification supersedes a held bot lookup', (
    tester,
  ) async {
    await h.mount(tester);
    await h.edit(tester);
    h.rosterGate = Completer<void>();
    final opening = h.open(tester);
    await h.wait(tester, () => h.rosterHeld);

    h.notifications.tap('t2');
    await tester.pumpAndSettle();
    h.rosterGate!.complete();
    await h.finish(tester, opening);
    expect(find.byType(SkillEditorScreen), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await h.wait(tester, () => h.selected(tester)?.id == 't2');

    expect(h.selected(tester)?.botContext, isNull);
    expect(h.methods.where((method) => method == 'session.list'), isEmpty);
  });
}

class _Auth extends AuthController {
  _Auth(this.client, this.url);
  final HermesApiClient client;
  final String url;
  bool allowed = true;
  int generation = 0;
  @override
  HermesConnectionState get state => HermesConnectionState.ready;
  @override
  bool get protectedRequestsAllowed => allowed;
  @override
  int get ownerGeneration => generation;
  @override
  HermesApiClient get api => client;
  @override
  String get baseUrl => url;
  void retire() {
    allowed = false;
    generation++;
    notifyListeners();
  }
}

class _Fixture {
  _Fixture(this.listener) {
    final api = server.client();
    auth = _Auth(api, 'http://127.0.0.1:${listener.port}');
    server
      ..on('POST', '/api/auth/ws-ticket', {'ticket': 'fixture'})
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/model/options', {'providers': []})
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work'), profileRow(name: 'writer')]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 't1', title: 'First'),
          sessionRow(id: 't2', title: 'Second'),
          sessionRow(id: 'bot-tip', title: 'Bot Chat'),
        ]),
      );
    for (final id in ['t1', 't2', 'bot-tip']) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    listener.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((frame) async {
        final request = jsonDecode(frame as String) as Map<String, dynamic>;
        final method = request['method'] as String;
        methods.add(method);
        if (method == 'profiles.list' && rosterGate != null) {
          rosterHeld = true;
          await rosterGate!.future;
        }
        final params = request['params'] as Map<String, dynamic>;
        final result = switch (method) {
          'profiles.list' => {
            'bot_mode_protocol': true,
            'profiles': [
              {
                'name': 'writer',
                'ui_meta_revisions': {'hermes-bots': 1},
                'ui_meta': {
                  'hermes-bots': {'title': 'Writer'},
                },
                'canonical_session': {'id': 'bot-root'},
              },
            ],
          },
          'session.list' => {
            'sessions': [
              {'id': 'bot-root', 'resolved_id': 'bot-tip', 'title': 'Bot Chat'},
            ],
          },
          'session.resume' => {
            'session_id': params['session_id'],
            'stored_session_id': params['session_id'],
            'running': false,
          },
          'session.active_list' => {'sessions': []},
          'client.capabilities' => {'server_requests': []},
          'commands.catalog' => {'commands': []},
          _ => <String, Object?>{},
        };
        if (!_closing && socket.readyState == WebSocket.open) {
          socket.add(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': request['id'],
              'result': result,
            }),
          );
        }
      });
    });
  }

  static Future<_Fixture> start() async =>
      _Fixture(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  final HttpServer listener;
  final server = FakeHermesServer();
  final notifications = FakeNotificationService();
  final sockets = <WebSocket>[];
  final methods = <String>[];
  late final _Auth auth;
  Completer<void>? rosterGate;
  bool rosterHeld = false;
  bool _closing = false;

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      _closing = true;
      if (rosterGate?.isCompleted == false) rosterGate!.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future.wait(sockets.map((socket) => socket.close()));
        await listener.close(force: true);
      });
      auth.dispose();
      await notifications.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(auth.client),
          ),
          Provider<NotificationService>.value(value: notifications),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.linux),
          home: const AppShell(),
        ),
      ),
    );
    await wait(
      tester,
      () => find.byKey(const ValueKey('thread-t1')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await wait(tester, () => selected(tester)?.id == 't1');
    await tester.tap(
      find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text('Bots'),
      ),
    );
    await wait(tester, () => find.text('Writer').evaluate().isNotEmpty);
  }

  Future<void> edit(WidgetTester tester) async {
    unawaited(
      Navigator.of(tester.element(find.byType(AppShell))).push<void>(
        MaterialPageRoute(
          builder: (_) => SkillEditorScreen.edit(
            name: 'example',
            initialText: 'Original skill',
            onSave: (_, _, _) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved skill');
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) {
    final screen = tester.widget<BotModeRosterScreen>(
      find.byType(BotModeRosterScreen, skipOffstage: false),
    );
    return (screen.onOpen! as Future<void> Function(BotModeBot))(
      BotModeBot(serverId: auth.url, name: 'writer', revision: 1),
    );
  }

  ChatThread? selected(WidgetTester tester) => tester
      .widget<ChatThreadView>(find.byType(ChatThreadView, skipOffstage: false))
      .thread;

  Future<void> finish(WidgetTester tester, Future<void> future) async {
    var done = false;
    unawaited(future.whenComplete(() => done = true));
    await wait(tester, () => done);
    await tester.pumpAndSettle();
  }

  Future<void> wait(WidgetTester tester, bool Function() ready) async {
    for (var attempts = 0; attempts < 200 && !ready(); attempts++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ready(), isTrue, reason: 'The scripted gateway did not settle');
  }
}
