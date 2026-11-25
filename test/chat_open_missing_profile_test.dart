import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

/// A chat that is fetched because the loaded list lacks it must not land in a
/// profile the user has since switched to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'a missing chat that arrives after a profile switch is dropped',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final gate = Completer<FakeResponse>();
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'w1', title: 'Work chat')]),
          query: {'profile': 'work'},
        )
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'h1', title: 'Home chat')]),
          query: {'profile': 'home'},
        )
        ..onRequest('GET', '/api/sessions/old', (_) => gate.future)
        ..on('GET', '/api/sessions/old/messages', messageListBody('old', []))
        ..on('GET', '/api/sessions/h1/messages', messageListBody('h1', []));
      final activity = ValueNotifier(true);
      final notifications = FakeNotificationService();
      final attention = AttentionNotifier(
        service: notifications,
        settings: null,
        onOpen: (_) {},
      );
      final chat = ChatController(
        activity: activity,
        transport: FakeChatTransport(),
        repository: HermesChatRepository(server.client().raw),
        attention: attention,
        report: (_) {},
      );
      addTearDown(chat.dispose);
      addTearDown(activity.dispose);
      addTearDown(notifications.dispose);
      addTearDown(attention.dispose);
      await chat.loadThreads('work');
      await flush();

      chat.open(
        const NotificationTarget(threadId: 'old', profile: 'work'),
        fetchMissing: true,
      );
      await flush();
      await chat.loadThreads('home');
      await flush();
      expect(chat.profile, 'home');

      gate.complete((
        status: 200,
        body: sessionDetailRow(id: 'old', title: 'Old chat'),
      ));
      await flush();

      expect(chat.threads.map((t) => t.id), ['h1']);
      expect(chat.selectedThread?.id, isNot('old'));
    },
  );
}
