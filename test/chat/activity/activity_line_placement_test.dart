import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/activity/bound_needs_you_dock.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_dock.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_card.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_attachment_source.dart';
import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';
import '../billing_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Busy chat')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', []),
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  testWidgets('with a plan, a process, usage and a billing request together, '
      'only the line sits between the header and the transcript', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      chat.submit('Start', const []);
      await pumpEventQueue();
      gateway.event('todo.updated', 'rt-1', {
        'revision': 1,
        'todos': [
          {'id': 'a', 'content': 'Draft', 'status': 'completed'},
          {'id': 'b', 'content': 'Review', 'status': 'in_progress'},
        ],
      });
      gateway.event('agent.terminal.output', 'rt-1', {
        'process_id': 'worker',
        'chunk': 'compiling',
      });
      gateway.event('session.usage', 'rt-1', {
        'usage': {'total': 8, 'cost_usd': 0.2},
      });
      gateway.event(
        'billing.step_up.verification',
        'rt-1',
        billingVerificationFixture,
      );
      await pumpEventQueue();
    });
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    final queue = needsYouQueueFor(chat);
    for (final dispose in [
      composer.dispose,
      focus.dispose,
      latest.dispose,
      queue.dispose,
    ]) {
      addTearDown(dispose);
    }
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                key: const Key('thread-side'),
                child: boundChatThreadView(
                  chat: chat,
                  thread: chat.selectedThread,
                  header: const SizedBox(key: Key('header'), height: 56),
                  composerController: composer,
                  composerFocus: focus,
                  attachments: const [],
                  attachmentSource: FakeAttachmentSource(),
                  onAddAttachments: (_) {},
                  onRemoveAttachment: (_) {},
                  onSend: (_) {},
                  latestReply: latest,
                  welcome: false,
                  needsYou: queue,
                  onOpenActivity: () {},
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
    );
    await tester.pump();

    Finder inThread(Finder finder) => find.descendant(
      of: find.byKey(const Key('thread-side')),
      matching: finder,
    );
    Finder inPanel(Finder finder) => find.descendant(
      of: find.byKey(const Key('activity-panel')),
      matching: finder,
    );

    // Header, then the line, then the transcript, with nothing between.
    final header = tester.getRect(find.byKey(const Key('header')));
    final line = tester.getRect(find.byKey(const Key('activity-line')));
    final transcript = tester.getRect(find.byType(Chat));
    expect(line.top, moreOrLessEquals(header.bottom + 1, epsilon: 1));
    expect(transcript.top, moreOrLessEquals(line.bottom, epsilon: 1));
    expect(
      inThread(find.byKey(const Key('chat-activity-strip'))),
      findsNothing,
    );

    // Billing is docked above the composer.
    final dock = tester.getRect(find.byType(NeedsYouDock));
    expect(
      dock.bottom,
      moreOrLessEquals(
        tester.getRect(find.byType(ChatComposer)).top,
        epsilon: 0.5,
      ),
    );

    // The rest is in the panel, and none of it in the thread.
    for (final card in [
      find.byType(TodoPlanCard),
      find.byType(ProcessOutputCard),
      find.byType(SessionUsageCard),
    ]) {
      expect(inThread(card), findsNothing);
      expect(inPanel(card), findsOneWidget);
    }
    expect(inPanel(find.byType(NeedsYouDock)), findsNothing);
    // The line says the process runs and keeps the plan counter beside it.
    expect(
      find.descendant(
        of: find.byKey(const Key('activity-line')),
        matching: find.text('Process running'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity-chip-plan')), findsOneWidget);
  });
}
