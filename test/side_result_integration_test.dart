import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_gateway.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_attachment_source.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeHermesServer server;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'Side result test'),
        ]),
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

  Future<void> open() async {
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
  }

  void result(
    String kind,
    String text, {
    String runtime = 'rt-1',
    String task = 'task',
  }) => gateway.event(kind, runtime, {
    'task_id': task,
    'text': text,
    'question': kind == 'btw.complete' ? 'Reported question' : null,
  });

  test(
    'side completions during a main turn never settle or alter its prose',
    () async {
      await open();
      final thread = chat.selectedThread!;
      chat.submit('Foreground', const []);
      await pumpEventQueue();
      result('background.complete', 'Background answer');
      result('btw.complete', 'Side answer');
      result('btw.complete', 'Foreign answer', runtime: 'foreign');
      await pumpEventQueue();
      expect(
        chat
                .sideResultsIn(thread)
                ?.results
                .map((result) => result.text)
                .toList() ??
            [],
        ['Background answer', 'Side answer'],
      );
      expect(thread.isReplying, isTrue);
      expect(thread.messages.last.content, isEmpty);
      gateway.event('message.delta', 'rt-1', {'text': 'Main answer'});
      gateway.event('message.complete', 'rt-1', {
        'text': 'Main answer',
        'status': 'complete',
      });
      await pumpEventQueue();
      expect(thread.messages.last.content, 'Main answer');
      expect(thread.isReplying, isFalse);
    },
  );

  test('idle results replace matching kind and task without opening or dispatching a turn', () async {
    await open();
    final thread = chat.selectedThread!;
    final messagesBefore = thread.messages.length;
    final submitsBefore = gateway.methods
        .where((method) => method == 'prompt.submit')
        .length;
    result('background.complete', 'First');
    result('btw.complete', 'Different kind');
    result('background.complete', 'Replacement');
    await pumpEventQueue();
    expect(chat.sideResultsIn(thread)!.results.map((result) => result.text), [
      'Replacement',
      'Different kind',
    ]);
    expect(thread.messages, hasLength(messagesBefore));
    expect(thread.isReplying, isFalse);
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(submitsBefore),
    );
    final state = chat.sideResultsIn(thread);
    chat.submit('Same owned runtime', const []);
    await pumpEventQueue();
    expect(chat.sideResultsIn(thread), same(state));
    expect(state!.results, hasLength(2));
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });

  test('profile replacement and reclaim clear received answers without restoring old frames', () async {
    await open();
    final oldThread = chat.selectedThread!;
    result('background.complete', 'Old profile');
    await pumpEventQueue();
    final old = chat.sideResultsIn(oldThread)!;
    await chat.loadThreads('other');
    chat.select('stored-1');
    await pumpEventQueue();
    result('background.complete', 'Late old profile');
    result('background.complete', 'Current profile', runtime: 'rt-2');
    await pumpEventQueue();
    final current = chat.selectedThread!;
    expect(old.results, isEmpty);
    expect(chat.sideResultsIn(current)!.results.single.text, 'Current profile');
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-2',
      'stored_session_id': 'stored-1',
      'reason': 'Another client',
    });
    await pumpEventQueue();
    expect(chat.sideResultsIn(current), isNull);
    result('background.complete', 'Late reclaimed answer', runtime: 'rt-2');
    await pumpEventQueue();
    expect(chat.sideResultsIn(current), isNull);
  });

  test(
    'activity suspension clears details and rejects retained event ownership',
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
      result('btw.complete', 'Sensitive synthetic answer');
      await pumpEventQueue();
      final state = chat.sideResultsIn(thread)!;
      activity.value = false;
      await guarded.suspend();
      result('btw.complete', 'Late answer');
      await pumpEventQueue();
      expect(state.results, isEmpty);
      expect(chat.sideResultsIn(thread), isNull);
    },
  );

  test('same-runtime frames from an old physical connection cannot overwrite current results', () async {
    chat.dispose();
    final owned = _OwnedTransport();
    addTearDown(owned.close);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: owned,
      attention: attention,
      report: (_) {},
    );
    await open();
    final thread = chat.selectedThread!;
    final old = owned.binding!;
    final follow = owned.followUpStreams['stored-1']!;
    follow.emit(
      SideResultReceived(
        const SideResult(
          kind: SideResultKind.background,
          taskId: 'task',
          text: 'Old',
        ),
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    await pumpEventQueue();
    final oldState = chat.sideResultsIn(thread)!;
    owned.replace();
    await pumpEventQueue();
    expect(oldState.results, isEmpty);
    final current = owned.binding!;
    follow.emit(
      SideResultReceived(
        const SideResult(
          kind: SideResultKind.background,
          taskId: 'task',
          text: 'Current',
        ),
        runtimeId: current.runtimeId,
        connection: current.connection,
      ),
    );
    follow.emit(
      SideResultReceived(
        const SideResult(
          kind: SideResultKind.background,
          taskId: 'task',
          text: 'Stale queued frame',
        ),
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    await pumpEventQueue();
    expect(chat.sideResultsIn(thread)!.results.single.text, 'Current');
    owned.lose();
    await pumpEventQueue();
    expect(chat.sideResultsIn(thread), isNull);
  });

  test(
    'replacement ownership retires old side details before notifying listeners',
    () async {
      chat.dispose();
      final owned = _OwnedTransport();
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      final binding = owned.binding!;
      owned.followUpStreams['stored-1']!.emit(
        SideResultReceived(
          const SideResult(
            kind: SideResultKind.background,
            taskId: 'task',
            text: 'Old owner answer',
          ),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      final observed = <String>[];
      chat.addListener(() {
        observed.addAll(
          chat.sideResultsIn(thread)?.results.map((result) => result.text) ??
              const [],
        );
      });
      owned.replace();
      await pumpEventQueue();
      expect(observed, isNot(contains('Old owner answer')));
    },
  );

  test(
    'replacement side adoption cannot expose old usage under the new binding',
    () async {
      chat.dispose();
      final owned = _OwnedTransport();
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      final binding = owned.binding!;
      final follow = owned.followUpStreams['stored-1']!;
      follow.emit(
        SideResultReceived(
          const SideResult(
            kind: SideResultKind.background,
            taskId: 'task',
            text: 'Old answer',
          ),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      follow.emit(
        SessionUsageUpdated(
          const UsageSnapshot(total: 7),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      expect(chat.usageIn(thread)!.snapshot!.total, 7);
      final observed = <int>[];
      chat.addListener(() {
        final total = chat.usageIn(thread)?.snapshot?.total;
        if (total != null) {
          observed.add(total);
        }
      });
      owned.replace();
      await pumpEventQueue();
      expect(observed, isNot(contains(7)));
    },
  );

  test(
    'confirmed replacement hides cached disconnected usage before notification',
    () async {
      chat.dispose();
      final owned = _OwnedTransport();
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      final binding = owned.binding!;
      owned.followUpStreams['stored-1']!.emit(
        SessionUsageUpdated(
          const UsageSnapshot(total: 7),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      owned.lose();
      await pumpEventQueue();
      expect(chat.usageIn(thread)!.snapshot!.total, 7);
      expect(chat.usageIn(thread)!.freshness.name, 'stale');
      owned.binding = OwnedSessionBinding(
        connection: Object(),
        runtimeId: 'same-runtime',
        profile: 'work',
      );
      expect(chat.usageIn(thread)?.snapshot?.total, isNull);
    },
  );

  test('a reentrant ownership notification cannot apply side data after activity retirement', () async {
    chat.dispose();
    final activity = ValueNotifier(true);
    final owned = _OwnedTransport();
    final applied = <Map<String, Object>>[];
    addTearDown(activity.dispose);
    addTearDown(owned.close);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: owned,
      activity: activity,
      attention: attention,
      report: (_) {},
      events: (name, [attributes = const {}]) {
        applied.add(Map.of(attributes));
      },
    );
    await open();
    var retire = true;
    chat.addListener(() {
      if (!retire) return;
      retire = false;
      activity.value = false;
    });
    owned.binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'same-runtime',
      profile: 'work',
    );
    final binding = owned.binding!;
    owned.followUpStreams['stored-1']!.emit(
      SideResultReceived(
        const SideResult(
          kind: SideResultKind.background,
          taskId: 'task',
          text: 'Retired answer',
        ),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    await pumpEventQueue();
    expect(activity.value, isFalse);
    expect(applied, isEmpty);
  });

  testWidgets('expanded activity leaves chat usable in a short window', (
    tester,
  ) async {
    await tester.runAsync(() async {
      gateway.handlers['session.usage'] = (_) => {
        'input': 3,
        'output': 2,
        'total': 5,
      };
      await open();
      gateway.event('session.usage', 'rt-1', {
        'usage': {'input': 3, 'output': 2, 'total': 5},
      });
      gateway.event('todo.updated', 'rt-1', {
        'revision': 1,
        'todos': [
          {
            'id': 'task',
            'content': List.filled(40, 'Synthetic task detail').join('\n'),
            'status': 'pending',
          },
        ],
      });
      result(
        'background.complete',
        List.filled(40, 'Synthetic background detail').join('\n'),
      );
      result('btw.complete', 'Synthetic side answer');
      await pumpEventQueue();
    });
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    tester.view.physicalSize = const Size(520, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          ),
        ),
      ),
    );
    for (final title in [
      find.textContaining('Plan ·'),
      find.text('Background result'),
      find.textContaining('Session usage ·'),
    ]) {
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.runAsync(() => pumpEventQueue());
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getSize(find.byType(Chat)).height, greaterThan(180));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await transport.close();
      await pumpEventQueue();
    });
    await tester.pump();
  });

  testWidgets('received results render as independent compact disclosures', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await open();
      result('background.complete', 'Background details');
      result('btw.complete', 'Side details');
      await pumpEventQueue();
    });
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          ),
        ),
      ),
    );
    expect(find.text('Background result'), findsOneWidget);
    expect(find.text('Side question answer'), findsOneWidget);
    await tester.tap(find.text('Side question answer'));
    await tester.pumpAndSettle();
    expect(find.text('Side details'), findsOneWidget);
    expect(find.text('Question: Reported question'), findsOneWidget);
  });
}

class _OwnedTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  OwnedSessionBinding? binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'same-runtime',
    profile: 'work',
  );
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored-1' && binding?.profile == profile ? binding : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw const FakeRpcError(-32601);
  void replace() {
    binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'same-runtime',
      profile: 'work',
    );
    _changes.add(OwnedSessionChange('stored-1', binding!));
  }

  void lose() {
    final old = binding!;
    binding = null;
    _changes.add(OwnedSessionChange('stored-1', old, connected: false));
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}
