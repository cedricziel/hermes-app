import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_display_server.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import 'bot_screen_repository_test.dart' show jpeg;

/// The chat screen's viewer while this device holds the screen's control
/// lease: handing back, closing, leaving, and what each way of not being seen
/// does to the stream.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late FakeDisplayServer display;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late ChatProfiles profiles;
  late List<FakeDisplayChannel> channels;
  late List<String> tickets;
  late BreadcrumbTrail trail;
  late int connects;

  List<String> crumbs() => [
    for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
  ];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    channels = [];
    tickets = [];
    connects = 0;
    trail = BreadcrumbTrail(capacity: 200);
    gateway = FakeGateway()..activeSessions = {};
    display = FakeDisplayServer(gateway, connection: () => connects);
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(
      connect: () {
        connects++;
        return gateway.connect();
      },
    );
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

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      displaySocketOpener: (path, ticket) async {
        tickets.add(ticket);
        final channel = FakeDisplayChannel();
        channels.add(channel);
        return channel;
      },
      providers: [
        ChangeNotifierProvider<AppLockController>(create: (_) => _Lock()),
        Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
      ],
    );
    await openThread(tester, 'First chat');
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump();
    await settle(tester);
  }

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

  Future<void> finish(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  /// Opens the viewer and has this device hold the lease under the id the
  /// viewer was given, as a take over would.
  Future<void> openInControl(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Enlarge screen'));
    await settle(tester);
    await serve(tester);
    display.takeBy(display.mintedIds.single);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
  }

  final viewer = find.byType(BotScreenViewerView);

  testWidgets('a lease held by this device says so in the viewer and on the '
      'card, which offers no way to force it back', (tester) async {
    await openInControl(tester);

    expect(
      find.descendant(of: viewer, matching: find.text("You're in control")),
      findsOne,
    );
    expect(
      find.descendant(
        of: find.byType(BotScreenCard, skipOffstage: false),
        matching: find.text("You're in control", skipOffstage: false),
      ),
      findsOne,
    );
    expect(find.text('Hand back to Hermes'), findsNothing);
    await finish(tester);
  });

  testWidgets('Hand Back releases on the observing connection and the viewer '
      'goes back to watching', (tester) async {
    await openInControl(tester);

    await tester.tap(find.text('Hand Back'));
    await settle(tester);

    expect(display.released, ['viewer-1']);
    expect(display.holder, 'agent');
    expect(
      find.descendant(of: viewer, matching: find.text('Hermes is in control')),
      findsOne,
    );
    expect(viewer, findsOne);
    expect(channels.last.sentCloseCode, isNull);
    expect(crumbs(), contains('bot_screen.handback.pressed {}'));
    await finish(tester);
  });

  testWidgets('Close hands back first and then closes the stream with 1000', (
    tester,
  ) async {
    await openInControl(tester);
    Object? closedAtRelease = 'not called';
    final channel = channels.last;
    final release = gateway.handlers['display.lease.release']!;
    gateway.handlers['display.lease.release'] = (params) {
      closedAtRelease = channel.sentCloseCode;
      return release(params);
    };

    await tester.tap(find.byTooltip('Close (Esc)'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(viewer, findsNothing);
    expect(display.released, ['viewer-1']);
    expect(closedAtRelease, isNull);
    expect(channel.sentCloseCode, 1000);
    expect(display.holder, 'agent');
    await finish(tester);
  });

  testWidgets('Escape goes to the screen, not to the viewer, while in '
      'control', (tester) async {
    await openInControl(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(viewer, findsOne);
    expect(channels.last.sentCloseCode, isNull);
    await finish(tester);
  });

  testWidgets('switching the chat\'s profile hands back before the stream '
      'closes', (tester) async {
    await openInControl(tester);

    await tester.runAsync(() => profiles.switchTo('work'));
    await settle(tester);

    expect(viewer, findsNothing);
    expect(display.released, ['viewer-1']);
    expect(channels.last.sentCloseCode, 1000);
    await finish(tester);
  });

  testWidgets('leaving the chat screen, as sign-out does, hands back and '
      'closes with 1000', (tester) async {
    await openInControl(tester);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);

    expect(display.released, ['viewer-1']);
    expect(display.holder, 'agent');
    expect(channels.last.sentCloseCode, 1000);
    await tester.runAsync(transport.close);
  });

  testWidgets('the app going to the background closes with 4100 and keeps '
      'the lease, and returning keeps control', (tester) async {
    await openInControl(tester);
    final first = channels.last;

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);

    expect(first.sentCloseCode, 4100);
    expect(display.holder, 'human');
    expect(display.released, isEmpty);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
    await serve(tester);

    expect(channels, hasLength(2));
    expect(display.observedWith.last, 'viewer-1');
    expect(display.acquired, isEmpty);
    expect(
      find.descendant(of: viewer, matching: find.text("You're in control")),
      findsOne,
    );
    await finish(tester);
  });

  testWidgets('a glance at the notification shade keeps the stream, a long '
      'one closes it with 4100', (tester) async {
    await openInControl(tester);
    final first = channels.last;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(first.sentCloseCode, isNull);
    expect(channels, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(first.sentCloseCode, 4100);
    expect(display.holder, 'human');
    await finish(tester);
  });

  group('a lease held by someone else', () {
    Future<void> openHeldBySomeone(WidgetTester tester) async {
      await pumpScreen(tester);
      display.takeBy('somebody-before-the-restart');
      await tester.tap(find.byTooltip('Enlarge screen'));
      await settle(tester);
      await serve(tester);
    }

    testWidgets('the viewer offers Hand back to Hermes, asks first and then '
        'forces the release', (tester) async {
      await openHeldBySomeone(tester);
      final handBack = find.descendant(
        of: viewer,
        matching: find.text('Hand back to Hermes'),
      );
      expect(handBack, findsOne);

      await tester.tap(handBack);
      await tester.pumpAndSettle();
      expect(find.text('Hand control back to Hermes?'), findsOne);
      await tester.tap(find.widgetWithText(AppDialogAction, 'Cancel'));
      await tester.pumpAndSettle();
      expect(display.released, isEmpty);

      await tester.tap(handBack);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppDialogAction, 'Hand Back'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(display.released, [null]);
      expect(display.holder, 'agent');
      expect(
        find.descendant(
          of: viewer,
          matching: find.text('Hermes is in control'),
        ),
        findsOne,
      );
      expect(crumbs(), contains('bot_screen.force_handback.pressed {}'));
      await finish(tester);
    });
  });
}

/// An App Lock that covers nothing.
class _Lock extends AppLockController {
  @override
  bool get covered => false;
}
