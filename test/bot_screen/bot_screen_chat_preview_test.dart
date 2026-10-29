import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/bot_screen/widgets/bound_bot_screen_preview.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/bot_screen_fixture.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import 'bot_screen_repository_test.dart' show statusJson;

/// The still preview under the `computer_use` call of a running reply, on the
/// chat screen over the real transport.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late ChatProfiles profiles;
  late BreadcrumbTrail trail;
  late List<FakeDisplayChannel> channels;
  late _Lock lock;
  var running = true;
  var unsupported = false;

  void emit(String type, [Map<String, Object?> payload = const {}]) =>
      gateway.event(type, gateway.lastSessionId, payload);

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    running = true;
    unsupported = false;
    trail = BreadcrumbTrail();
    channels = [];
    lock = _Lock();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) {
      if (unsupported) throw const FakeRpcError(-32601, 'unknown method');
      return statusJson(running: running);
    };
    gateway.handlers['display.observe'] = (_) => {
      'ticket': 'ticket',
      'path': '/api/display/ws',
      'viewer_id': 'viewer',
      ...statusJson(),
    };
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url':
          'data:image/png;base64,${base64Encode(botScreenFixturePng())}',
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
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'First chat'),
          sessionRow(id: 'stored-2', title: 'Second chat'),
          sessionRow(id: 'stored-3', title: 'Long chat'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-2/messages',
        messageListBody('stored-2', [
          messageRow(id: 1, role: 'user', content: 'Another'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-3/messages',
        messageListBody('stored-3', [
          for (var i = 1; i <= 40; i++)
            messageRow(
              id: i,
              role: i.isOdd ? 'user' : 'assistant',
              content: 'Message $i of a long conversation. ' * 8,
            ),
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
    Size size = const Size(1400, 900),
    String thread = 'First chat',
  }) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      chatProfiles: profiles,
      size: size,
      displaySocketOpener: (path, ticket) async {
        final channel = FakeDisplayChannel();
        channels.add(channel);
        return channel;
      },
      providers: [
        ChangeNotifierProvider<AppLockController>.value(value: lock),
        Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
      ],
    );
    await openThread(tester, thread);
  }

  /// Sends a prompt; the fake gateway then holds the turn open until the test
  /// ends it.
  Future<void> startReply(WidgetTester tester) async {
    await tester.enterText(composerField, 'Book a table');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await settle(tester);
    emit('message.start');
    await settle(tester);
  }

  Future<void> emitAndSettle(
    WidgetTester tester,
    String type, [
    Map<String, Object?> payload = const {},
  ]) async {
    emit(type, payload);
    await settle(tester);
  }

  Future<void> useScreen(
    WidgetTester tester,
    String id, {
    bool finish = false,
  }) async {
    await emitAndSettle(tester, 'tool.start', {
      'tool_id': id,
      'name': 'computer_use',
      'context': 'click',
      'args': {'action': 'click'},
    });
    if (finish) {
      await emitAndSettle(tester, 'tool.complete', {
        'tool_id': id,
        'name': 'computer_use',
        'result': {'ok': true},
        'duration_s': 0.4,
      });
    }
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  final preview = find.byType(BotScreenPreview);
  final previewTarget = find.descendant(
    of: preview,
    matching: find.byType(InkWell),
  );

  group('placement', () {
    testWidgets('a running computer_use call shows the preview on its card', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);

      await useScreen(tester, 'c1');

      expect(preview, findsOne);
      expect(find.text('Live'), findsOne);
      expect(find.text('Hermes is in control'), findsOne);
      expect(
        find.descendant(of: find.byType(ToolCallGroup), matching: preview),
        findsOne,
      );
      expect(calls('display.thumbnail'), greaterThan(0));
      await end(tester);
    });

    testWidgets('a folded group shows it in its header and stays folded', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);

      await useScreen(tester, 'c1', finish: true);
      await useScreen(tester, 'c2');

      expect(find.byType(ToolCallGroup), findsOne);
      expect(preview, findsOne);
      expect(
        find.descendant(of: find.byType(ToolCallGroup), matching: preview),
        findsOne,
      );
      // The group is folded: its calls are not drawn as cards.
      expect(find.byType(ToolCallCard), findsNothing);
      await end(tester);
    });

    testWidgets('a later computer_use run takes the preview over', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1', finish: true);
      // Text before the next call starts a run of its own.
      await emitAndSettle(tester, 'message.delta', {'text': 'Now the form.'});
      final state = tester.state(find.byType(BoundBotScreenPreview));

      await useScreen(tester, 'c2');

      expect(preview, findsOne);
      final owner = tester.widget<ToolCallGroup>(
        find.ancestor(of: preview, matching: find.byType(ToolCallGroup)),
      );
      expect(owner.calls.single.id, 'c2');
      // It moved to the later run with its state, not drawn anew.
      expect(tester.state(find.byType(BoundBotScreenPreview)), same(state));
      expect(find.text('Waiting for the first picture…'), findsNothing);
      await end(tester);
    });

    testWidgets('a run of other tools gets no preview', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);

      await emitAndSettle(tester, 'tool.start', {
        'tool_id': 't1',
        'name': 'terminal',
        'context': 'ls',
        'args': {'command': 'ls'},
      });

      expect(find.byType(ToolCallCard), findsOne);
      expect(preview, findsNothing);
      await end(tester);
    });

    testWidgets('the preview leaves when the reply ends and nothing asks for '
        'frames after it', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(preview, findsOne);

      await emitAndSettle(tester, 'message.complete', {'text': 'Booked.'});
      final before = calls('display.thumbnail');

      expect(preview, findsNothing);
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);
      await end(tester);
    });

    testWidgets('a screen that is not running shows nothing and asks for no '
        'frame', (tester) async {
      running = false;
      await pumpScreen(tester);
      await startReply(tester);

      await useScreen(tester, 'c1');
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);

      expect(preview, findsNothing);
      expect(calls('display.thumbnail'), 0);
      await end(tester);
    });

    testWidgets('a server without the Bot Screen shows nothing', (
      tester,
    ) async {
      unsupported = true;
      await pumpScreen(tester);
      await startReply(tester);

      await useScreen(tester, 'c1');

      expect(preview, findsNothing);
      expect(calls('display.thumbnail'), 0);
      await end(tester);
    });

    testWidgets('a person in control leaves no picture, only who', (
      tester,
    ) async {
      gateway.handlers['display.status'] = (_) => statusJson(
        lease: {'holder': 'human', 'since': 1.0, 'epoch': 3, 'reason': ''},
      );
      await pumpScreen(tester);
      await startReply(tester);

      await useScreen(tester, 'c1');

      expect(preview, findsOne);
      expect(find.text('Someone else is in control'), findsOne);
      expect(find.text('Live'), findsNothing);
      await end(tester);
    });
  });

  group('opening the live viewer', () {
    final viewer = find.byType(BotScreenViewerView);
    final card = find.byType(BotScreenCard);

    testWidgets('a click opens the viewer over the window, not the panel', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(find.byKey(const Key('activity-inspector')), findsNothing);

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      expect(viewer, findsOne);
      expect(find.byKey(const Key('bot-screen-viewer-overlay')), findsOne);
      expect(find.byType(BotScreenCard), findsNothing);
      expect(channels, hasLength(1));
      expect(
        gateway.requests.where((r) => r['method'] == 'display.observe'),
        hasLength(1),
      );
      await end(tester);
    });

    testWidgets('closing it leaves the chat as it was, and it opens again', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pump();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(viewer, findsNothing);
      expect(find.byKey(const Key('activity-inspector')), findsNothing);
      expect(channels.last.sentCloseCode, 1000);

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);
      expect(viewer, findsOne);
      expect(channels, hasLength(2));
      await end(tester);
    });

    testWidgets('with the inspector open the panel stays beneath it', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pump();
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(card, findsOne);

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      expect(viewer, findsOne);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(viewer, findsNothing);
      expect(card, findsOne);
      await end(tester);
    });

    testWidgets('a tap opens a full-screen page on a phone', (tester) async {
      await pumpScreen(tester, size: const Size(390, 844));
      await startReply(tester);
      await useScreen(tester, 'c1');

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      expect(find.byKey(const Key('bot-screen-viewer-page')), findsOne);
      expect(find.byKey(const Key('activity-close')), findsNothing);
      await end(tester);
    });

    testWidgets('records the preview tap and where the viewer opened from', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      final all = [
        for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
      ];
      expect(all, contains('bot_screen.preview.tapped {}'));
      expect(
        all,
        contains(
          'bot_screen.viewer.opened {surface: overlay, source: preview}',
        ),
      );
      await end(tester);
    });
  });

  group('where it sits and what keeps it', () {
    Map<String, Object?> call(String id) => {
      'tool_id': id,
      'name': 'computer_use',
      'context': 'click',
      'args': {'action': 'click'},
    };

    testWidgets('a folded group that starts cold still shows it and asks for '
        'frames', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);

      // Two calls arrive before anything has been read.
      emit('tool.start', call('c1'));
      emit('tool.start', call('c2'));
      await settle(tester);

      expect(find.byType(ToolCallGroup), findsOne);
      expect(preview, findsOne);
      expect(calls('display.thumbnail'), greaterThan(0));
      await end(tester);
    });

    testWidgets('the preview sits below a single call\'s card and keeps its '
        'state and frame when the run folds into a group', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(find.text('Waiting for the first picture…'), findsNothing);
      final state = tester.state(find.byType(BoundBotScreenPreview));
      expect(
        tester.getTopLeft(preview).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(ToolCallCard)).dy,
        ),
      );
      final statusReads = calls('display.status');

      await useScreen(tester, 'c2');

      expect(find.byType(ToolCallGroup), findsOne);
      expect(tester.state(find.byType(BoundBotScreenPreview)), same(state));
      expect(find.text('Waiting for the first picture…'), findsNothing);
      expect(calls('display.status'), statusReads);
      await end(tester);
    });

    testWidgets('an approval appearing on the call leaves the preview as it '
        'was', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      final state = tester.state(find.byType(BoundBotScreenPreview));
      final statusReads = calls('display.status');

      await emitAndSettle(tester, 'approval.request', {
        'request_id': 'r1',
        'command': 'open the booking page',
        'description': 'computer use',
        'choices': ['once', 'deny'],
        'tool_name': 'computer_use',
      });

      expect(find.byType(ApprovalCard), findsOne);
      expect(preview, findsOne);
      expect(tester.state(find.byType(BoundBotScreenPreview)), same(state));
      expect(find.text('Waiting for the first picture…'), findsNothing);
      expect(calls('display.status'), statusReads);
      await end(tester);
    });

    for (final (name, status) in [
      ('a failed reply', 'error'),
      ('a stopped reply', 'interrupted'),
    ]) {
      testWidgets('$name takes the preview away and stops the requests', (
        tester,
      ) async {
        await pumpScreen(tester);
        await startReply(tester);
        await useScreen(tester, 'c1');
        expect(preview, findsOne);

        await emitAndSettle(tester, 'message.complete', {
          'text': '',
          'status': status,
          if (status == 'error') 'error': 'It broke',
        });
        final before = calls('display.thumbnail');

        expect(preview, findsNothing);
        await tester.pump(const Duration(seconds: 12));
        await settle(tester);
        expect(calls('display.thumbnail'), before);
        await end(tester);
      });
    }
  });

  group('in the real transcript', () {
    final list = find.descendant(
      of: find.byType(Chat),
      matching: find.byType(Scrollable),
    );

    testWidgets('scrolling the preview off screen stops the requests and '
        'scrolling back asks again', (tester) async {
      await pumpScreen(tester, thread: 'Long chat');
      await startReply(tester);
      await useScreen(tester, 'c1');
      await tester.pump(const Duration(milliseconds: 500));
      expect(preview, findsOne);
      expect(calls('display.thumbnail'), greaterThan(0));

      // Far enough that it is below the screen, near enough that the list
      // still builds it.
      await tester.drag(list.first, const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(
        find.byType(BoundBotScreenPreview, skipOffstage: false),
        findsOne,
        reason: 'built in the cache extent',
      );
      final before = calls('display.thumbnail');
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);

      await tester.drag(list.first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(calls('display.thumbnail'), greaterThan(before));
      await end(tester);
    });

    testWidgets('opening another chat releases the watch', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(calls('display.thumbnail'), greaterThan(0));

      await openThread(tester, 'Second chat', settle: false);
      await settle(tester);
      expect(preview, findsNothing);
      final before = calls('display.thumbnail');
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);

      expect(calls('display.thumbnail'), before);
      await end(tester);
    });

    testWidgets('another profile releases the watch', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      expect(calls('display.thumbnail'), greaterThan(0));

      await tester.runAsync(() => profiles.switchTo('work'));
      await settle(tester);
      await openThread(tester, 'First chat', settle: false);
      await settle(tester);
      int defaultFrames() => gateway.requests
          .where(
            (r) =>
                r['method'] == 'display.thumbnail' &&
                (r['params'] as Map)['profile'] == 'default',
          )
          .length;
      final before = defaultFrames();
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);

      expect(preview, findsNothing);
      expect(defaultFrames(), before);
      await end(tester);
    });
  });

  group('polling', () {
    testWidgets('App Lock stops the requests and the picture, unlocking '
        'resumes them', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      final before = calls('display.thumbnail');
      expect(before, greaterThan(0));

      lock.covered = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);

      lock.covered = false;
      await tester.pump();
      await settle(tester);
      expect(calls('display.thumbnail'), greaterThan(before));
      await end(tester);
    });

    testWidgets('leaving the foreground stops the requests, resuming asks '
        'again', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      final before = calls('display.thumbnail');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await settle(tester);
      expect(calls('display.thumbnail'), greaterThan(before));
      await end(tester);
    });
  });

  group('breadcrumbs', () {
    List<String> crumbs() => [
      for (final crumb in trail.recent)
        if (crumb.name.startsWith('bot_screen.preview'))
          '${crumb.name} ${crumb.attributes}',
    ];

    testWidgets('shown is recorded once per reply, tapped once per tap, both '
        'without attributes', (tester) async {
      await pumpScreen(tester);
      await startReply(tester);
      await useScreen(tester, 'c1');
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(crumbs(), ['bot_screen.preview.shown {}']);

      await tester.tap(previewTarget);
      await tester.pump();
      await settle(tester);

      expect(crumbs(), [
        'bot_screen.preview.shown {}',
        'bot_screen.preview.tapped {}',
      ]);
      await end(tester);
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
