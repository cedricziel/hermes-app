import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/bot_screen/input/screen_gesture_layer.dart';
import 'package:hermes_app/src/bot_screen/takeover_setting.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/bot_screen/widgets/trackpad_cursor.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_display_server.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import 'bot_screen_repository_test.dart' show jpeg;

/// Taking over from the chat screen's viewer and using the screen: the
/// question, the touch, the keyboard, Paste and the keys of a computer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late FakeDisplayServer display;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late List<FakeDisplayChannel> channels;
  late BreadcrumbTrail trail;
  late TakeoverSetting setting;
  late int connects;
  String? clipboard;

  List<String> crumbs() => [
    for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
  ];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    setting = TakeoverSetting(accountKey: 'test-account');
    clipboard = null;
    channels = [];
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
        profileListBody([profileRow(name: 'default', isDefault: true)]),
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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
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

  /// Opens the viewer from the Activity card, on a phone or a computer.
  Future<void> openViewer(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    TargetPlatform? platform,
    Key activity = const Key('header-activity'),
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return clipboard == null ? null : {'text': clipboard};
          }
          return null;
        });
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      size: size,
      platform: platform,
      takeoverSetting: setting,
      displaySocketOpener: (path, ticket) async {
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
    await tester.tap(find.byKey(activity));
    await tester.pump();
    await settle(tester);
    // A phone's sheet is still sliding in.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Enlarge screen'));
    await settle(tester);
    // A phone's page is still sliding in.
    await tester.pump(const Duration(milliseconds: 500));
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

  final viewer = find.byType(BotScreenViewerView);
  final sheet = find.byType(TakeoverConfirmation);
  final headerTakeOver = find.descendant(
    of: viewer,
    matching: find.widgetWithText(FilledButton, 'Take over'),
  );

  /// Takes over through the question.
  Future<void> takeOver(WidgetTester tester) async {
    await tester.tap(headerTakeOver);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Take over')),
    );
    await tester.pumpAndSettle();
    await settle(tester);
  }

  /// The client messages the stream carried after the handshake, as the
  /// message type and its bytes in hex.
  List<String> sent() => [
    for (final message in clientMessages(channels.last.sentBytes))
      if (message.first == 4 || message.first == 5 || message.first == 6)
        '${message.first} ${message.skip(1).map((b) => b.toRadixString(16)).join(',')}',
  ];

  group('taking over', () {
    testWidgets('asks first, and a cancel sends nothing', (tester) async {
      await openViewer(tester);

      await tester.tap(headerTakeOver);
      await tester.pumpAndSettle();

      expect(sheet, findsOne);
      expect(find.textContaining('stops using the screen'), findsOne);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(display.acquired, isEmpty);
      expect(find.text('Hermes is in control'), findsWidgets);
      expect(crumbs(), contains('bot_screen.takeover.pressed {}'));
      await finish(tester);
    });

    testWidgets('confirming takes over and says so', (tester) async {
      await openViewer(tester);

      await takeOver(tester);

      expect(display.acquired, ['viewer-1']);
      expect(
        find.descendant(of: viewer, matching: find.text("You're in control")),
        findsOne,
      );
      await finish(tester);
    });

    testWidgets('asks each time until told not to', (tester) async {
      await openViewer(tester);
      await takeOver(tester);
      await tester.tap(find.text('Hand Back'));
      await settle(tester);

      await tester.tap(headerTakeOver);
      await tester.pumpAndSettle();
      expect(sheet, findsOne);
      await tester.tap(find.text("Don't ask again"));
      await tester.pump();
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Take over')),
      );
      await tester.pumpAndSettle();
      await settle(tester);
      expect(display.acquired, hasLength(2));

      await tester.tap(find.text('Hand Back'));
      await settle(tester);
      await tester.tap(headerTakeOver);
      await tester.pumpAndSettle();
      await settle(tester);

      expect(sheet, findsNothing);
      expect(display.acquired, hasLength(3));
      expect(await setting.skipsConfirmation(), isTrue);
      await finish(tester);
    });

    testWidgets('Hand Back returns to watching and takes the input away', (
      tester,
    ) async {
      await openViewer(tester);
      await takeOver(tester);
      expect(find.byType(ScreenGestureLayer), findsOne);

      await tester.tap(find.text('Hand Back'));
      await settle(tester);

      expect(find.byType(ScreenGestureLayer), findsNothing);
      expect(
        find.descendant(
          of: viewer,
          matching: find.text('Hermes is in control'),
        ),
        findsOne,
      );
      await finish(tester);
    });
  });

  group('with a finger', () {
    testWidgets('a tap clicks at the mapped point', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.tapAt(tester.getCenter(find.byType(ScreenGestureLayer)));
      await tester.pump();

      expect(sent().sublist(before), [
        '5 0,0,4,0,2',
        '5 1,0,4,0,2',
        '5 0,0,4,0,2',
      ]);
      await finish(tester);
    });

    testWidgets('while watching a tap sends nothing', (tester) async {
      await openViewer(tester, size: const Size(390, 844));

      await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)));
      await tester.pump();

      expect(sent(), isEmpty);
      await finish(tester);
    });

    testWidgets('Trackpad mode shows a cursor and says so in a breadcrumb', (
      tester,
    ) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      expect(find.byKey(const Key('trackpad-cursor')), findsNothing);

      await tester.ensureVisible(find.byTooltip('Use Trackpad mode'));
      await tester.tap(find.byTooltip('Use Trackpad mode'));
      await tester.pump();

      expect(find.byKey(const Key('trackpad-cursor')), findsOne);
      expect(
        tester.getTopLeft(find.byKey(const Key('trackpad-cursor'))),
        tester.getCenter(find.byType(TrackpadCursor)),
      );
      expect(crumbs(), contains('bot_screen.input.mode {mode: trackpad}'));
      expect(
        tester.widget<ScreenGestureLayer>(find.byType(ScreenGestureLayer)).mode,
        ScreenGestureMode.trackpad,
      );

      await tester.ensureVisible(find.byTooltip('Use Touch mode'));
      await tester.tap(find.byTooltip('Use Touch mode'));
      await tester.pump();
      expect(find.byKey(const Key('trackpad-cursor')), findsNothing);
      expect(crumbs(), contains('bot_screen.input.mode {mode: touch}'));
      await finish(tester);
    });
  });

  group('the on-screen keyboard', () {
    testWidgets('has nothing the system keyboard can learn from and sends '
        'only committed text', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pump();

      final args = tester.testTextInput.setClientArgs!;
      expect(args['autocorrect'], isFalse);
      expect(args['enableSuggestions'], isFalse);
      expect(args['enableIMEPersonalizedLearning'], isFalse);
      expect(args['smartDashesType'], '${SmartDashesType.disabled.index}');
      expect(args['smartQuotesType'], '${SmartQuotesType.disabled.index}');
      expect(
        (args['inputType'] as Map)['name'],
        'TextInputType.visiblePassword',
      );

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '​48',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 1, end: 3),
        ),
      );
      await tester.pump();
      expect(sent().length, before);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '​481',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pump();

      expect(sent().sublist(before), [
        '4 1,0,0,0,0,0,34',
        '4 0,0,0,0,0,0,34',
        '4 1,0,0,0,0,0,38',
        '4 0,0,0,0,0,0,38',
        '4 1,0,0,0,0,0,31',
        '4 0,0,0,0,0,0,31',
      ]);
      await finish(tester);
    });

    testWidgets('Ctrl on the key bar holds for the next key', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.tap(find.text('Ctrl'));
      await tester.pump();
      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pump();
      tester.testTextInput.enterText('​c');
      await tester.pump();

      expect(sent().sublist(before), [
        '4 1,0,0,0,0,ff,e3',
        '4 1,0,0,0,0,0,63',
        '4 0,0,0,0,0,0,63',
        '4 0,0,0,0,0,ff,e3',
      ]);
      await finish(tester);
    });

    testWidgets('Esc and Tab of the key bar are key presses', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.tap(find.text('Esc'));
      await tester.tap(find.text('Tab'));
      await tester.pump();

      expect(sent().sublist(before), [
        '4 1,0,0,0,0,ff,1b',
        '4 0,0,0,0,0,ff,1b',
        '4 1,0,0,0,0,ff,9',
        '4 0,0,0,0,0,ff,9',
      ]);
      await finish(tester);
    });

    testWidgets('the stream closing for the background takes the keyboard '
        'away and it can be opened again on return', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
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

      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pump();
      tester.testTextInput.enterText('\u200b7');
      await tester.pump();
      expect(sent().last, '4 0,0,0,0,0,0,37');
      await finish(tester);
    });

    testWidgets('losing control closes the keyboard', (tester) async {
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      await tester.tap(find.byTooltip('Keyboard'));
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      display.giveToAgent();
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);

      expect(tester.testTextInput.hasAnyClients, isFalse);
      await finish(tester);
    });
  });

  group('Paste', () {
    testWidgets('sends the text, Control+V and later an empty clipboard', (
      tester,
    ) async {
      clipboard = 'hunter2';
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.ensureVisible(find.byTooltip('Paste'));
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      await settle(tester);

      final pasted = sent().sublist(before);
      expect(pasted.first, startsWith('6 '));
      expect(pasted.skip(1), [
        '4 1,0,0,0,0,ff,e3',
        '4 1,0,0,0,0,0,76',
        '4 0,0,0,0,0,0,76',
        '4 0,0,0,0,0,ff,e3',
      ]);

      await tester.pump(const Duration(milliseconds: 600));
      expect(sent().last, '6 0,0,0,0,0,0,0');
      await finish(tester);
    });

    testWidgets('text outside Latin-1 is refused with a message and nothing '
        'is sent', (tester) async {
      clipboard = 'café \u{1F600}';
      await openViewer(tester, size: const Size(390, 844));
      await takeOver(tester);
      final before = sent().length;

      await tester.ensureVisible(find.byTooltip('Paste'));
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      await settle(tester);

      expect(find.text("This text can't be pasted to the screen."), findsOne);
      expect(sent().length, before);
      await finish(tester);
    });
  });

  group('the keys of a computer', () {
    testWidgets('Ctrl+V pastes, Ctrl+A reaches the screen and Escape goes to '
        'it, not to the viewer', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      clipboard = 'hunter2';
      await openViewer(tester, platform: TargetPlatform.linux);
      await takeOver(tester);
      final before = sent().length;

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'linux',
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        platform: 'linux',
        character: 'a',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: 'linux');
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyV,
        platform: 'linux',
        character: 'v',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: 'linux');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'linux',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape, platform: 'linux');
      await settle(tester);

      final messages = sent().sublist(before);
      expect(messages, contains('4 1,0,0,0,0,0,61'));
      expect(messages.where((m) => m.startsWith('6 ')), isNotEmpty);
      expect(
        messages,
        containsAllInOrder(['4 1,0,0,0,0,ff,1b', '4 0,0,0,0,0,ff,1b']),
      );
      expect(viewer, findsOne);
      await tester.pump(const Duration(seconds: 1));
      await finish(tester);
    });

    testWidgets('F8 closes the viewer and hands control back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await openViewer(tester, platform: TargetPlatform.linux);
      await takeOver(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.f8, platform: 'linux');
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewer, findsNothing);
      expect(display.released, ['viewer-1']);
      expect(display.holder, 'agent');
      await finish(tester);
    });

    testWidgets('Send F8 is offered on Linux and sends the key', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await openViewer(tester, platform: TargetPlatform.linux);
      await takeOver(tester);
      final before = sent().length;

      await tester.tap(find.text('Send F8'));
      await tester.pump();

      expect(sent().sublist(before), [
        '4 1,0,0,0,0,ff,c5',
        '4 0,0,0,0,0,ff,c5',
      ]);
      expect(viewer, findsOne);
      await finish(tester);
    });

    testWidgets('a computer has no key bar and a touch device no tools', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await openViewer(tester, platform: TargetPlatform.linux);
      await takeOver(tester);

      expect(find.byTooltip('Keyboard'), findsNothing);
      expect(find.byTooltip('Paste'), findsOne);
      await finish(tester);
    });

    testWidgets('the wheel scrolls the screen and does not zoom the '
        'picture', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await openViewer(tester, platform: TargetPlatform.linux);
      await takeOver(tester);
      final before = sent().length;
      final zoom = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final center = tester.getCenter(find.byType(ScreenGestureLayer));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(mouse.hover(center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();

      expect(zoom.scaleEnabled, isFalse);
      expect(zoom.transformationController!.value.getMaxScaleOnAxis(), 1);
      expect(sent().sublist(before).any((m) => m.startsWith('5 ')), isTrue);
      await finish(tester);
    });
  });

  testWidgets('on a Mac, Command+A reaches the screen as Control+A and '
      'Command+Q is left to the app', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await openViewer(
      tester,
      platform: TargetPlatform.macOS,
      activity: const Key('toolbar-activity'),
    );
    await takeOver(tester);
    final before = sent().length;

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyA,
      platform: 'macos',
      character: 'a',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA, platform: 'macos');
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyQ,
      platform: 'macos',
      character: 'q',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ, platform: 'macos');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
    await settle(tester);

    expect(sent().sublist(before), [
      '4 1,0,0,0,0,ff,e3',
      '4 1,0,0,0,0,0,61',
      '4 0,0,0,0,0,0,61',
      '4 0,0,0,0,0,ff,e3',
    ]);
    await finish(tester);
  });

  testWidgets('no key name, text or coordinate reaches a breadcrumb', (
    tester,
  ) async {
    clipboard = 'hunter2';
    await openViewer(tester, size: const Size(390, 844));
    await takeOver(tester);
    await tester.tap(find.byTooltip('Keyboard'));
    await tester.pump();
    tester.testTextInput.enterText('​hunter2');
    await tester.tapAt(tester.getCenter(find.byType(ScreenGestureLayer)));
    await tester.ensureVisible(find.byTooltip('Paste'));
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    await settle(tester);

    final everything = crumbs().join(' ');
    expect(everything, isNot(contains('hunter2')));
    expect(everything, isNot(contains('Escape')));
    await finish(tester);
  });
}

class _Lock extends AppLockController {
  @override
  bool get covered => false;
}
