import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_gateway.dart';
import 'support/fake_attachment_source.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/gateway/todo_state.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeHermesServer server;
  Map<String, Object?> plan(int revision, String text) => {
    'revision': revision,
    'todos': [
      {'id': 'task', 'content': text, 'status': 'pending'},
    ],
  };
  Map<String, Object?> resume({Object? snapshot, String runtime = 'rt-1'}) => {
    'session_id': runtime,
    'stored_session_id': 'stored-1',
    'session_key': 'stored-1',
    'todo_state': ?snapshot,
  };
  Future<void> open([String profile = 'work']) async {
    await chat.loadThreads(profile);
    chat.select('stored-1');
    await pumpEventQueue();
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) =>
        resume(runtime: params['profile'] == 'other' ? 'rt-2' : 'rt-1');
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      sleep: (_) async {},
    );
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Synthetic plan')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', []),
      );
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
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  test('resume restores pinned plan on the confirmed owner', () async {
    gateway.handlers['session.resume'] = (_) =>
        resume(snapshot: fixture['state']);
    await open();

    final state = chat.todoPlanIn(chat.selectedThread!)!;
    expect(state.snapshot!.revision, 1);
    expect(state.snapshot!.entries[1]!.content, 'Implement the change');
  });

  testWidgets('the bound chat view shows a read-only expandable plan', (
    tester,
  ) async {
    gateway.handlers['session.resume'] = (_) =>
        resume(snapshot: fixture['state']);
    await tester.runAsync(() => open());
    final composer = TextEditingController(), focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    final methods = gateway.methods.length;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: boundChatThreadView(
            chat: chat,
            thread: chat.selectedThread,
            composerController: composer,
            composerFocus: focus,
            attachments: const [],
            attachmentSource: FakeAttachmentSource(),
            onAddAttachments: (_) {},
            onRemoveAttachment: (_) {},
            onSend: (_) {},
            latestReply: latest,
            welcome: false,
          ),
        ),
      ),
    );

    expect(find.byType(TodoPlanCard), findsOneWidget);
    await tester.tap(find.text('Plan · 1 of 4 completed'));
    await tester.pumpAndSettle();
    expect(find.text('Implement the change'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(gateway.methods, hasLength(methods));
  });

  test('an unconfirmed stored owner has no guessed runtime plan', () async {
    gateway.silent.add('session.resume');
    gateway.handlers.remove('session.resume');
    await open();
    gateway.event('todo.updated', 'stored-1', plan(8, 'Unconfirmed'));
    await pumpEventQueue();

    expect(chat.todoPlanIn(chat.selectedThread!), isNull);
  });

  test(
    'binding metadata before ThreadBound is recovered by pure lookup',
    () async {
      String? idAtSignal;
      bool? remoteAtSignal;
      final subscription = transport.ownedSessions.listen((change) {
        if (change.connected &&
            change.threadId == 'stored-1' &&
            idAtSignal == null) {
          idAtSignal = chat.selectedThread!.id;
          remoteAtSignal = chat.selectedThread!.remote;
        }
      });
      addTearDown(subscription.cancel);
      chat.newThread();
      chat.submit('Create a synthetic session', const []);
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(thread.id, 'stored-1');
      expect(idAtSignal, isNotNull);
      expect(idAtSignal, isNot('stored-1'));
      expect(remoteAtSignal, isFalse);
      gateway.event('todo.updated', 'rt-1', plan(1, 'New task'));
      await pumpEventQueue();

      expect(
        chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
        'New task',
      );
    },
  );

  test(
    'active and idle plans replace without settling or creating replies',
    () async {
      await open();
      final thread = chat.selectedThread!;
      chat.submit('Inspect the plan', const []);
      await pumpEventQueue();
      gateway.event('todo.updated', 'foreign-runtime', plan(99, 'Foreign'));
      gateway.event('todo.updated', 'rt-1', plan(1, 'Active task'));
      await pumpEventQueue();
      expect(chat.todoPlanIn(thread)!.snapshot!.revision, 1);
      expect(thread.isReplying, isTrue);
      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
      await pumpEventQueue();
      expect(thread.isReplying, isFalse);
      final messages = thread.messages.length;
      gateway.event('todo.updated', 'rt-1', plan(2, 'Idle task'));
      gateway.event('todo.updated', 'rt-1', plan(1, 'Old task'));
      await pumpEventQueue();

      expect(
        chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
        'Idle task',
      );
      expect(thread.messages, hasLength(messages));
      gateway.event('todo.updated', 'rt-1', {'revision': 3, 'todos': []});
      await pumpEventQueue();
      expect(chat.todoPlanIn(thread)!.snapshot!.entries, isEmpty);
    },
  );

  for (final missing in [false, true]) {
    test(
      'same-client takeover preserves live revision against ${missing ? 'missing' : 'older'} resume',
      () async {
        await open();
        final thread = chat.selectedThread!;
        gateway.event('todo.updated', 'rt-1', plan(6, 'Current task'));
        await pumpEventQueue();
        final state = chat.todoPlanIn(thread)!;
        gateway.handlers['session.resume'] = (_) =>
            resume(snapshot: missing ? null : plan(5, 'Old task'));
        chat.submit('Continue on same connection', const []);
        await pumpEventQueue();

        expect(chat.todoPlanIn(thread), same(state));
        expect(state.snapshot!.revision, 6);
        expect(state.snapshot!.entries.single!.content, 'Current task');
      },
    );
  }

  for (final newConnection in [false, true]) {
    test(
      '${newConnection ? 'connection' : 'runtime'} replacement accepts a lower revision',
      () async {
        await open();
        final thread = chat.selectedThread!;
        gateway.event('todo.updated', 'rt-1', plan(6, 'Previous generation'));
        await pumpEventQueue();
        final previousBinding = transport.ownedSessionFor(
          thread.id,
          profile: 'work',
        )!;
        gateway.handlers['session.resume'] = (_) => resume(
          snapshot: plan(1, 'New generation'),
          runtime: newConnection ? 'rt-1' : 'rt-2',
        );
        if (newConnection) {
          gateway.drop();
          await pumpEventQueue();
          expect(chat.todoPlanIn(thread), isNull);
          chat.submit('Attach on new connection', const []);
        } else {
          chat.submit('Attach new runtime', const []);
        }
        await pumpEventQueue();

        expect(
          transport.ownedSessionFor(thread.id, profile: 'work'),
          isNotNull,
        );
        expect(
          transport.ownedSessionFor(thread.id, profile: 'work'),
          isNot(previousBinding),
        );
        expect(chat.todoPlanIn(thread)!.snapshot!.revision, 1);
        expect(
          chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
          'New generation',
        );
      },
    );
  }

  test(
    'profile replacement clears old plan and rejects old runtime delivery',
    () async {
      await open();
      final oldThread = chat.selectedThread!;
      gateway.event('todo.updated', 'rt-1', plan(6, 'Old profile task'));
      await pumpEventQueue();
      final previous = chat.todoPlanIn(oldThread)!;
      gateway.handlers['session.resume'] = (_) =>
          resume(snapshot: plan(1, 'Other profile task'), runtime: 'rt-2');
      await open('other');
      gateway.event('todo.updated', 'rt-1', plan(99, 'Stale profile task'));
      await pumpEventQueue();

      expect(previous.attached, isFalse);
      expect(chat.todoPlanIn(oldThread), isNull);
      expect(
        chat
            .todoPlanIn(chat.selectedThread!)!
            .snapshot!
            .entries
            .single!
            .content,
        'Other profile task',
      );
    },
  );

  test('reclaim clears the plan and late updates cannot restore it', () async {
    await open();
    final thread = chat.selectedThread!;
    gateway.event('todo.updated', 'rt-1', plan(6, 'Retired task'));
    await pumpEventQueue();
    final previous = chat.todoPlanIn(thread)!;
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'reason': 'Synthetic retirement',
    });
    await pumpEventQueue();
    gateway.event('todo.updated', 'rt-1', plan(99, 'Late task'));
    await pumpEventQueue();

    expect(previous.attached, isFalse);
    expect(chat.todoPlanIn(thread), isNull);
  });

  test(
    'protected activity suspension clears plans before stale delivery',
    () async {
      chat.dispose();
      final activity = ValueNotifier(true);
      addTearDown(activity.dispose);
      final guarded = SessionChatTransport(() => transport);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: guarded,
        activity: activity,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      gateway.event('todo.updated', 'rt-1', plan(6, 'Protected task'));
      await pumpEventQueue();
      final previous = chat.todoPlanIn(thread)!;
      activity.value = false;
      gateway.event('todo.updated', 'rt-1', plan(99, 'Stale task'));
      await pumpEventQueue();

      expect(previous.attached, isFalse);
      expect(chat.todoPlanIn(thread), isNull);
    },
  );
}
