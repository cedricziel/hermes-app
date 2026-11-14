import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/side_results/side_result_card.dart';
import 'package:hermes_app/src/chat/widgets/billing_verification_card.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_attachment_source.dart';
import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';

/// A widget test that, once its body is done, lets the panel's read of the
/// chat's agents (made when it opens or the chat changes) land, so no request
/// is left in flight.
void panelTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late _TestAppLock lock;
  late ValueNotifier<bool> activity;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    lock = _TestAppLock();
    activity = ValueNotifier(true);
    gateway = FakeGateway();
    gateway.activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['session_id'] == 'stored-2' ? 'rt-2' : 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'First'),
          sessionRow(id: 'stored-2', title: 'Second'),
        ]),
      );
    for (final id in ['stored-1', 'stored-2']) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      activity: activity,
      appLock: lock,
      attention: attention,
      report: (_) {},
    );
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
    lock.dispose();
    activity.dispose();
  });

  Future<void> open(String id) async {
    if (chat.threads.isEmpty) await chat.loadThreads('work');
    chat.select(id);
    await pumpEventQueue();
  }

  Future<void> pumpChat(WidgetTester tester) async {
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    await tester.pumpWidget(
      MaterialApp(
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
                SizedBox(
                  width: 380,
                  child: BoundActivityPanel(
                    chat: chat,
                    thread: chat.selectedThread,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Finder inStrip(Finder finder) => find.descendant(
    of: find.byKey(const Key('strip-side')),
    matching: finder,
  );
  Finder inPanel(Finder finder) => find.descendant(
    of: find.byKey(const Key('activity-panel')),
    matching: finder,
  );

  panelTest(
    'recall events go to This session, survive clears and stay with their chat',
    (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        gateway.event('status.update', 'rt-1', {
          'kind': 'lifecycle',
          'text': '🧠 robot-notes — recalled 5 memories',
        });
        gateway.event('status.update', 'rt-1', {
          'kind': 'lifecycle',
          'text': '',
        });
        await pumpEventQueue();
      });
      await pumpChat(tester);
      expect(inStrip(find.byType(MemoryActivityCard)), findsNothing);
      expect(inStrip(find.textContaining('recalled')), findsNothing);
      expect(inPanel(find.byType(MemoryActivityCard)), findsOneWidget);
      expect(inPanel(find.text('THIS SESSION')), findsOneWidget);
      await tester.tap(inPanel(find.text('Memory & review')));
      await tester.pumpAndSettle();
      expect(inPanel(find.textContaining('did not include')), findsOneWidget);
      await tester.runAsync(() => open('stored-2'));
      await tester.pump();
      expect(find.byType(MemoryActivityCard), findsNothing);
    },
  );

  panelTest('finished status and process logs stay in the inspector', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await open('stored-1');
      gateway.event('status.update', 'rt-1', {
        'kind': 'lifecycle',
        'text': 'Background Process Finished: check status',
      });
      gateway.event('agent.terminal.output', 'rt-1', {
        'process_id': 'worker',
        'chunk': 'Received output',
      });
      gateway.event('terminal.close', 'rt-1', {'process_id': 'worker'});
      await pumpEventQueue();
    });
    await pumpChat(tester);
    expect(inStrip(find.byType(SessionStatusCard)), findsNothing);
    expect(inStrip(find.byType(ProcessOutputCard)), findsNothing);
    expect(inPanel(find.byType(SessionStatusCard)), findsOneWidget);
    expect(inPanel(find.byType(ProcessOutputCard)), findsOneWidget);
  });

  panelTest('process output and its omission note are under Now, not This '
      'session', (tester) async {
    await tester.runAsync(() async {
      await open('stored-1');
      gateway.event('status.update', 'rt-1', {
        'kind': 'lifecycle',
        'text': '🧠 robot-notes — recalled 5 memories',
      });
      for (var i = 0; i < 17; i++) {
        gateway.event('agent.terminal.output', 'rt-1', {
          'process_id': 'worker-$i',
          'chunk': 'line $i',
        });
      }
      await pumpEventQueue();
    });
    await pumpChat(tester);
    final now = tester.getTopLeft(inPanel(find.text('NOW'))).dy;
    final session = tester.getTopLeft(inPanel(find.text('THIS SESSION'))).dy;
    expect(session, greaterThan(now));
    final cards = tester
        .widgetList<ProcessOutputCard>(inPanel(find.byType(ProcessOutputCard)))
        .length;
    expect(cards, 16);
    for (final card in tester.elementList(
      inPanel(find.byType(ProcessOutputCard)),
    )) {
      final y = tester.getTopLeft(find.byWidget(card.widget)).dy;
      expect(y, inExclusiveRange(now, session));
    }
    final note = tester.getTopLeft(
      inPanel(find.text('Earlier process cards omitted.')),
    );
    expect(note.dy, inExclusiveRange(now, session));
    expect(inPanel(find.byType(MemoryActivityCard)), findsOneWidget);
  });

  testWidgets('closed process cards and a status of a finished turn are '
      'under This session, not Now', (tester) async {
    await tester.runAsync(() async {
      await open('stored-1');
      chat.submit('Start', const []);
      await pumpEventQueue();
      gateway.event('status.update', 'rt-1', {
        'kind': 'process',
        'text': 'Waiting for background process',
      });
      gateway.event('agent.terminal.output', 'rt-1', {
        'process_id': 'done',
        'chunk': 'finished',
      });
      gateway.event('terminal.close', 'rt-1', {'process_id': 'done'});
      gateway.event('agent.terminal.output', 'rt-1', {
        'process_id': 'open',
        'chunk': 'running',
      });
      await pumpEventQueue();
    });
    await pumpChat(tester);
    double y(Finder f) => tester.getTopLeft(inPanel(f)).dy;
    // During the turn: the wait and the open card are Now; the closed card
    // is history.
    expect(inPanel(find.byType(SessionStatusCard)), findsOneWidget);
    final now = y(find.text('NOW')), session = y(find.text('THIS SESSION'));
    expect(y(find.byType(SessionStatusCard)), inExclusiveRange(now, session));
    final running = find.byKey(const ValueKey('open'));
    final done = find.byKey(const ValueKey('done'));
    expect(y(running), inExclusiveRange(now, session));
    expect(y(done), greaterThan(session));

    await tester.runAsync(() async {
      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
      await pumpEventQueue();
    });
    await tester.pump();
    // After it: the old wait is for reference; the card that never closed
    // stays under Now (the backend sends no exit).
    final session2 = y(find.text('THIS SESSION'));
    expect(y(find.byType(SessionStatusCard)), greaterThan(session2));
    expect(y(done), greaterThan(session2));
    expect(y(running), lessThan(session2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  panelTest('Verify billing access is offered only under This session', (
    tester,
  ) async {
    await tester.runAsync(() => open('stored-1'));
    await pumpChat(tester);
    expect(inStrip(find.byType(BillingVerificationCard)), findsNothing);
    expect(inPanel(find.text('THIS SESSION')), findsOneWidget);
    expect(inPanel(find.byType(BillingVerificationCard)), findsOneWidget);
  });

  panelTest('billing the server does not offer leaves the panel', (
    tester,
  ) async {
    await tester.runAsync(() async {
      gateway.handlers['billing.step_up'] = (_) =>
          throw const FakeRpcError(-32601, 'Unsupported');
      await open('stored-1');
      await chat.billingVerificationIn(chat.selectedThread!)!.start();
      await pumpEventQueue();
    });
    await pumpChat(tester);
    expect(find.byType(BillingVerificationCard), findsNothing);
  });

  panelTest('a side answer goes to the panel and stays with its own chat', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await open('stored-1');
      gateway.event('btw.complete', 'rt-1', {
        'task_id': 'side',
        'text': 'Reported answer',
        'question': 'Reported question',
      });
      await pumpEventQueue();
    });
    await pumpChat(tester);
    expect(inStrip(find.byType(SideResultCard)), findsNothing);
    expect(inPanel(find.byType(SideResultCard)), findsOneWidget);

    await tester.runAsync(() => open('stored-2'));
    await tester.pump();
    expect(find.byType(SideResultCard), findsNothing);
  });
}

class _TestAppLock extends AppLockController {
  @override
  bool get covered => false;
}
