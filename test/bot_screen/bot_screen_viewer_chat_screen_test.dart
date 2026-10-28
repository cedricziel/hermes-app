import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import 'bot_screen_repository_test.dart' show jpeg, statusJson;

/// The chat screen opening the live viewer from the Activity card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late _Lock lock;
  late ChatProfiles profiles;
  late List<FakeDisplayChannel> channels;
  late List<String> tickets;
  late BreadcrumbTrail trail;

  List<String> crumbs() => [
    for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
  ];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    lock = _Lock();
    channels = [];
    tickets = [];
    trail = BreadcrumbTrail(capacity: 200);
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (params) => statusJson(
      running: params['profile'] == 'default',
      extra: {'profile': params['profile']},
    );
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    };
    gateway.handlers['display.observe'] = (params) => {
      'ticket': 'ticket-${tickets.length + 1}',
      'path': '/api/display/ws',
      'viewer_id': 'viewer-1',
      ...statusJson(extra: {'profile': params['profile']}),
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
    Size? size,
    MacCommandRegistry? commands,
    ValueListenable<bool>? visible,
  }) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      size: size ?? const Size(1400, 900),
      commands: commands,
      visible: visible,
      displaySocketOpener: (path, ticket) async {
        tickets.add(ticket);
        final channel = FakeDisplayChannel();
        channels.add(channel);
        return channel;
      },
      providers: [
        ChangeNotifierProvider<AppLockController>.value(value: lock),
        Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
      ],
    );
    await openThread(tester, 'First chat');
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump();
    await settle(tester);
  }

  /// Frames for a while, for a screen that has a spinner and never settles.
  Future<void> pumpFor(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  /// The server's side of the handshake and one picture.
  Future<void> serve(WidgetTester tester) async {
    final channel = channels.last;
    for (final part in rfbHandshake(8, 4)) {
      channel.serverSend(part);
      await settle(tester);
    }
    channel.serverSend(
      rfbUpdate([
        rfbRawRect(0, 0, 8, 4, [200, 0, 0]),
      ]),
    );
    await settle(tester);
  }

  final enlarge = find.byTooltip('Enlarge screen');
  final viewer = find.byType(BotScreenViewerView);

  testWidgets('Enlarge is offered and opens the viewer over the window', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(enlarge, findsOne);
    await tester.tap(enlarge);
    await settle(tester);

    expect(viewer, findsOne);
    expect(find.byKey(const Key('bot-screen-viewer-overlay')), findsOne);
    expect(find.byKey(const Key('bot-screen-viewer-page')), findsNothing);
    expect(
      gateway.requests
          .where((r) => r['method'] == 'display.observe')
          .single['params'],
      {'profile': 'default'},
    );
    expect(tickets, ['ticket-1']);
    expect(
      crumbs(),
      contains('bot_screen.viewer.opened {surface: overlay, source: card}'),
    );
    await finish(tester);
  });

  testWidgets('tapping the card\'s picture opens the viewer too', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(BotScreenCard),
        matching: find.byType(Image),
      ),
    );
    await settle(tester);

    expect(viewer, findsOne);
    await finish(tester);
  });

  testWidgets('a phone width pushes a full-screen page', (tester) async {
    await pumpScreen(tester, size: const Size(390, 844));

    // The sheet is still sliding in.
    await tester.pumpAndSettle();
    await tester.tap(enlarge);
    await settle(tester);

    expect(find.byKey(const Key('bot-screen-viewer-page')), findsOne);
    expect(find.byKey(const Key('bot-screen-viewer-overlay')), findsNothing);
    expect(
      crumbs(),
      contains('bot_screen.viewer.opened {surface: page, source: card}'),
    );

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);

    expect(viewer, findsNothing);
    expect(channels.last.sentCloseCode, 1000);
    expect(crumbs(), contains('bot_screen.viewer.closed {surface: page}'));
    await finish(tester);
  });

  testWidgets('Close and Escape close the overlay and the stream', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    await tester.tap(find.byTooltip('Close (Esc)'));
    await settle(tester);
    expect(viewer, findsNothing);
    expect(channels.last.sentCloseCode, 1000);

    await tester.tap(enlarge);
    await settle(tester);
    expect(viewer, findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(viewer, findsNothing);
    expect(channels, hasLength(2));
    expect(channels.last.sentCloseCode, 1000);
    await finish(tester);
  });

  testWidgets('a tap or click on the picture sends no input', (tester) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    final picture = find.descendant(
      of: viewer,
      matching: find.bySemanticsLabel("Hermes's screen"),
    );
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.tap(
      picture.evaluate().isEmpty ? find.byType(InteractiveViewer) : picture,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center);
    await mouse.down(center);
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();

    final types = clientMessages(channels.last.sentBytes).map((m) => m.first);
    expect(types.toSet().difference({0, 2, 3}), isEmpty);
    await finish(tester);
  });

  testWidgets('the app leaving the foreground closes the stream and returning '
      'opens a new one', (tester) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);

    expect(channels.last.sentCloseCode, 1000);
    expect(viewer, findsOne);
    expect(channels, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(channels, hasLength(2));
    expect(tickets, ['ticket-1', 'ticket-2']);
    await finish(tester);
  });

  testWidgets('App Lock closes the stream', (tester) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    lock.covered = true;
    await settle(tester);
    expect(channels.last.sentCloseCode, 1000);

    lock.covered = false;
    await settle(tester);
    expect(channels, hasLength(2));
    await finish(tester);
  });

  testWidgets('switching the chat\'s profile closes the viewer', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    await tester.runAsync(() => profiles.switchTo('work'));
    await settle(tester);

    expect(viewer, findsNothing);
    expect(channels.last.sentCloseCode, 1000);
    await finish(tester);
  });

  testWidgets('leaving the chat screen closes the stream', (tester) async {
    await pumpScreen(tester);
    await tester.tap(enlarge);
    await settle(tester);
    await serve(tester);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);

    expect(channels.last.sentCloseCode, 1000);
    await tester.runAsync(transport.close);
  });
  group('as a route on the root navigator', () {
    testWidgets('a dialog pushed over the viewer is shown on top of it', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(enlarge);
      await settle(tester);

      unawaited(
        showDialog<void>(
          context: tester.element(viewer),
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      await pumpFor(tester);

      expect(find.text('Cancel').hitTestable(), findsOne);
      await tester.tap(find.text('Cancel'));
      await pumpFor(tester);
      expect(viewer, findsOne, reason: 'only the dialog went');
      await finish(tester);
    });

    testWidgets('Back closes the viewer and leaves the chat', (tester) async {
      await pumpScreen(tester);
      await tester.tap(enlarge);
      await settle(tester);
      await serve(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(viewer, findsNothing);
      expect(channels.last.sentCloseCode, 1000);
      expect(find.byKey(const Key('header-activity')), findsOne);
      await finish(tester);
    });

    testWidgets('the chat\'s menu commands act on nothing while it is open', (
      tester,
    ) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpScreen(tester, commands: commands);
      expect(commands.invoke(MacCommand.find), isTrue);
      await tester.tap(enlarge);
      await settle(tester);
      await pumpFor(tester);

      for (final command in [
        MacCommand.newChat,
        MacCommand.toggleInspector,
        MacCommand.find,
      ]) {
        expect(commands.invoke(command), isFalse, reason: '$command');
      }

      await tester.tap(find.byTooltip('Close (Esc)'));
      await settle(tester);
      await pumpFor(tester);
      expect(commands.invoke(MacCommand.newChat), isTrue);
      await finish(tester);
    });

    testWidgets('a landscape phone gets the page', (tester) async {
      await pumpScreen(tester, size: const Size(844, 390));
      await pumpFor(tester);
      await tester.ensureVisible(enlarge);
      await tester.pump();

      await tester.tap(enlarge, warnIfMissed: false);
      await settle(tester);

      expect(find.byKey(const Key('bot-screen-viewer-page')), findsOne);
      expect(find.byKey(const Key('bot-screen-viewer-overlay')), findsNothing);
      await finish(tester);
    });

    testWidgets('a tablet gets the layer over the window', (tester) async {
      await pumpScreen(tester, size: const Size(800, 1100));
      await tester.pumpAndSettle();
      await tester.tap(enlarge);
      await settle(tester);

      expect(find.byKey(const Key('bot-screen-viewer-overlay')), findsOne);
      expect(find.byKey(const Key('bot-screen-viewer-page')), findsNothing);
      await finish(tester);
    });

    testWidgets('Escape closes the page too', (tester) async {
      await pumpScreen(tester, size: const Size(390, 844));
      await pumpFor(tester);
      await tester.tap(enlarge);
      await settle(tester);
      expect(find.byKey(const Key('bot-screen-viewer-page')), findsOne);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      expect(viewer, findsNothing);
      expect(channels.last.sentCloseCode, 1000);
      await finish(tester);
    });
  });

  group('when the stream stops for not being seen', () {
    testWidgets('a desktop window that is merely inactive keeps its stream', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpScreen(tester);
      await tester.tap(enlarge);
      await settle(tester);
      await serve(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await settle(tester);

      expect(channels.last.sentCloseCode, isNull);
      expect(channels, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await settle(tester);
      expect(channels.last.sentCloseCode, 1000);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(channels, hasLength(2));
      await finish(tester);
    });

    testWidgets('a desktop app that was paused closes it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpScreen(tester);
      await tester.tap(enlarge);
      await settle(tester);
      await serve(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);

      expect(channels.last.sentCloseCode, 1000);
      await finish(tester);
    });

    testWidgets('a page covered by another route closes it and returns', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(390, 844));
      await pumpFor(tester);
      await tester.tap(enlarge);
      await settle(tester);
      await serve(tester);

      final navigator = Navigator.of(
        tester.element(viewer),
        rootNavigator: true,
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('on top')),
          ),
        ),
      );
      await pumpFor(tester);
      await settle(tester);

      expect(channels.last.sentCloseCode, 1000);
      expect(channels, hasLength(1));

      navigator.pop();
      await pumpFor(tester);
      await settle(tester);

      expect(channels, hasLength(2));
      await finish(tester);
    });

    testWidgets('the chat leaving the screen closes the viewer', (
      tester,
    ) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await pumpScreen(tester, visible: visible);
      await tester.tap(enlarge);
      await settle(tester);
      await serve(tester);

      visible.value = false;
      await settle(tester);

      expect(viewer, findsNothing);
      expect(channels.last.sentCloseCode, 1000);
      await finish(tester);
    });
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
