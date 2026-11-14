import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_change_feed.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_session_auth.dart';
import 'support/pump_chat.dart';

class _ChatFeed extends FakeChatTransport
    implements GatewayConnectionTransport {
  final changes = FakeChangeFeed();
  @override
  Stream<GatewayConnectionEvent> get connectionEvents =>
      changes.connectionEvents;
  @override
  Object? get gatewayConnection => changes.gatewayConnection;
  @override
  bool ownsGatewayConnection(Object connection) =>
      changes.ownsGatewayConnection(connection);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'the real chat view refreshes its sidebar without replacing the composer draft',
    (tester) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/profiles/active', {
          'active': 'work',
          'current': 'work',
        })
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Before change')]),
        )
        ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []));
      final auth = FakeSessionAuth();
      final source = _ChatFeed();
      addTearDown(auth.dispose);
      addTearDown(source.changes.close);
      await pumpChatScreen(
        tester,
        server: server,
        withProfiles: true,
        transport: source,
        providers: [ChangeNotifierProvider<AuthController>.value(value: auth)],
      );
      await openThread(tester, 'Before change');
      await tester.enterText(composerField, 'Synthetic unsaved draft');
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'External title')]),
      );
      source.changes.hint('sessions.changed');
      await tester.pumpAndSettle();
      expect(find.text('External title'), findsWidgets);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Synthetic unsaved draft',
      );
      expect(source.sends, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  test('complete-list absence retains selected in-flight queues and never rebinds their target', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Owned target')]),
      );
    final source = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: source,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    await chat.loadThreads('work');
    chat.select('s1');
    chat.submit('Current turn', const []);
    chat.submit('Queued prompt', const []);
    final target = chat.selectedThread!;
    final generation = chat.threadListGeneration;
    expect(
      chat.applyInvalidatedThreads(
        const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
        profile: 'work',
        generation: generation,
      ),
      true,
    );
    expect(chat.selectedThread, same(target));
    expect(target.id, 's1');
    expect(target.remote, true);
    expect(chat.threadListAvailable(target), false);
    expect(chat.queuedIn(target).single.text, 'Queued prompt');
    expect(source.sends, hasLength(1));
  });

  test(
    'a partial page does not prove absence and stale generation cannot apply',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Owned target')]),
        );
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      final chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        attention: attention,
        report: (_) {},
      );
      addTearDown(() {
        chat.dispose();
        attention.dispose();
      });
      await chat.loadThreads('work');
      final target = chat.threads.single;
      expect(
        chat.applyInvalidatedThreads(
          const ThreadPage(threads: [], nextOffset: 50, hasMore: true),
          profile: 'work',
          generation: chat.threadListGeneration,
        ),
        true,
      );
      expect(chat.threads.single, same(target));
      expect(chat.threadListAvailable(target), true);
      final fresh = ChatThread(
        id: 's1',
        title: 'Rejected title',
        updatedAt: DateTime(2026),
        remote: true,
      );
      expect(
        chat.applyInvalidatedThreads(
          ThreadPage(threads: [fresh], nextOffset: 50, hasMore: false),
          profile: 'work',
          generation: chat.threadListGeneration - 1,
        ),
        false,
      );
      expect(target.title, 'Owned target');
    },
  );
}
