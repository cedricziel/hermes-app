import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_attachment_source.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import 'bot_screen_repository_test.dart' show jpeg, statusJson;

/// The Activity panel with the Bot screen card, over a real chat controller
/// and gateway transport.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  BotScreenController? screen;
  late BreadcrumbTrail trail;
  var running = true;
  var holder = 'agent';
  var usedComputer = false;

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    screen = null;
    running = true;
    holder = 'agent';
    usedComputer = false;
    trail = BreadcrumbTrail();
    activity = ValueNotifier(true);
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) =>
        statusJson(running: running, lease: {'holder': holder, 'epoch': 1});
    gateway.handlers['display.start'] = (_) {
      running = true;
      return statusJson(running: true);
    };
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });

  tearDown(() async {
    screen?.dispose();
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
            toolCalls: usedComputer
                ? [functionCall('computer_use', '{"action":"screenshot"}')]
                : null,
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

  Future<void> openChat(WidgetTester tester) async {
    await tester.runAsync(loadChat);
  }

  /// Lets the gateway calls and the image decode finish: they run on real
  /// time, outside the test's fake clock.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool withScreen = true,
    bool visible = true,
    bool panel = true,
  }) async {
    if (withScreen) {
      screen ??= BotScreenController(
        BotScreenRepository(transport.requestKeepingConnection),
        transport.connectionEvents,
        profile: 'work',
      );
    }
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    await tester.pumpWidget(
      Provider<Breadcrumbs>.value(
        value: Breadcrumbs.of(trail),
        child: MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (context, _) => Row(
                children: [
                  Expanded(
                    key: const Key('strip-side'),
                    child: boundChatThreadView(
                      chat: chat,
                      thread: chat.selectedThread,
                      composerController: composer,
                      composerFocus: focus,
                      attachments: const [],
                      attachmentSource: FakeAttachmentSource(),
                      onAddAttachments: (_) {},
                      onRemoveAttachment: (_) {},
                      onSend: (_) {},
                      latestReply: latest,
                      welcome: false,
                    ),
                  ),
                  if (panel)
                    SizedBox(
                      width: 380,
                      child: Visibility(
                        visible: visible,
                        maintainState: true,
                        child: BoundActivityPanel(
                          chat: chat,
                          thread: chat.selectedThread,
                          screen: screen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// A test that ends with the panel unmounted, which stops the polling.
  void panelTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
      });

  final card = find.byType(BotScreenCard);

  panelTest('a running screen is listed under Now with its frame, and the '
      'strip shows nothing for it', (tester) async {
    await openChat(tester);
    await pumpPanel(tester);

    expect(card, findsOne);
    expect(find.text('Hermes is in control'), findsOne);
    expect(find.byType(Image), findsWidgets);
    expect(
      find.descendant(of: find.byKey(const Key('strip-side')), matching: card),
      findsNothing,
    );
    expect(find.text('NOW'), findsOne);
  });

  panelTest('a stopped screen and a chat that never used it list nothing', (
    tester,
  ) async {
    running = false;
    await openChat(tester);
    await pumpPanel(tester);

    expect(card, findsNothing);
    expect(find.text('NOW'), findsNothing);
  });

  panelTest('a stopped screen is listed as Off for a chat that used it', (
    tester,
  ) async {
    running = false;
    usedComputer = true;
    await openChat(tester);
    await pumpPanel(tester);

    expect(card, findsOne);
    expect(find.text('Start Screen'), findsOne);
  });

  panelTest('a server without the feature lists nothing, even for a chat '
      'that used the screen', (tester) async {
    usedComputer = true;
    gateway.handlers['display.status'] = (_) =>
        throw const FakeRpcError(-32601, 'unknown method');
    await openChat(tester);
    await pumpPanel(tester);

    expect(card, findsNothing);
    expect(calls('display.thumbnail'), 0);
  });

  panelTest('Start Screen sends display.start and shows the running card', (
    tester,
  ) async {
    running = false;
    usedComputer = true;
    await openChat(tester);
    await pumpPanel(tester);

    await tester.tap(find.text('Start Screen'));
    await settle(tester);

    expect(calls('display.start'), 1);
    expect(gateway.requests.lastWhere((r) => r['method'] == 'display.start'), {
      'jsonrpc': '2.0',
      'id': isNotNull,
      'method': 'display.start',
      'params': {'profile': 'work'},
    });
    expect(find.text('Hermes is in control'), findsOne);
    expect(
      [for (final c in trail.recent) c.name],
      containsAllInOrder([
        'bot_screen.card.shown',
        'bot_screen.start.pressed',
        'bot_screen.card.shown',
      ]),
    );
  });

  panelTest('Start Screen shows Starting until display.start answers', (
    tester,
  ) async {
    running = false;
    usedComputer = true;
    gateway.silent.add('display.start');
    await openChat(tester);
    await pumpPanel(tester);

    await tester.tap(find.text('Start Screen'));
    await settle(tester);

    expect(find.text('Starting the screen…'), findsOne);
    expect(find.text('Start Screen'), findsNothing);

    gateway.silent.remove('display.start');
    running = true;
    gateway.replyTo(
      gateway.requestOf('display.start'),
      statusJson(running: true),
    );
    await settle(tester);

    expect(find.text('Starting the screen…'), findsNothing);
    expect(find.text('Hermes is in control'), findsOne);
  });

  panelTest('a failed Start shows Off with the reason', (tester) async {
    running = false;
    usedComputer = true;
    gateway.handlers['display.start'] = (_) =>
        throw const FakeRpcError(5300, 'cannot start');
    await openChat(tester);
    await pumpPanel(tester);

    await tester.tap(find.text('Start Screen'));
    await settle(tester);

    expect(find.text("Couldn't start the screen."), findsOne);
    expect(find.text('Start Screen'), findsOne);
  });

  panelTest('a person holding control shows no picture', (tester) async {
    holder = 'human';
    await openChat(tester);
    await pumpPanel(tester);

    expect(find.text('Someone else is in control'), findsOne);
    expect(find.byType(Image), findsNothing);
    expect(screen!.frame, isNull);
  });

  group('handing back a lease nobody here holds', () {
    Future<void> openHeldByAPerson(WidgetTester tester) async {
      holder = 'human';
      gateway.handlers['display.lease.release'] = (_) {
        holder = 'agent';
        return {
          'lease': {'holder': 'agent', 'epoch': 2},
        };
      };
      await openChat(tester);
      await pumpPanel(tester);
    }

    final confirm = find.widgetWithText(AppDialogAction, 'Hand Back');

    panelTest('asks first, and a cancel sends nothing', (tester) async {
      await openHeldByAPerson(tester);

      await tester.tap(find.text('Hand back to Hermes'));
      await tester.pumpAndSettle();

      expect(find.text('Hand control back to Hermes?'), findsOne);
      expect(find.textContaining('loses control'), findsOne);
      await tester.tap(find.widgetWithText(AppDialogAction, 'Cancel'));
      await tester.pumpAndSettle();
      await settle(tester);

      expect(calls('display.lease.release'), 0);
      expect(find.text('Someone else is in control'), findsOne);
    });

    panelTest('confirming sends a forced release and shows Hermes in '
        'control', (tester) async {
      await openHeldByAPerson(tester);

      await tester.tap(find.text('Hand back to Hermes'));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await settle(tester);

      expect(gateway.requestOf('display.lease.release')['params'], {
        'profile': 'work',
        'force': true,
      });
      expect(find.text('Someone else is in control'), findsNothing);
      expect(find.text('Hermes is in control'), findsOne);
      expect([
        for (final c in trail.recent) c.name,
      ], contains('bot_screen.force_handback.pressed'));
    });

    panelTest('a refusal says so and leaves the card as it was', (
      tester,
    ) async {
      await openHeldByAPerson(tester);
      gateway.handlers['display.lease.release'] = (_) =>
          throw const FakeRpcError(5300, 'broken');

      await tester.tap(find.text('Hand back to Hermes'));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await settle(tester);

      expect(find.text("Couldn't hand control back to Hermes."), findsOne);
      expect(find.text('Someone else is in control'), findsOne);
    });
  });

  panelTest('closing the panel stops the frame requests and drops the '
      'frame', (tester) async {
    await openChat(tester);
    await pumpPanel(tester);
    expect(screen!.frame, isNotNull);
    final before = calls('display.thumbnail');

    await pumpPanel(tester, panel: false);
    await tester.pump(const Duration(seconds: 12));

    expect(calls('display.thumbnail'), before);
    expect(screen!.frame, isNull);
  });

  panelTest('a hidden panel stops the requests, a shown one resumes them', (
    tester,
  ) async {
    await openChat(tester);
    await pumpPanel(tester);
    final before = calls('display.thumbnail');

    await pumpPanel(tester, visible: false);
    await tester.pump(const Duration(seconds: 12));
    expect(calls('display.thumbnail'), before);
    expect(screen!.frame, isNull);

    await pumpPanel(tester);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    expect(screen!.frame, isNotNull);
  });

  panelTest('reopening the panel does not record the same state again', (
    tester,
  ) async {
    await openChat(tester);
    await pumpPanel(tester);
    await pumpPanel(tester, panel: false);
    await pumpPanel(tester);

    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'],
      ['bot_screen.card.shown {state: frame}'],
    );
  });

  panelTest('a page pushed over the panel stops the requests, popping it '
      'resumes them', (tester) async {
    await openChat(tester);
    await pumpPanel(tester);
    final before = calls('display.thumbnail');
    final navigator = Navigator.of(
      tester.element(find.byType(BoundActivityPanel)),
    );

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Skills')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settle(tester);
    await tester.pump(const Duration(seconds: 12));
    expect(calls('display.thumbnail'), before);
    expect(screen!.frame, isNull);

    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    expect(screen!.frame, isNotNull);
  });

  panelTest('without a screen controller (a conversation window) no card '
      'is listed and nothing is requested', (tester) async {
    usedComputer = true;
    await openChat(tester);
    screen = null;
    await pumpPanel(tester, withScreen: false);
    await tester.pump(const Duration(seconds: 12));

    expect(card, findsNothing);
    expect(calls('display.status'), 0);
    expect(calls('display.thumbnail'), 0);
  });
}
