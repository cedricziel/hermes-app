import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

/// A branch just made knows its parent before the server's rows say so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late FakeHermesServer server;
  late ChatController chat;

  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final activity = ValueNotifier(true);
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
        ]),
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
      report: (_) {},
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

  ChatThread branchOf() => chat.threads.firstWhere((t) => t.id == 'branch-1');

  test('the result\'s parent names the new chat\'s parent', () async {
    server.on(
      'GET',
      '/api/sessions/branch-1',
      sessionDetailRow(id: 'branch-1', title: 'Run failure #2'),
    );
    transport.branchResult = const BranchedThread('branch-1', parent: 's1');

    await chat.branch(chat.threads.firstWhere((t) => t.id == 's1'));
    await flush();

    expect(chat.selectedThread?.id, 'branch-1');
    expect(branchOf().branchParentId, 's1');
  });

  test('the row\'s own marker wins over the result', () async {
    server.on(
      'GET',
      '/api/sessions/branch-1',
      sessionDetailRow(id: 'branch-1', title: 'Run failure #2')
        ..['_branched_from'] = 'from-row',
    );
    transport.branchResult = const BranchedThread('branch-1', parent: 's1');

    await chat.branch(chat.threads.firstWhere((t) => t.id == 's1'));
    await flush();

    expect(branchOf().branchParentId, 'from-row');
  });

  test('a result without a parent leaves the chat unmarked', () async {
    server.on(
      'GET',
      '/api/sessions/branch-1',
      sessionDetailRow(id: 'branch-1', title: 'Run failure #2'),
    );

    await chat.branch(chat.threads.firstWhere((t) => t.id == 's1'));
    await flush();

    expect(branchOf().branchParentId, isNull);
  });
}
