import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_queue_keys.dart';
import 'support/fake_queue_transport.dart';
import 'support/fake_gateway.dart';
import 'support/recording_tracer.dart';

QueueScope _scope(String id) => QueueScope(
  serverKey: 'synthetic-server',
  accountKey: 'synthetic-account',
  profile: 'work',
  conversationId: id,
);

Future<void> _idle(ChatController chat, ChatThread thread) async {
  if (!chat.queueBusy(thread)) return;
  final done = Completer<void>();
  void changed() {
    if (!chat.queueBusy(thread) && !done.isCompleted) done.complete();
  }

  chat.addListener(changed);
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    chat.removeListener(changed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DurableQueueStore store;
  late FakeQueueKeys keys;
  late FakeHermesServer server;
  late AttentionNotifier attention;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('invalidation-queue-');
    keys = FakeQueueKeys();
    store = DurableQueueStore(directory: directory, keys: keys);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored', title: 'Exact target'),
          sessionRow(id: 'other', title: 'Other target'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      )
      ..on('GET', '/api/sessions/other/messages', messageListBody('other', []));
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });
  tearDown(() async {
    attention.dispose();
    await directory.delete(recursive: true);
  });

  ChatController controller({
    Future<PromptQueueStore> Function()? openStore,
    ChatTransport? transport,
    ValueNotifier<bool>? activity,
  }) => ChatController(
    activity: activity,
    repository: HermesChatRepository(server.client().raw),
    transport: transport,
    attention: attention,
    report: (_) {},
    queueStore: openStore ?? () async => store,
    queueScope: (thread, profile) => _scope(thread.id),
  );

  test('complete absence while a protected attachment read is held prevents dispatch', () async {
    final held = _HeldAttachmentStore(directory, keys);
    store = held;
    final input = File('${directory.path}/synthetic.txt');
    await input.writeAsString('Synthetic attachment');
    final record = await store.commit(
      _scope('stored'),
      'Retained attachment prompt',
      files: [QueueAttachmentInput(path: input.path, name: 'synthetic.txt')],
    );
    final transport = FakeQueueTransport();
    final chat = controller(transport: transport);
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    chat.sendQueued(target);
    await held.entered.future.timeout(const Duration(seconds: 5));
    chat.applyInvalidatedThreads(
      const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    held.release.complete();
    await _idle(chat, target);
    await pumpEventQueue();
    expect(transport.sends, isEmpty);
    final retained = (await store.load(_scope('stored'))).records.single;
    expect(retained.id, record.id);
    expect(retained.state, QueueRecordState.queued);
    expect(retained.submissionClaimHash, isNull);
    expect(chat.queuedIn(target).single.scope!.conversationId, 'stored');
  });

  test(
    'absence during claim persistence restores only the proven unsent claim',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      var held = false;
      store = DurableQueueStore(
        directory: directory,
        keys: keys,
        beforeCommit: (operation) async {
          if (operation == 'state' && !held) {
            held = true;
            entered.complete();
            await release.future;
          }
        },
      );
      final record = await store.commit(_scope('stored'), 'Retain exact claim');
      final transport = FakeQueueTransport();
      final chat = controller(transport: transport);
      addTearDown(chat.dispose);
      await chat.loadThreads('work');
      chat.select('stored');
      final target = chat.selectedThread!;
      await _idle(chat, target);
      chat.sendQueued(target);
      await entered.future.timeout(const Duration(seconds: 5));
      chat.applyInvalidatedThreads(
        const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
        profile: 'work',
        generation: chat.threadListGeneration,
      );
      release.complete();
      await transport.prepared.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(transport.sends, isEmpty);
      final retained = (await store.load(_scope('stored'))).records.single;
      expect(retained.id, record.id);
      expect(retained.state, QueueRecordState.queued);
      expect(retained.submissionClaimHash, isNull);
    },
  );

  test('instrumentation absence after the committed barrier prevents queued prompt bytes', () async {
    final gateway = FakeGateway()..activeSessions = {};
    late ChatController chat;
    late ChatThread target;
    final atDispatch = Completer<void>();
    final tracer = _SubmitTracer(() {
      expect(
        chat.queuedIn(target).single.durable!.state,
        QueueRecordState.submissionStarted,
      );
      chat.applyInvalidatedThreads(
        const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
        profile: 'work',
        generation: chat.threadListGeneration,
      );
      atDispatch.complete();
    });
    final transport = HermesGatewayTransport(
      connect: gateway.connect,
      telemetry: gatewayTracer(tracer),
    );
    gateway.turn = (server, runtime) {
      server.event('message.start', runtime);
      server.event('message.complete', runtime, {
        'text': 'Unexpected answer',
        'status': 'complete',
      });
    };
    addTearDown(transport.close);
    final record = await store.commit(
      _scope('stored'),
      'Retain at final dispatch',
    );
    chat = controller(transport: transport);
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    target = chat.selectedThread!;
    await _idle(chat, target);
    chat.sendQueued(target);
    await atDispatch.future.timeout(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(gateway.methods, isNot(contains('prompt.submit')));
    final retained = (await store.load(_scope('stored'))).records.single;
    expect(retained.id, record.id);
    expect(retained.state, QueueRecordState.queued);
    expect(retained.submissionClaimHash, isNull);
    expect(chat.queueErrorIn(target), contains('kept in their original scope'));
    final fresh = await chat.repository!.loadThreadPage(profile: 'work');
    chat.applyInvalidatedThreads(
      fresh,
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    expect(chat.queueAvailable(target), true);
    expect(chat.queueErrorIn(target), isNull);
    expect(chat.queueNeedsReview(target), true);
    expect(gateway.methods, isNot(contains('prompt.submit')));
  });

  test('positive acceptance after sent bytes settles the owned reply and preserves the remaining unavailable queue', () async {
    final gateway = FakeGateway()..activeSessions = {};
    final transport = HermesGatewayTransport(connect: gateway.connect);
    final chat = controller(transport: transport);
    addTearDown(transport.close);
    addTearDown(chat.dispose);
    await store.commit(_scope('stored'), 'Known accepted prompt');
    await store.commit(_scope('stored'), 'Still paused prompt');
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    final sent = Completer<void>();
    gateway.handlers['prompt.submit'] = (params) {
      chat.applyInvalidatedThreads(
        const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
        profile: 'work',
        generation: chat.threadListGeneration,
      );
      final runtime = params['session_id'] as String;
      gateway.event('message.start', runtime);
      gateway.event('message.complete', runtime, {
        'text': 'Known main answer',
        'status': 'complete',
      });
      sent.complete();
      return {'status': 'streaming', 'user_row_id': 42};
    };
    chat.sendQueued(target);
    await sent.future.timeout(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(1),
    );
    expect(
      target.messages
          .where((message) => message.role == ChatRole.user)
          .single
          .content,
      'Known accepted prompt',
    );
    expect(target.messages.last.content, 'Known main answer');
    expect(target.isReplying, false);
    expect(chat.queueAvailable(target), false);
    expect(chat.queueNeedsReview(target), true);
    expect(chat.queuedIn(target).single.text, 'Still paused prompt');
    expect(
      (await store.load(_scope('stored'))).records.single.text,
      'Still paused prompt',
    );
  });

  testWidgets(
    'an unavailable attachment abort clears the bound queue busy indicator',
    (tester) async {
      late _HeldAttachmentStore held;
      late FakeQueueTransport transport;
      late ChatController chat;
      late ChatThread target;
      await tester.runAsync(() async {
        held = _HeldAttachmentStore(directory, keys);
        store = held;
        transport = FakeQueueTransport();
        chat = controller(transport: transport);
        addTearDown(chat.dispose);
        final input = File('${directory.path}/synthetic.txt');
        await input.writeAsString('Synthetic attachment');
        await store.commit(
          _scope('stored'),
          'Retained attachment prompt',
          files: [
            QueueAttachmentInput(path: input.path, name: 'synthetic.txt'),
          ],
        );
        await chat.loadThreads('work');
        chat.select('stored');
        target = chat.selectedThread!;
        await _idle(chat, target);
      });
      final composer = TextEditingController(), focus = FocusNode();
      final latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (context, _) => boundChatThreadView(
                chat: chat,
                thread: target,
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
        ),
      );
      await tester.runAsync(() async {
        chat.sendQueued(target);
        await held.entered.future.timeout(const Duration(seconds: 5));
        chat.applyInvalidatedThreads(
          const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
          profile: 'work',
          generation: chat.threadListGeneration,
        );
      });
      await tester.pump();
      expect(find.text('Queueing…'), findsOneWidget);
      await tester.runAsync(() async {
        held.release.complete();
        await held.finished.future.timeout(const Duration(seconds: 5));
        await pumpEventQueue();
      });
      await tester.pump();
      expect(chat.queueBusy(target), false);
      expect(find.text('Queueing…'), findsNothing);
      expect(find.text('Original conversation unavailable.'), findsOneWidget);
      expect(transport.sends, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('a fresh durable queue remains paused when positive proof precedes foreground settlement', () async {
    final transport = FakeQueueTransport();
    final chat = controller(transport: transport);
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    await chat.submit('Foreground', const []);
    await chat.submit('Fresh durable queued prompt', const []);
    expect(chat.queueNeedsReview(target), false);
    chat.applyInvalidatedThreads(
      const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    final page = await chat.repository!.loadThreadPage(profile: 'work');
    chat.applyInvalidatedThreads(
      page,
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    transport.sends.single
      ..emit(const ReplyCompleted('Foreground answer'))
      ..emit(const SessionInfo(running: false))
      ..finish();
    await pumpEventQueue();
    expect(transport.sends, hasLength(1));
    expect(chat.queueAvailable(target), true);
    expect(chat.queueNeedsReview(target), true);
    expect(chat.queuedIn(target).single.text, 'Fresh durable queued prompt');
    expect(
      (await store.load(_scope('stored'))).records.single.state,
      QueueRecordState.queued,
    );
  });

  test('busy absence retains review when an invisible durable commit completes after positive proof', () async {
    final entered = Completer<void>(), release = Completer<void>();
    store = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'record') {
          entered.complete();
          await release.future;
        }
      },
    );
    final transport = FakeQueueTransport();
    final chat = controller(transport: transport);
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    await chat.submit('Foreground', const []);
    final pending = Future.sync(
      () => chat.submit('Pending durable entry', const []),
    );
    await entered.future.timeout(const Duration(seconds: 5));
    expect(chat.queuedIn(target), isEmpty);
    expect(chat.queueBusy(target), true);
    chat.applyInvalidatedThreads(
      const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    final positive = await chat.repository!.loadThreadPage(profile: 'work');
    chat.applyInvalidatedThreads(
      positive,
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    transport.sends.single
      ..emit(const ReplyCompleted('Foreground answer'))
      ..emit(const SessionInfo(running: false))
      ..finish();
    await pumpEventQueue();
    release.complete();
    expect(await pending.timeout(const Duration(seconds: 5)), true);
    await pumpEventQueue();
    expect(chat.queueNeedsReview(target), true);
    expect(transport.sends, hasLength(1));
    expect(chat.queuedIn(target).single.text, 'Pending durable entry');
    expect(
      (await store.load(_scope('stored'))).records.single.state,
      QueueRecordState.queued,
    );
  });

  test('empty restoration after positive proof keeps an intended ordinary send available', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final transport = FakeQueueTransport();
    final chat = controller(
      transport: transport,
      openStore: () async {
        entered.complete();
        await release.future;
        return store;
      },
    );
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    final pending = Future.sync(
      () => chat.submit('Intended ordinary prompt', const []),
    );
    await entered.future.timeout(const Duration(seconds: 5));
    chat.applyInvalidatedThreads(
      const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    final positive = await chat.repository!.loadThreadPage(profile: 'work');
    chat.applyInvalidatedThreads(
      positive,
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    release.complete();
    expect(await pending.timeout(const Duration(seconds: 5)), true);
    await pumpEventQueue();
    expect(transport.sends.single.text, 'Intended ordinary prompt');
    expect(chat.queueNeedsReview(target), false);
    expect(chat.queuedIn(target), isEmpty);
    expect((await store.load(_scope('stored'))).records, isEmpty);
  });

  test('complete absence retains an unselected preparing target until protected restoration finishes', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final chat = controller(
      openStore: () async {
        entered.complete();
        await release.future;
        return store;
      },
    );
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    final preparing = Future.sync(
      () => chat.submit('Retained draft', const []),
    );
    await entered.future.timeout(const Duration(seconds: 5));
    chat.select('other');
    expect(chat.queueBusy(target), true);
    expect(target.isReplying, false);
    expect(chat.queuedIn(target), isEmpty);
    try {
      chat.applyInvalidatedThreads(
        ThreadPage(
          threads: [chat.selectedThread!],
          nextOffset: 50,
          hasMore: false,
        ),
        profile: 'work',
        generation: chat.threadListGeneration,
      );
      expect(chat.threads, contains(same(target)));
      expect(chat.threadListAvailable(target), false);
      expect(chat.queueErrorIn(target), isNull);
    } finally {
      release.complete();
      await preparing.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
    }
    expect(target.id, 'stored');
    expect(target.remote, true);
    expect((await store.load(_scope('stored'))).records, isEmpty);
  });

  testWidgets(
    'complete absence pauses recovered controls and positive list proof restores availability without sending',
    (tester) async {
      final transport = FakeQueueTransport();
      final chat = controller(transport: transport);
      addTearDown(chat.dispose);
      late ChatThread target;
      await tester.runAsync(() async {
        await store.commit(_scope('stored'), 'Retained queued prompt');
        await store.commit(_scope('unlisted'), 'Unlisted ciphertext');
        await chat.loadThreads('work');
        chat.select('stored');
        target = chat.selectedThread!;
        await _idle(chat, target);
        expect(chat.queueAvailable(target), true);
        chat.applyInvalidatedThreads(
          const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
          profile: 'work',
          generation: chat.threadListGeneration,
        );
      });
      final composer = TextEditingController();
      final focus = FocusNode();
      final latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (context, _) => boundChatThreadView(
                chat: chat,
                thread: target,
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
        ),
      );
      expect(find.text('Send next'), findsNothing);
      expect(find.text('Original conversation unavailable.'), findsOneWidget);
      expect(chat.queueAvailable(target), false);
      expect(
        chat.queueErrorIn(target),
        contains('kept in their original scope'),
      );
      await tester.runAsync(() async {
        chat.sendQueued(target);
        await pumpEventQueue();
        expect(transport.sends, isEmpty);
        expect(
          (await store.load(_scope('stored'))).records.single.text,
          'Retained queued prompt',
        );
        expect(
          (await store.load(_scope('unlisted'))).records.single.text,
          'Unlisted ciphertext',
        );
        final fresh = (await chat.repository!.loadThreadPage(profile: 'work'))
            .threads;
        chat.applyInvalidatedThreads(
          ThreadPage(threads: fresh, nextOffset: 50, hasMore: false),
          profile: 'work',
          generation: chat.threadListGeneration,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Send next'), findsOneWidget);
      expect(find.text('Original conversation unavailable.'), findsNothing);
      expect(chat.queueAvailable(target), true);
      expect(chat.queueErrorIn(target), isNull);
      expect(chat.queueNeedsReview(target), true);
      expect(chat.selectedThread, same(target));
      expect(chat.queuedIn(target).single.scope!.conversationId, 'stored');
      expect(transport.sends, isEmpty);
      await tester.runAsync(() async {
        expect(
          (await store.load(_scope('unlisted'))).records.single.text,
          'Unlisted ciphertext',
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('positive availability does not clear an unrelated protected storage failure', () async {
    final chat = controller();
    addTearDown(chat.dispose);
    await store.commit(_scope('stored'), 'Encrypted record requires its key');
    keys.unavailable = true;
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    final failure = chat.queueErrorIn(target);
    expect(failure, contains('Protected queue storage is unavailable'));
    chat.setThreadListAvailability(target, available: false);
    chat.setThreadListAvailability(target, available: true);
    expect(chat.queueErrorIn(target), failure);
  });

  test('explicit successful target recovery clears only its matching unavailable marker and error', () async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    await store.commit(_scope('stored'), 'Retain namespace');
    final transport = FakeQueueTransport();
    final chat = controller(transport: transport, activity: activity);
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final target = chat.selectedThread!;
    await _idle(chat, target);
    chat.applyInvalidatedThreads(
      const ThreadPage(threads: [], nextOffset: 50, hasMore: false),
      profile: 'work',
      generation: chat.threadListGeneration,
    );
    server.on('GET', '/api/sessions', sessionListBody([]));
    server.on(
      'GET',
      '/api/sessions/stored',
      sessionRow(id: 'stored', title: 'Verified exact target'),
    );
    activity.value = false;
    await pumpEventQueue();
    activity.value = true;
    await pumpEventQueue();
    final recovered = chat.selectedThread!;
    expect(chat.threadListAvailable(target), true);
    expect(chat.queueErrorIn(target), isNull);
    expect(recovered.id, 'stored');
    expect(recovered.remote, true);
    expect(chat.queueAvailable(recovered), true);
    expect(chat.queuedIn(recovered).single.scope!.conversationId, 'stored');
    expect(transport.sends, isEmpty);
    expect(
      (await store.load(_scope('stored'))).records.single.text,
      'Retain namespace',
    );
  });
}

class _HeldAttachmentStore extends DurableQueueStore {
  _HeldAttachmentStore(Directory directory, FakeQueueKeys keys)
    : super(directory: directory, keys: keys);
  final entered = Completer<void>(),
      release = Completer<void>(),
      finished = Completer<void>();
  @override
  Future<List<int>> readAttachment(
    QueueScope scope,
    String id,
    String blobId,
  ) async {
    entered.complete();
    await release.future;
    final bytes = await super.readAttachment(scope, id, blobId);
    finished.complete();
    return bytes;
  }
}

class _SubmitTracer extends RecordingTracer {
  _SubmitTracer(this.onSubmit);
  final void Function() onSubmit;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'prompt.submit send') onSubmit();
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}
