import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/install/bot_screen_installs.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import 'bot_screen_repository_test.dart' show statusJson;

const _key = '/home/u/.hermes/profiles/work';
const _command = 'sudo apt-get install -y x';

/// Install on Server in the Activity panel, over a real chat controller, the
/// gateway transport and the app level installs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  late BotScreenInstalls installs;
  final controllers = <BotScreenController>[];
  var placement = 'gateway';
  String? installCommand = _command;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    placement = 'gateway';
    installCommand = _command;
    activity = ValueNotifier(true);
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) => statusJson(
      running: false,
      extra: {
        'installed': false,
        'placement': placement,
        'install_command': installCommand,
      },
    );
    gateway.handlers['display.install'] = (_) => {
      'started': true,
      'command': _command,
      'profile_key': _key,
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    installs = BotScreenInstalls(
      repository: BotScreenRepository(
        transport.requestKeepingConnection,
        installRpc: transport.requestKeepingConnectionOnClient,
      ),
      connectionEvents: transport.connectionEvents,
      registerServerRequestHandler: transport.registerServerRequestHandler,
      askPassword: (host, profile, ended) async => null,
      host: 'hermes.example.com',
    );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });

  tearDown(() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    installs.dispose();
    chat.dispose();
    attention.dispose();
    await transport.close();
    activity.dispose();
  });

  Future<void> loadChat() async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Open the browser'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'Done',
            toolCalls: [
              functionCall('computer_use', '{"action":"screenshot"}'),
            ],
          ),
        ]),
      );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      activity: activity,
      attention: attention,
      report: (_) {},
    );
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  /// A panel with a new controller, as a reopened panel or another chat has.
  Future<void> pumpPanel(WidgetTester tester, {bool open = true}) async {
    final screen = BotScreenController(
      BotScreenRepository(transport.requestKeepingConnection),
      transport.connectionEvents,
      profile: 'work',
      installs: installs,
    );
    controllers.add(screen);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: open
              ? ListenableBuilder(
                  listenable: chat,
                  builder: (context, _) => BoundActivityPanel(
                    chat: chat,
                    thread: chat.selectedThread,
                    screen: screen,
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
    await settle(tester);
  }

  /// Ends a test: the installs hold a timer that waits for a done broadcast.
  Future<void> finish(WidgetTester tester) async {
    installs.dispose();
    await tester.pumpWidget(const SizedBox());
  }

  final install = find.text('Install on Server');

  testWidgets('is offered on the gateway host with an install command, and '
      'starts the install', (tester) async {
    await tester.runAsync(loadChat);
    await pumpPanel(tester);

    expect(install, findsOne);
    await tester.tap(install);
    await settle(tester);

    expect(gateway.requestOf('display.install')['params'], {'profile': 'work'});
    expect(find.text('Installing the desktop on the server…'), findsOne);
    expect(install, findsNothing);

    gateway.event('display.install.log', '', {
      'profile_key': _key,
      'line': 'Reading package lists…',
    });
    await settle(tester);

    expect(find.text('Reading package lists…'), findsOne);
    await finish(tester);
  });

  testWidgets('is not offered without an install command', (tester) async {
    installCommand = null;
    await tester.runAsync(loadChat);
    await pumpPanel(tester);

    expect(find.byType(BotScreenCard), findsOne);
    expect(install, findsNothing);
    await finish(tester);
  });

  testWidgets('is not offered for a sandboxed profile, which keeps its '
      'sentence', (tester) async {
    placement = 'docker';
    await tester.runAsync(loadChat);
    await pumpPanel(tester);

    expect(find.textContaining('sandbox image'), findsOne);
    expect(install, findsNothing);
    await finish(tester);
  });

  testWidgets('closing the panel keeps the install, and the reopened panel '
      'shows it again', (tester) async {
    await tester.runAsync(loadChat);
    await pumpPanel(tester);
    await tester.tap(install);
    await settle(tester);

    await pumpPanel(tester, open: false);
    expect(find.byType(BotScreenCard), findsNothing);
    gateway.event('display.install.log', '', {
      'profile_key': _key,
      'line': 'Setting up xfce4',
    });
    await settle(tester);
    await pumpPanel(tester);

    expect(find.text('Installing the desktop on the server…'), findsOne);
    expect(find.text('Setting up xfce4'), findsOne);
    expect(find.text('You can close this; the install keeps going.'), findsOne);
    await finish(tester);
  });

  testWidgets('a refused install says so and offers it again', (tester) async {
    gateway.handlers['display.install'] = (_) =>
        throw const FakeRpcError(5300, 'an install is already running');
    await tester.runAsync(loadChat);
    await pumpPanel(tester);

    await tester.tap(install);
    await settle(tester);

    expect(find.text("Couldn't start the install."), findsOne);
    expect(find.text('an install is already running'), findsOne);
    expect(install, findsOne);
    await finish(tester);
  });

  testWidgets('done with 0 shows the screen as the status that came with it '
      'says', (tester) async {
    await tester.runAsync(loadChat);
    await pumpPanel(tester);
    await tester.tap(install);
    await settle(tester);

    gateway.event('display.install.done', '', {
      'profile_key': _key,
      'code': 0,
      'status': statusJson(running: false, extra: {'installed': true}),
    });
    await settle(tester);

    expect(find.text('Start Screen'), findsOne);
    await finish(tester);
  });
}
