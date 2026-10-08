import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// Text the user wrote or named; none of it may reach a breadcrumb.
const _prompt = 'my secret prompt';
const _reply = 'my secret reply';
const _title = 'Private roadmap';
const _profileName = 'work-secrets';
const _threadId = 'thread-id-77';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BreadcrumbTrail trail;
  late FakeChatTransport transport;
  late FakeHermesServer server;
  late ChatController chat;

  List<String> names() => [for (final c in trail.recent) c.name];

  Map<String, Object> last(String name) =>
      trail.recent.lastWhere((c) => c.name == name).attributes;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail(capacity: 100);
    transport = FakeChatTransport();
    server = FakeHermesServer();
    for (final profile in ['default', _profileName]) {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: _threadId, title: _title)]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/$_threadId/messages',
          messageListBody(_threadId, [
            messageRow(id: 1, role: 'user', content: _prompt),
          ]),
          query: {'profile': profile},
        );
    }
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
      breadcrumbs: Breadcrumbs.of(trail),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  test(
    'loading threads and switching profile leave a crumb with counts',
    () async {
      await chat.loadThreads('default');
      expect(last('chat.threads.loaded'), {'switched': true, 'count': 1});

      await chat.loadThreads('default');
      expect(last('chat.threads.loaded'), {'switched': false, 'count': 1});

      await chat.loadThreads(_profileName);
      expect(last('chat.threads.loaded'), {'switched': true, 'count': 1});
    },
  );

  test('a failed thread load leaves a crumb', () async {
    server.on(
      'GET',
      '/api/sessions',
      {'detail': 'x'},
      status: 500,
      query: {'profile': 'nowhere'},
    );
    await chat.loadThreads('nowhere');

    expect(names(), contains('chat.threads.failed'));
  });

  test('opening, creating and closing a chat leave a crumb', () async {
    await chat.loadThreads('default');
    chat.select(_threadId);
    expect(last('chat.thread.selected'), {'remote': true});

    chat.newThread();
    expect(names().last, 'chat.thread.new');

    chat.clearSelection();
    expect(names().last, 'chat.thread.closed');
  });

  test('a chat asked for from outside leaves a crumb', () async {
    await chat.loadThreads('default');
    chat.open(
      const NotificationTarget(threadId: 'missing', profile: 'default'),
      fetchMissing: false,
    );

    expect(last('chat.open.requested'), {'fetch_missing': false});
    expect(names(), contains('chat.open.failed'));
  });

  test('a reply leaves a started and an ended crumb', () async {
    chat.newThread();
    chat.submit(_prompt, const []);
    expect(last('chat.reply.started'), {'queued': false, 'attachments': 0});

    transport.sends.single
      ..emit(const ReplyDelta(_reply))
      ..emit(const ReplyCompleted(_reply))
      ..finish();
    await pumpEventQueue();

    expect(last('chat.reply.ended'), {'outcome': 'completed'});
  });

  test('a send that fails ends the reply as failed', () async {
    chat.newThread();
    chat.submit(_prompt, const []);
    transport.sends.single.fail(StateError(_reply));
    await pumpEventQueue();

    expect(last('chat.reply.ended'), {'outcome': 'failed'});
  });

  test('a reply that ends without a completion is failed', () async {
    chat.newThread();
    chat.submit(_prompt, const []);
    transport.sends.single.finish();
    await pumpEventQueue();

    expect(last('chat.reply.ended'), {'outcome': 'failed'});
  });

  test('a stopped reply ends as stopped', () async {
    chat.newThread();
    chat.submit(_prompt, const []);
    transport.sends.single
      ..emit(const ReplyCompleted(_reply, stopped: true))
      ..finish();
    await pumpEventQueue();

    expect(last('chat.reply.ended'), {'outcome': 'stopped'});
  });

  test(
    'no crumb carries a prompt, a reply, a title, a profile or an id',
    () async {
      await chat.loadThreads(_profileName);
      chat.select(_threadId);
      chat.newThread();
      chat.submit(_prompt, const []);
      transport.sends.single
        ..emit(const ReplyCompleted(_reply))
        ..finish();
      await pumpEventQueue();
      chat.clearSelection();

      expect(trail.recent, isNotEmpty);
      final text = trail.recent.map((c) => c.toString()).join('\n');
      for (final secret in [_prompt, _reply, _title, _profileName, _threadId]) {
        expect(text, isNot(contains(secret)));
      }
    },
  );
}
