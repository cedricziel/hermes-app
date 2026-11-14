import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_needs_you_dock.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/live_activities/live_activity_state.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';

/// `WorkspaceBound` is a `ChatEvent`. It reports where Hermes started a chat,
/// before the prompt is submitted, and says nothing about the reply: no
/// consumer of the event stream may read it as a turn, a request or a
/// completion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bound = WorkspaceBound(cwd: '/srv/demo', branch: 'main');

  test('it is not a turn, a request or an end', () {
    expect(beginsTurn(bound), isFalse);
    expect(opensTurn(bound), isFalse);
  });

  test('a Live Activity or watch complication keeps its state', () {
    for (final state in ReplyActivityState.values) {
      expect(nextActivityState(state, bound), state);
    }
  });

  group('in a chat', () {
    late ChatController chat;
    late FakeChatTransport transport;
    late AttentionNotifier attention;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]));
      transport = FakeChatTransport();
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
      await chat.loadThreads();
    });

    tearDown(() {
      chat.dispose();
      attention.dispose();
    });

    test('it opens no reply, request, subagent or queued prompt, and the '
        'Needs-you dock stays empty', () async {
      final queue = needsYouQueueFor(chat);
      addTearDown(queue.dispose);
      chat.newThread();
      await chat.submit('hello', const []);
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final messages = thread.messages.length;

      transport.sends.last
        ..emit(const ThreadBound('s1'))
        ..emit(bound);
      await pumpEventQueue();

      expect(thread.workingDirectory, '/srv/demo');
      expect(thread.branch, 'main');
      expect(thread.messages.length, messages);
      expect(queue.count, 0);
      expect(chat.queuedIn(thread), isEmpty);
      expect(chat.workspaceMismatchOf(thread), isNull);
    });

    test('it does not end the reply the way a completion does', () async {
      chat.newThread();
      await chat.submit('hello', const []);
      await pumpEventQueue();
      final thread = chat.selectedThread!;

      transport.sends.last
        ..emit(const ThreadBound('s1'))
        ..emit(bound);
      await pumpEventQueue();

      expect(thread.isReplying, isTrue);
      transport.sends.last
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();
      expect(thread.isReplying, isFalse);
    });
  });
}
