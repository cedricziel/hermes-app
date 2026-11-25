import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

/// One idempotency key per branch the user asks for, reused only when the
/// answer to that very branch was lost; and no Branch action once the server
/// has said it cannot branch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late FakeHermesServer server;
  late ChatController chat;
  late List<String> reported;
  late ValueNotifier<bool> activity;

  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ChatThread parent() => chat.threads.firstWhere((t) => t.id == 's1');

  /// The id of the nth message of the open chat, for "branch from here".
  String messageId(int index) => parent().messages[index].id;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    activity = ValueNotifier(true);
    reported = [];
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
          messageRow(id: 3, role: 'user', content: 'Can you retry it?'),
          messageRow(id: 4, role: 'assistant', content: 'It passed this time.'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/branch-1',
        sessionDetailRow(id: 'branch-1', title: 'Run failure #2'),
      )
      ..on(
        'GET',
        '/api/sessions/branch-1/messages',
        messageListBody('branch-1', const []),
      );
    final notifications = FakeNotificationService();
    final attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      activity: activity,
      transport: transport,
      repository: HermesChatRepository(server.client().raw),
      attention: attention,
      report: reported.add,
    );
    addTearDown(chat.dispose);
    addTearDown(activity.dispose);
    addTearDown(notifications.dispose);
    addTearDown(attention.dispose);
    await chat.loadThreads();
    await flush();
    chat.select('s1');
    await flush();
  });

  group('idempotency key', () {
    test('two separate branches send different keys', () async {
      await chat.branch(parent());
      await flush();
      chat.select('s1');
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys, hasLength(2));
      expect(transport.branchKeys, everyElement(isNotEmpty));
      expect(transport.branchKeys[0], isNot(transport.branchKeys[1]));
    });

    test('a branch whose answer was lost keeps its key for the next tap, '
        'and a later branch gets a new one', () async {
      transport.branchError = const GatewayCallTimedOut();
      await chat.branch(parent());
      await flush();
      await chat.branch(parent());
      await flush();

      transport.branchError = null;
      await chat.branch(parent());
      await flush();
      chat.select('s1');
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys, hasLength(4));
      expect(transport.branchKeys[1], transport.branchKeys[0]);
      expect(transport.branchKeys[2], transport.branchKeys[0]);
      expect(transport.branchKeys[3], isNot(transport.branchKeys[0]));
    });

    test('a branch Hermes refused does not lend its key', () async {
      transport.branchError = GatewayRpcException(5008, 'no');
      await chat.branch(parent());
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys[1], isNot(transport.branchKeys[0]));
    });

    test('a lost answer lends its key to the same branch point only', () async {
      transport.branchError = const GatewayCallTimedOut();
      await chat.branch(parent(), fromMessageId: messageId(1));
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys[1], isNot(transport.branchKeys[0]));
    });

    test('a lost answer lends its key only while the chat has not '
        'moved on', () async {
      transport.branchError = const GatewayCallTimedOut();
      await chat.branch(parent());
      await flush();
      transport.branchError = null;
      chat.threads
          .firstWhere((t) => t.id == 's1')
          .messages
          .add(
            ChatMessage(
              id: 'later',
              role: ChatRole.assistant,
              content: 'Another reply',
              createdAt: DateTime(2026),
            ),
          );
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys[1], isNot(transport.branchKeys[0]));
    });

    test('a branch whose answer comes after the session changed keeps '
        'nothing', () async {
      final gate = transport.branchGate = Completer<void>();
      transport.branchError = const GatewayCallTimedOut();
      final branching = chat.branch(parent());
      await flush();

      activity.value = false;
      await flush();
      activity.value = true;
      await flush();
      gate.complete();
      await branching;
      transport
        ..branchGate = null
        ..branchError = null;
      chat.select('s1');
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys, hasLength(2));
      expect(transport.branchKeys[1], isNot(transport.branchKeys[0]));
    });

    test('an incomplete copy does not lend its key', () async {
      server.on('DELETE', '/api/sessions/branch-1', {'ok': true});
      transport.branchError = BranchIncomplete(
        const BranchedThread('branch-1'),
        const GatewayCallTimedOut(),
      );
      await chat.branch(parent());
      await flush();
      await chat.branch(parent());
      await flush();

      expect(transport.branchKeys[1], isNot(transport.branchKeys[0]));
    });
  });

  group('Branch offered', () {
    test('while the server has not said anything', () {
      expect(transport.branchSupported, isNull);
      expect(chat.canBranch(parent()), isTrue);
    });

    test('while the server can branch', () {
      transport.branchSupported = true;
      expect(chat.canBranch(parent()), isTrue);
    });

    test('not once the server cannot branch', () {
      transport.branchSupported = false;
      expect(chat.canBranch(parent()), isFalse);
    });

    test('not after a branch found the server unable to', () async {
      transport.branchResult = null;
      await chat.branch(parent());
      await flush();

      expect(reported, [
        "This Hermes server can't branch chats. Update Hermes to branch.",
      ]);
      expect(chat.canBranch(parent()), isFalse);
    });
  });
}
