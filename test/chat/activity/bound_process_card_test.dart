import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_process_card.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/subagents/subagent_repository.dart';
import 'package:hermes_app/src/chat/subagents/subagent_roster.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_chat_transport.dart';
import '../subagents/subagent_roster_programs_test.dart' show FakeCards;
import '../subagents/subagent_roster_test.dart' show FakeEnv;

/// One program card bound to a real roster: what its stop controller is
/// bound to when the chat, profile or connection changes under it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late FakeEnv env;
  late FakeCards cards;
  late SubagentRoster roster;
  late ChatController chat;
  late AttentionNotifier attention;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport()
      ..agentAnswer = (call) => switch (call.method) {
        'process.list' => {
          'processes': [
            {
              'session_id': 'proc_dev',
              'command': 'npm run dev',
              'status': 'running',
            },
          ],
        },
        'process.kill' => {'status': 'killed'},
        _ => {'subagents': <Object?>[], 'delegations': <Object?>[]},
      };
    env = FakeEnv();
    cards = FakeCards()..frame('proc_dev', 'ready\n');
    roster = SubagentRoster(
      threadId: 'chat-old',
      profile: 'work',
      repository: SubagentRepository(transport),
      env: env,
      programs: cards,
    );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: FakeChatTransport(),
      attention: attention,
      report: (_) {},
    );
  });

  tearDown(() {
    roster.dispose();
    chat.dispose();
    attention.dispose();
  });

  Finder stop() => find.descendant(
    of: find.byType(DestructiveTintButton),
    matching: find.text('Stop program'),
  );

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpCard(WidgetTester tester) async {
    roster.watch();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([roster, cards]),
            builder: (context, _) => SingleChildScrollView(
              child: BoundProcessCard(
                key: const ValueKey('proc_dev'),
                chat: chat,
                output: cards.state.card('proc_dev')!,
                roster: roster,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byType(ProcessOutputCard));
    await settle(tester);
  }

  Future<void> pressStop(WidgetTester tester) async {
    await tester.ensureVisible(stop());
    await tester.tap(stop());
    await settle(tester);
  }

  /// The roster's read timer ends with the test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    roster.dispose();
  }

  List<FakeAgentCall> kills() => [
    for (final call in transport.agentActions)
      if (call.method == 'process.kill') call,
  ];

  testWidgets('a chat id that changed after a cancelled confirmation sends '
      'the kill under the new id', (tester) async {
    await pumpCard(tester);
    await pressStop(tester);
    await tester.tap(dialogText('Cancel'));
    await settle(tester);

    // Compression rotated the chat's stored id; the same roster follows it.
    roster.retarget('chat-new');
    await settle(tester);

    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    expect(kills(), hasLength(1));
    expect(kills().single.threadId, 'chat-new');
    expect(kills().single.profile, 'work');
    await finish(tester);
  });

  testWidgets('a chat id that changes while the confirmation is open sends '
      'no kill', (tester) async {
    await pumpCard(tester);
    await pressStop(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    // Compression rotates the id; the roster follows it without notifying.
    roster.retarget('chat-new');
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(dialogText('Stop program'));
    }
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(kills(), isEmpty);
    await finish(tester);
  });

  testWidgets('"This server can\'t stop programs." goes with the connection '
      'that said it', (tester) async {
    transport.agentAnswer = (call) => call.method == 'process.kill'
        ? throw const GatewayRpcException(kGatewayMethodNotFound, 'x')
        : {
            'processes': [
              {
                'session_id': 'proc_dev',
                'command': 'npm run dev',
                'status': 'running',
              },
            ],
          };
    await pumpCard(tester);
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    expect(find.text("This server can't stop programs."), findsOneWidget);
    expect(stop(), findsNothing);

    env.update(() => env.connection = Object());
    await settle(tester);
    expect(find.text("This server can't stop programs."), findsNothing);
    expect(stop(), findsOneWidget);
    await finish(tester);
  });
}
