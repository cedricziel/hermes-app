import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_notification_service.dart';

/// A subagent delegated in the background outlives the reply that spawned it:
/// its later frames arrive on the follow-ups, and belong to that reply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late ChatController chat;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: FakeNotificationService(),
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  const spawned = SubagentUpdated(
    Subagent(id: 'sa-0', goal: 'Run a quick connectivity check'),
  );
  const finished = SubagentUpdated(
    Subagent(
      id: 'sa-0',
      goal: 'Run a quick connectivity check',
      status: SubagentStatus.completed,
      summary: 'host 9d36ee89d0cb',
    ),
  );

  /// Sends a prompt whose reply spawns a background subagent and ends.
  Future<(ChatThread, ChatMessage, FakeFollowUps)> delegate() async {
    chat.newThread();
    chat.submit('Launch a test subagent', const []);
    transport.sends.last
      ..emit(const ThreadBound('s1'))
      ..emit(const ReplyStarted())
      ..emit(spawned)
      ..emit(const ReplyCompleted('It will report back.'))
      ..finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    final reply = thread.messages.last;
    expect(reply.subagents.single.status, SubagentStatus.running);
    return (thread, reply, transport.followUpStreams['s1']!);
  }

  test(
    'a completion between turns finishes the subagent of its reply',
    () async {
      final (thread, reply, follow) = await delegate();

      follow.emit(finished);
      await pumpEventQueue();

      expect(reply.subagents.single.status, SubagentStatus.completed);
      expect(reply.subagents.single.summary, 'host 9d36ee89d0cb');
      expect(thread.messages.where((m) => m.role == ChatRole.assistant), [
        reply,
      ]);
    },
  );

  test('a completion during the next turn finishes the subagent of the reply '
      'that spawned it', () async {
    final (thread, reply, follow) = await delegate();

    follow
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('The test subagent finished.'))
      ..emit(finished);
    await pumpEventQueue();

    final next = thread.messages.last;
    expect(next, isNot(same(reply)));
    expect(reply.subagents.single.status, SubagentStatus.completed);
    expect(next.subagents, isEmpty);
  });
}
