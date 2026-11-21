import 'dart:async';

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
  var messagesFail = false;

  /// While set, each messages read waits for the test to say how it ends
  /// (true: the page, false: a server error).
  var gating = false;
  final messageCalls = <Completer<bool>>[];

  setUp(() {
    messagesFail = false;
    gating = false;
    messageCalls.clear();
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
          if (messagesFail) return (status: 500, body: {'detail': 'down'});
          if (gating) {
            final call = Completer<bool>();
            messageCalls.add(call);
            if (!await call.future) {
              return (status: 500, body: {'detail': 'down'});
            }
          }
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
    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Done.'));
    transport.active.clear();
    transport.activeInProfile['default'] = {};
    await chat.refreshActive();
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isFalse);
    expect(lastAssistant(thread).status, MessageStatus.sent);
    expect(lastAssistant(thread).content, 'Done.');
  });

  test(
    'a hold released after a read that found the stored answer re-reads '
    'the thread, so the failed bubble goes and Retry does not stay on',
    () async {
      final thread = await heldTurn('default');
      stored
        ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
        ..add(messageRow(id: 4, role: 'assistant', content: 'Done.'));
      // Read during the hold: the failed bubble is kept.
      await chat.refreshThread('s1');
      await pumpEventQueue();
      expect(chat.turnActionsHeld(thread), isTrue);

      transport.active.clear();
      transport.activeInProfile['default'] = {};
      await chat.refreshActive();
      await pumpEventQueue();

      expect(chat.turnActionsHeld(thread), isFalse);
      expect(
        thread.messages.where((m) => m.status == MessageStatus.error),
        isEmpty,
      );
      expect(lastAssistant(thread).content, 'Done.');
      expect(transport.sends, hasLength(1));
      expect(transport.undos, isEmpty);
    },
  );

  test('a release whose re-read fails keeps Retry and Edit held, and the next '
      'poll lands the read and releases', () async {
    final thread = await heldTurn('default');
    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Done.'));
    // Read during the hold: the failed bubble is kept.
    await chat.refreshThread('s1');
    await pumpEventQueue();
    transport.active.clear();
    transport.activeInProfile['default'] = {};

    messagesFail = true;
    await chat.refreshActive();
    await pumpEventQueue();

    // The stale bubble may still be on screen: nothing is enabled.
    expect(chat.turnActionsHeld(thread), isTrue);
    expect(chat.canEditLastPrompt(thread), isFalse);
    await chat.retry(thread);
    await chat.editLastPrompt(thread);
    expect(transport.undos, isEmpty);
    expect(transport.sends, hasLength(1));

    messagesFail = false;
    await chat.refreshActive();
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isFalse);
    expect(
      thread.messages.where((m) => m.status == MessageStatus.error),
      isEmpty,
    );
    expect(lastAssistant(thread).content, 'Done.');
    expect(transport.sends, hasLength(1));
    expect(transport.undos, isEmpty);
  });

  test('an idle answer that predates a newer turn does not release that '
      "turn's hold", () async {
    final thread = await heldTurn('default');
    // A's hold is asked about; the server says idle, but the answer is slow.
    transport
      ..active.clear()
      ..activeInProfile['default'] = {}
      ..answeredGate = Completer<void>();
    final gate = transport.answeredGate!;
    final probe = chat.refreshActive();
    await pumpEventQueue();

    // B is sent meanwhile and ends where the server may still run it.
    chat.submit('And again', const []);
    final second = transport.sends.last;
    transport.active['s1'] = 'working';
    transport.activeInProfile['default'] = {'s1': 'working'};
    second.fail(const GatewayReplyUnconfirmed());
    await pumpEventQueue();
    expect(chat.turnActionsHeld(thread), isTrue);

    gate.complete();
    await probe;
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isTrue);
    expect(chat.canEditLastPrompt(thread), isFalse);
    expect(transport.undos, isEmpty);
    expect(transport.sends, hasLength(2));
  });

  /// The stored rows of both turns: each answered.
  void storeBothTurns() {
    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Done.'))
      ..add(messageRow(id: 5, role: 'user', content: 'And again'))
      ..add(messageRow(id: 6, role: 'assistant', content: 'Partial.'));
  }

  test('a send that starts and fails unconfirmed while the release re-read '
      'waits keeps its held bubble and its hold', () async {
    final thread = await heldTurn('default');
    storeBothTurns();
    transport
      ..active.clear()
      ..activeInProfile['default'] = {};
    gating = true;
    final probe = chat.refreshActive();
    await pumpEventQueue();
    expect(messageCalls, hasLength(1));

    // B is sent while the read waits, and ends where the server may run it.
    chat.submit('And again', const []);
    transport.active['s1'] = 'working';
    transport.activeInProfile['default'] = {'s1': 'working'};
    transport.sends.last.fail(const GatewayReplyUnconfirmed());
    await pumpEventQueue();
    expect(chat.turnActionsHeld(thread), isTrue);

    messageCalls.first.complete(true);
    await probe;
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isTrue);
    expect(chat.canEditLastPrompt(thread), isFalse);
    expect(lastAssistant(thread).status, MessageStatus.error);
    expect(transport.sends, hasLength(2));
    expect(transport.undos, isEmpty);
  });

  test('an ordinary re-read that is already waiting when a release starts '
      'keeps the held bubble, even if the release read then fails', () async {
    final thread = await heldTurn('default');
    stored
      ..add(messageRow(id: 3, role: 'user', content: 'Run the build'))
      ..add(messageRow(id: 4, role: 'assistant', content: 'Partial.'));
    transport
      ..active.clear()
      ..activeInProfile['default'] = {};
    gating = true;
    final ordinary = chat.refreshThread('s1');
    await pumpEventQueue();
    final probe = chat.refreshActive();
    await pumpEventQueue();
    expect(messageCalls, hasLength(2));

    // The ordinary read lands first, while the release read is in flight.
    messageCalls[0].complete(true);
    await ordinary;
    await pumpEventQueue();
    messageCalls[1].complete(false);
    await probe;
    await pumpEventQueue();

    expect(chat.turnActionsHeld(thread), isTrue);
    expect(lastAssistant(thread).status, MessageStatus.error);
    expect(transport.sends, hasLength(1));
    expect(transport.undos, isEmpty);
  });

  test('a ask that throws releases nothing and does not throw', () async {
    final thread = await heldTurn('default');
    transport.answeredError = StateError('bug');

    expect(await chat.refreshActive(), isTrue);

    expect(chat.turnActionsHeld(thread), isTrue);
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
