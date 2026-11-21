import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// A held reply survives a re-read of the thread, and is asked about for the
/// chat's own profile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ChatController chat;
  late List<Map<String, Object?>> stored;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    stored = [
      messageRow(id: 1, role: 'user', content: 'Earlier'),
      messageRow(id: 2, role: 'assistant', content: 'Earlier reply'),
    ];
    for (final profile in ['default', 'work']) {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Run')]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/s1',
          sessionRow(id: 's1', title: 'Run'),
          query: {'profile': profile},
        )
        ..onRequest('GET', '/api/sessions/s1/messages', (_) async {
          return (status: 200, body: messageListBody('s1', List.of(stored)));
        });
    }
    transport = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
      reconnectRetry: const Duration(hours: 1),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  /// A prompt in the open chat whose turn ends on a lost connection while the
  /// server still lists the session as working.
  Future<ChatThread> heldTurn(String profile) async {
    await chat.loadThreads(profile);
    chat.select('s1');
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    chat.submit('Run the build', const []);
    transport.active['s1'] = 'working';
    transport.activeInProfile[profile] = {'s1': 'working'};
    transport.sends.single.fail(const GatewayTurnEnded());
    await pumpEventQueue();
    expect(chat.turnActionsHeld(thread), isTrue);
    return thread;
  }

  ChatMessage lastAssistant(ChatThread thread) =>
      thread.messages.lastWhere((m) => m.role == ChatRole.assistant);

  test('a re-read that already holds a stored row of the running turn keeps '
      'the held reply, so Retry and Edit stay off', () async {
    final thread = await heldTurn('default');

    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Partial answer'));
    await chat.refreshThread('s1');
    await pumpEventQueue();

    expect(lastAssistant(thread).status, MessageStatus.error);
    expect(chat.turnActionsHeld(thread), isTrue);
    expect(chat.canEditLastPrompt(thread), isFalse);
    expect(transport.sends, hasLength(1));
    expect(transport.undos, isEmpty);
  });

  test('once the server says the turn is over, the re-read drops the reply '
      'for the stored one', () async {
    final thread = await heldTurn('default');
    transport.active.clear();
    transport.activeInProfile['default'] = {};
    await chat.refreshActive();
    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Done.'));

    await chat.refreshThread('s1');
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isFalse);
    expect(lastAssistant(thread).status, MessageStatus.sent);
    expect(lastAssistant(thread).content, 'Done.');
  });

  test("the hold of a chat on another profile is asked about for that "
      "profile, and is kept until its own list answers", () async {
    final thread = await heldTurn('work');
    // The default profile's list says nothing runs; the chat's own does.
    transport.active.clear();
    transport.activeAsked.clear();

    await chat.refreshActive();
    expect(chat.turnActionsHeld(thread), isTrue);
    expect(transport.activeAsked, contains('work'));

    transport.activeInProfile['work'] = {};
    await chat.refreshActive();
    expect(chat.turnActionsHeld(thread), isFalse);
  });
}
