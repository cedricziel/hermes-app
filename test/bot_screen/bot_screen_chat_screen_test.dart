import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import 'bot_screen_repository_test.dart' show jpeg, statusJson;

/// The chat screen owning one Bot Screen controller for its profile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late _Lock lock;
  late ChatProfiles profiles;
  final running = <String, bool>{};

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  Iterable<Object?> profilesAsked(String method) => [
    for (final r in gateway.requests)
      if (r['method'] == method) (r['params'] as Map)['profile'],
  ];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    running
      ..clear()
      ..['default'] = true
      ..['work'] = false;
    lock = _Lock();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (params) => statusJson(
      running: running[params['profile']] ?? false,
      extra: {'profile': params['profile']},
    );
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First chat')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
        ]),
      );
    profiles = ChatProfiles(HermesProfilesRepository(server.client().raw));
  });

  tearDown(() async {
    profiles.dispose();
    lock.dispose();
    await transport.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    MacCommandRegistry? commands,
  }) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      commands: commands,
      providers: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
    );
    await openThread(tester, 'First chat');
    if (commands == null) {
      await tester.tap(find.byKey(const Key('header-activity')));
    } else {
      expect(commands.invoke(MacCommand.toggleInspector), isTrue);
    }
    await tester.pump();
    await settle(tester);
  }

  /// Ends a test with the inspector closed, which stops the polling.
  Future<void> finish(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  final card = find.byType(BotScreenCard);

  testWidgets('the open chat\'s profile screen is listed in the inspector', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(card, findsOne);
    expect(find.text('Hermes is in control'), findsOne);
    expect(find.byType(Image), findsWidgets);
    expect(profilesAsked('display.status').toSet(), {'default'});
    await finish(tester);
  });

  testWidgets('closing the inspector stops the frame requests', (tester) async {
    await pumpScreen(tester);
    final before = calls('display.thumbnail');
    expect(before, greaterThan(0));

    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);

    expect(card, findsNothing);
    expect(calls('display.thumbnail'), before);
    await finish(tester);
  });

  testWidgets('a non-resumed lifecycle stops the requests and drops the '
      'frame, resuming asks again', (tester) async {
    await pumpScreen(tester);
    final before = calls('display.thumbnail');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    expect(calls('display.thumbnail'), before);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    expect(find.byType(Image), findsWidgets);
    await finish(tester);
  });

  testWidgets('App Lock stops the requests and drops the frame', (
    tester,
  ) async {
    await pumpScreen(tester);
    final before = calls('display.thumbnail');

    lock.covered = true;
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    expect(calls('display.thumbnail'), before);

    lock.covered = false;
    await tester.pump();
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    await finish(tester);
  });

  testWidgets('a windowless Mac app stops the requests until a window is on '
      'screen again', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final commands = MacCommandRegistry();
    addTearDown(commands.dispose);
    await pumpScreen(tester, commands: commands);
    final before = calls('display.thumbnail');

    Future<void> windowless(bool value) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'hermes_app/app',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('windowless', value),
          ),
          (_) {},
        );

    await windowless(true);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    expect(calls('display.thumbnail'), before);

    await windowless(false);
    await tester.pump();
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    await finish(tester);
  });

  testWidgets('another profile shows that profile\'s own screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(card, findsOne);

    await tester.runAsync(() => profiles.switchTo('work'));
    await settle(tester);
    await openThread(tester, 'First chat', settle: false);
    await settle(tester);

    // The work profile has no screen running and its chat never used one.
    expect(card, findsNothing);
    expect(profilesAsked('display.status'), contains('work'));
    final workFrames = gateway.requests.where(
      (r) =>
          r['method'] == 'display.thumbnail' &&
          (r['params'] as Map)['profile'] == 'work',
    );
    expect(workFrames, isEmpty);

    await tester.runAsync(() => profiles.switchTo('default'));
    await settle(tester);
    await openThread(tester, 'First chat', settle: false);
    await settle(tester);
    expect(card, findsOne);
    await finish(tester);
  });
}

class _Lock extends AppLockController {
  var _covered = false;

  @override
  bool get covered => _covered;

  set covered(bool value) {
    _covered = value;
    notifyListeners();
  }
}
