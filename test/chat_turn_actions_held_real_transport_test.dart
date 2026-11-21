import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_gateway.dart';

/// What releases Retry and Edit of a reply whose turn the server may still
/// run, with the REAL transport: only a real `session.active_list` answer that
/// does not list the session as running. Offline, an error, an unreadable
/// answer and a missing list are not that, however the transport reports them
/// to its other callers (an empty map).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGateway gateway;
  late ChatController chat;
  late ChatThread thread;
  var offline = false;

  setUp(() {
    offline = false;
    gateway = FakeGateway();
    final transport = HermesGatewayTransport(
      connect: () async {
        if (offline) throw const GatewayConnectionClosed();
        return gateway.channel;
      },
    );
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    chat.newThread();
    thread = chat.selectedThread!;
    // A reply that ended on a lost connection, as the controller leaves it.
    thread.messages
      ..add(
        ChatMessage(
          id: 'u',
          role: ChatRole.user,
          content: 'Run the build',
          createdAt: DateTime(2026),
        ),
      )
      ..add(
        ChatMessage(
          id: 'a',
          role: ChatRole.assistant,
          content: 'Starting. ',
          createdAt: DateTime(2026),
          status: MessageStatus.error,
          failure: ReplyFailure.generic,
        )..serverMayRun = true,
      );
  });

  Future<void> expectHeld(bool held) async {
    await chat.refreshActive();
    await pumpEventQueue();
    expect(chat.turnActionsHeld(thread), held);
    expect(chat.turnActionStatus(thread).held, held);
    expect(gateway.methods.where((m) => m == 'prompt.submit'), isEmpty);
    expect(gateway.methods.where((m) => m == 'session.undo'), isEmpty);
  }

  group('the hold stays when the server did not really answer', () {
    test('the socket is down', () async {
      offline = true;
      await expectHeld(true);
    });

    test('the method answers an error', () async {
      gateway.handlers['session.active_list'] = (_) =>
          throw const FakeRpcError(5036, 'could not enumerate');
      await expectHeld(true);
    });

    test('an older server does not know the method', () async {
      gateway.handlers['session.active_list'] = (_) =>
          throw const FakeRpcError(-32601, 'unknown method');
      await expectHeld(true);
    });

    test('the answer is not an object', () async {
      gateway.handlers['session.active_list'] = (_) => 'not an object';
      await expectHeld(true);
    });

    test('the answer has no list of sessions', () async {
      gateway.handlers['session.active_list'] = (_) => <String, Object?>{};
      await expectHeld(true);
    });
  });

  group('the hold stays while the server lists the session as running', () {
    for (final status in [
      'starting',
      'waiting',
      'working',
      'streaming',
      'resuming',
    ]) {
      test(status, () async {
        gateway.activeSessions = {thread.id: status};
        await expectHeld(true);
      });
    }
  });

  group('two rows of one session: a running one wins over an idle one', () {
    for (final order in [
      ['working', 'idle'],
      ['idle', 'working'],
    ]) {
      test(order.join(' then '), () async {
        gateway.handlers['session.active_list'] = (_) => {
          'sessions': [
            for (final status in order)
              {'session_key': thread.id, 'status': status},
          ],
        };
        await expectHeld(true);
      });
    }
  });

  group('the hold ends on a real answer that does not list it as running', () {
    test('a list without the session', () async {
      gateway.activeSessions = {'someone-else': 'working'};
      await expectHeld(false);
    });

    test('an empty list', () async {
      gateway.activeSessions = {};
      await expectHeld(false);
    });

    test('the session listed as idle', () async {
      gateway.activeSessions = {thread.id: 'idle'};
      await expectHeld(false);
    });
  });
}
