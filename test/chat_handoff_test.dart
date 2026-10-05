import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_chat_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late ChatController chat;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'home'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'same', title: 'Home')]),
        query: {'profile': 'home'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions/same',
        sessionRow(id: 'same', title: 'Work'),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions/same/messages',
        messageListBody('same', [
          messageRow(id: 1, role: 'assistant', content: 'Work history'),
        ]),
        query: {'profile': 'work'},
      );
    final api = server.client().raw;
    chat = ChatController(
      repository: HermesChatRepository(api),
      profiles: HermesProfilesRepository(api),
      transport: FakeChatTransport(),
      attention: AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      ),
      report: (_) {},
    );
  });
  tearDown(() => chat.dispose());
  test('restores an older thread with exact profile ownership', () async {
    await chat.loadThreads('home');
    expect(
      await chat.restoreHandoff(
        const NotificationTarget(threadId: 'same', profile: 'work'),
        () => true,
      ),
      isTrue,
    );
    expect(chat.profile, 'work');
    expect(chat.selectedThread?.title, 'Work');
    expect(chat.selectedThread?.messages.single.content, 'Work history');
    expect(
      server
          .requestsTo('GET', '/api/sessions/same/messages')
          .single
          .queryParameters['profile'],
      'work',
    );
  });
  test('missing profile never falls back to another profile', () async {
    await chat.loadThreads('home');
    expect(
      await chat.restoreHandoff(
        const NotificationTarget(threadId: 'same', profile: 'missing'),
        () => true,
      ),
      isFalse,
    );
    expect(chat.profile, 'home');
    expect(server.requestsTo('GET', '/api/sessions/same/messages'), isEmpty);
  });
  test('continuing a locally running chat preserves its live reply', () async {
    await chat.loadThreads('home');
    final thread = chat.threads.single;
    final reply = ChatMessage(
      id: 'live',
      role: ChatRole.assistant,
      content: 'Still replying',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    thread.messages.add(reply);
    expect(
      await chat.restoreHandoff(
        const NotificationTarget(threadId: 'same', profile: 'home'),
        () => true,
      ),
      isTrue,
    );
    expect(chat.selectedThread?.messages.single, same(reply));
    expect(server.requestsTo('GET', '/api/sessions/same/messages'), isEmpty);
  });
  test('missing thread does not create a replacement', () async {
    server.on('GET', '/api/sessions/gone', {
      'detail': 'not found',
    }, status: 404);
    await chat.loadThreads('home');
    expect(
      await chat.restoreHandoff(
        const NotificationTarget(threadId: 'gone', profile: 'work'),
        () => true,
      ),
      isFalse,
    );
    expect(chat.profile, 'home');
  });
  test('denied history propagates failure without selecting a chat', () async {
    server.on(
      'GET',
      '/api/sessions/same/messages',
      {'detail': 'denied'},
      status: 403,
      query: {'profile': 'work'},
    );
    await chat.loadThreads('home');
    expect(
      chat.restoreHandoff(
        const NotificationTarget(threadId: 'same', profile: 'work'),
        () => true,
      ),
      throwsException,
    );
    await pumpEventQueue();
    expect(chat.profile, 'home');
  });
  test('navigation cancels a delayed profile switch', () async {
    final release = Completer<FakeResponse>();
    final requested = Completer<void>();
    await chat.loadThreads('home');
    server.onRequest('GET', '/api/sessions', (_) {
      requested.complete();
      return release.future;
    }, query: {'profile': 'work'});
    var valid = true;
    final restoring = chat.restoreHandoff(
      const NotificationTarget(threadId: 'same', profile: 'work'),
      () => valid,
    );
    await requested.future;
    valid = false;
    release.complete((status: 200, body: sessionListBody([])));
    expect(await restoring, isFalse);
    expect(chat.profile, 'home');
  });
  test('cancelled restoration cannot select its target', () async {
    await chat.loadThreads('home');
    expect(
      await chat.restoreHandoff(
        const NotificationTarget(threadId: 'same', profile: 'work'),
        () => false,
      ),
      isFalse,
    );
    expect(chat.profile, 'home');
  });
}
