import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_gateway.dart';
import '../support/fake_queue_keys.dart';
import '../support/fake_queue_transport.dart';

QueueScope scope([String? profile = 'work']) => QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: profile,
  conversationId: 'stored',
);

Future<void> queueIdle(ChatController chat) async {
  final thread = chat.selectedThread!;
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
  late FakeQueueTransport transport;
  late FakeHermesServer server;
  late ValueNotifier<bool> visible;
  late ValueNotifier<bool> activity;
  late List<String> reports;
  late List<(String, Map<String, Object>)> outcomes;
  late BreadcrumbTrail trail;
  late AttentionNotifier attention;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('queue-dispatch-test-');
    keys = FakeQueueKeys();
    store = DurableQueueStore(directory: directory, keys: keys);
    transport = FakeQueueTransport();
    visible = ValueNotifier(true);
    activity = ValueNotifier(true);
    reports = [];
    outcomes = [];
    trail = BreadcrumbTrail();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored', title: 'Original conversation'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      );
  });

  tearDown(() async {
    visible.dispose();
    activity.dispose();
    attention.dispose();
    await directory.delete(recursive: true);
  });

  Future<ChatController> open({
    String? profile = 'work',
    ChatTransport? delegate,
    bool resolveProfile = false,
    bool loggerFails = false,
  }) async {
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      profiles: resolveProfile
          ? HermesProfilesRepository(server.client().raw)
          : null,
      activity: activity,
      transport: delegate ?? transport,
      attention: attention,
      report: reports.add,
      breadcrumbs: Breadcrumbs.of(trail),
      events: (name, [attributes = const {}]) {
        if (loggerFails) throw StateError('logger unavailable');
        outcomes.add((name, Map.of(attributes)));
      },
      queueStore: () async => store,
      queueChanges: visible,
      canShowQueues: () => visible.value,
      queueScope: (thread, profile) => visible.value
          ? QueueScope(
              serverKey: 'server',
              accountKey: 'account',
              profile: profile,
              conversationId: thread.id,
            )
          : null,
    );
    addTearDown(chat.dispose);
    await chat.loadThreads(profile);
    chat.select('stored');
    await queueIdle(chat);
    await pumpEventQueue();
    return chat;
  }

  test(
    'restart review sends one entry and keeps remaining FIFO paused',
    () async {
      await store.commit(scope(), 'first');
      await store.commit(scope(), 'second');
      store = DurableQueueStore(directory: directory, keys: keys);
      final chat = await open();
      final thread = chat.selectedThread!;
      expect(chat.queuedIn(thread).map((entry) => entry.text), [
        'first',
        'second',
      ]);
      expect(chat.queueNeedsReview(thread), true);
      expect(transport.sends, isEmpty);

      chat.sendQueued(thread);
      await transport.prepared;
      await pumpEventQueue();
      expect(transport.sends.single.text, 'first');
      expect(transport.sends.single.queued, true);
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      transport.followUpStreams['stored']!.emit(
        const SessionInfo(running: false),
      );
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread).single.text, 'second');
      expect(chat.queueNeedsReview(thread), true);
      expect((await store.load(scope())).records.single.text, 'second');
    },
  );

  test('new input on restored queue stays paused', () async {
    await store.commit(scope(), 'restored');
    final chat = await open();
    expect(await chat.submit('new input', const []), true);
    expect(transport.sends, isEmpty);
    expect(chat.queuedIn(chat.selectedThread!).map((entry) => entry.text), [
      'restored',
      'new input',
    ]);
  });

  for (final discard in [false, true]) {
    test(
      'fresh queue auto-sends after ${discard ? 'discarding' : 'sending'} the last suspended entry',
      () async {
        await store.commit(scope(), 'recovered');
        final chat = await open();
        // Session recovery retains the queue but suspends it until review.
        activity.value = false;
        activity.value = true;
        await pumpEventQueue();
        while (chat.loadingThreads) {
          await pumpEventQueue();
        }
        chat.select('stored');
        await queueIdle(chat);
        await pumpEventQueue();
        final thread = chat.selectedThread!;
        expect(chat.queueNeedsReview(thread), true);
        expect(transport.sends, isEmpty);
        if (discard) {
          await chat.removeQueued(thread, chat.queuedIn(thread).single);
          await chat.submit('new turn', const []);
        } else {
          chat.sendQueued(thread);
          await transport.prepared.timeout(const Duration(seconds: 5));
          await pumpEventQueue();
        }
        expect(chat.queuedIn(thread), isEmpty);
        expect(await chat.submit('fresh follow-up', const []), true);
        expect(chat.queueNeedsReview(thread), false);
        final dispatched = Completer<void>();
        void onDispatch() {
          if (transport.sends.length == 2 && !dispatched.isCompleted) {
            dispatched.complete();
          }
        }

        chat.addListener(onDispatch);
        addTearDown(() => chat.removeListener(onDispatch));
        final first = transport.sends.single;
        first
          ..emit(const ReplyCompleted('Done'))
          ..emit(const SessionInfo(running: false))
          ..finish();
        // Dispatch persists its submitting state before calling the transport.
        // An idle queue or a drained microtask queue does not finish that I/O.
        await dispatched.future.timeout(const Duration(seconds: 5));
        await queueIdle(chat);
        await pumpEventQueue();
        expect(transport.sends.map((send) => send.text), [
          discard ? 'new turn' : 'recovered',
          'fresh follow-up',
        ]);
        transport.sends.last
          ..emit(const ReplyCompleted('Follow-up done'))
          ..emit(const SessionInfo(running: false))
          ..finish();
        await pumpEventQueue();
        await store.load(scope());
      },
    );
  }

  test(
    'same session ID restores only its exact profile after switching',
    () async {
      await store.commit(scope('work'), 'work draft');
      await store.commit(scope('personal'), 'personal draft');
      final chat = await open(profile: 'work');
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'work draft');

      await chat.loadThreads('personal');
      chat.select('stored');
      await queueIdle(chat);
      await pumpEventQueue();
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'personal draft');
      expect(chat.queueNeedsReview(chat.selectedThread!), true);
      expect(transport.sends, isEmpty);
      expect(
        (await store.load(scope('work'))).records.single.text,
        'work draft',
      );
    },
  );

  test('locked queue DTOs disappear and unlock reloads with review', () async {
    await store.commit(scope(), 'private draft');
    final chat = await open();
    final thread = chat.selectedThread!;
    visible.value = false;
    expect(chat.queuedIn(thread), isEmpty);
    chat.sendQueued(thread);
    expect(transport.sends, isEmpty);

    visible.value = true;
    await queueIdle(chat);
    await pumpEventQueue();
    expect(chat.queuedIn(thread).single.text, 'private draft');
    expect(chat.queueNeedsReview(thread), true);
    expect(transport.sends, isEmpty);
  });

  test('durable user transcript row waits for acceptance', () async {
    await store.commit(scope(), 'queued text');
    final chat = await open();
    final thread = chat.selectedThread!;
    final receipt = Completer<void>();
    transport.acceptanceGate = receipt;
    chat.sendQueued(thread);
    await transport.prepared;
    await pumpEventQueue();
    expect(transport.sends, hasLength(1));
    expect(
      thread.messages.where((message) => message.role == ChatRole.user),
      isEmpty,
    );
    expect(
      (await store.load(scope())).records.single.state,
      QueueRecordState.submissionStarted,
    );

    receipt.complete();
    await pumpEventQueue();
    expect(
      thread.messages
          .where((message) => message.role == ChatRole.user)
          .single
          .content,
      'queued text',
    );
    expect(chat.queuedIn(thread), isEmpty);
    expect((await store.load(scope())).records, isEmpty);
  });

  test('lock cycle during enqueue keeps draft and does not dispatch', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
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
    final chat = await open();
    final thread = chat.selectedThread!;
    await chat.submit('opening', const []);
    final source = File('${directory.path}/attachment.txt');
    await source.writeAsString('retained bytes');
    final queued = Future.sync(
      () => chat.submit('next', [
        SharedFile(path: source.path, name: 'attachment.txt'),
      ]),
    );
    await entered.future;
    visible.value = false;
    visible.value = true;
    release.complete();
    expect(await queued, false);
    expect(chat.queuedIn(thread), isEmpty);
    expect(transport.sends, hasLength(1));
  });

  test('lock cycle during dispatch claim prevents a network send', () async {
    await store.commit(scope(), 'retained');
    final entered = Completer<void>();
    final release = Completer<void>();
    var waiting = true;
    store = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'state' && waiting) {
          waiting = false;
          entered.complete();
          await release.future;
        }
      },
    );
    final chat = await open();
    final thread = chat.selectedThread!;
    chat.sendQueued(thread);
    await entered.future;
    visible.value = false;
    visible.value = true;
    release.complete();
    await transport.prepared;
    await pumpEventQueue();
    expect(transport.sends, isEmpty);
    expect(
      (await store.load(scope())).records.single.state,
      QueueRecordState.queued,
    );
    expect(chat.queueNeedsReview(thread), true);
  });

  test(
    'lost receipt retains uncertainty and never creates a sent user row',
    () async {
      await store.commit(scope(), 'possibly sent');
      final chat = await open();
      final thread = chat.selectedThread!;
      transport.loseAcceptance = true;
      chat.sendQueued(thread);
      await transport.prepared;
      await pumpEventQueue();
      expect(chat.queuedIn(thread).single.uncertain, true);
      expect(
        thread.messages.where((message) => message.role == ChatRole.user),
        isEmpty,
      );
      expect(
        (await store.load(scope())).records.single.state,
        QueueRecordState.submissionStarted,
      );

      chat.sendQueued(thread);
      await transport.prepared;
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      await chat.removeQueued(thread, chat.queuedIn(thread).single);
      expect((await store.load(scope())).records, isEmpty);
    },
  );

  test('unknown acceptance event cannot remove local ownership', () async {
    await store.commit(scope(), 'possibly sent');
    transport.acceptanceStatus = 'accepted';
    final chat = await open();
    final thread = chat.selectedThread!;
    chat.sendQueued(thread);
    await transport.prepared;
    transport.sends.single
      ..emit(const ReplyCompleted('Done'))
      ..finish();
    await pumpEventQueue();

    expect(chat.queuedIn(thread).single.uncertain, true);
    expect(
      (await store.load(scope())).records.single.state,
      QueueRecordState.submissionStarted,
    );
    expect(
      thread.messages.where((message) => message.role == ChatRole.user),
      isEmpty,
    );
  });

  test(
    'unknown RPC status retains uncertainty after reply completion',
    () async {
      await store.commit(scope(), 'possibly sent');
      final gateway = FakeGateway()..submitStatus = 'accepted';
      final completed = Completer<void>();
      gateway.turn = (server, session) {
        server.event('message.start', session);
        server.event('message.complete', session, {
          'text': 'Done',
          'status': 'complete',
        });
        completed.complete();
      };
      final actual = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(actual.close);
      final chat = await open(delegate: actual);
      final thread = chat.selectedThread!;
      chat.sendQueued(thread);
      await completed.future.timeout(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(chat.queuedIn(thread).single.uncertain, true);
      expect(
        (await store.load(scope())).records.single.state,
        QueueRecordState.submissionStarted,
      );
      expect(
        thread.messages.where((message) => message.role == ChatRole.user),
        isEmpty,
      );
      chat.sendQueued(thread);
      await pumpEventQueue();
      expect(
        gateway.methods.where((method) => method == 'prompt.submit'),
        hasLength(1),
      );
    },
  );

  test('failed submission-state commit opens no network dispatch', () async {
    await store.commit(scope(), 'retained');
    store = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'state') throw StateError('disk unavailable');
      },
    );
    final chat = await open();
    final thread = chat.selectedThread!;
    chat.sendQueued(thread);
    await transport.prepared;
    await pumpEventQueue();
    expect(transport.sends, isEmpty);
    expect(
      (await store.load(scope())).records.single.state,
      QueueRecordState.queued,
    );
    expect(
      thread.messages.where((message) => message.role == ChatRole.user),
      isEmpty,
    );
  });
  for (final unresolved in <String?>[null, '']) {
    test(
      'unresolved profile $unresolved keeps legacy immediate sends but refuses queueing',
      () async {
        await store.commit(scope(unresolved), 'legacy retained');
        final chat = await open(profile: unresolved);
        final thread = chat.selectedThread!;
        expect(chat.queuedIn(thread), isEmpty);
        expect(await chat.submit('immediate', const []), true);
        expect(transport.sends.single.profile, unresolved);
        expect(await chat.submit('keep this draft', const []), false);
        expect(
          reports,
          contains(
            "This chat's profile could not be confirmed. Your draft was kept.",
          ),
        );
        expect(
          (await store.load(scope(unresolved))).records.single.text,
          'legacy retained',
        );
        expect(transport.sends, hasLength(1));
      },
    );
  }

  test('resolved default profile remains explicit after backend active profile changes', () async {
    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await store.commit(scope('work'), 'work retained');
    await store.commit(scope('personal'), 'personal retained');
    final chat = await open(profile: null, resolveProfile: true);
    final thread = chat.selectedThread!;
    expect(chat.profile, 'work');
    expect(chat.queuedIn(thread).single.text, 'work retained');
    server.on(
      'GET',
      '/api/profiles/active',
      activeProfileBody(active: 'personal'),
    );
    chat.sendQueued(thread);
    await transport.prepared;
    await pumpEventQueue();
    expect(transport.sends.single.profile, 'work');
    expect(
      (await store.load(scope('personal'))).records.single.text,
      'personal retained',
    );
    await chat.loadThreads();
    chat.select('stored');
    await queueIdle(chat);
    expect(chat.profile, 'personal');
    expect(
      chat.queuedIn(chat.selectedThread!).single.text,
      'personal retained',
    );
    expect(chat.queueNeedsReview(chat.selectedThread!), true);
    expect(transport.sends, hasLength(1));
  });

  test('missing durable chat stays remote in its original scope across activity recovery', () async {
    await store.commit(scope(), 'keep exact target');
    final chat = await open();
    activity.value = false;
    server.on('GET', '/api/sessions', sessionListBody([]));
    activity.value = true;
    await pumpEventQueue();
    final thread = chat.threads.single;
    expect(thread.id, 'stored');
    expect(thread.remote, true);
    expect(chat.queueAvailable(thread), false);
    expect(chat.queuedIn(thread).single.scope!.conversationId, 'stored');
    chat.sendQueued(thread);
    expect(await chat.submit('do not rebind', const []), false);
    expect(transport.sends, isEmpty);
    expect(
      (await store.load(scope())).records.single.text,
      'keep exact target',
    );
  });

  test(
    'profile switch during deletion cleans only the captured original scope',
    () async {
      await store.commit(scope('work'), 'delete work');
      await store.commit(scope('personal'), 'keep personal');
      final gate = Completer<FakeResponse>();
      server.onRequest('DELETE', '/api/sessions/stored', (_) => gate.future);
      final chat = await open();
      final removed = chat.housekeeping!.delete(chat.selectedThread!);
      await pumpEventQueue();
      await chat.loadThreads('personal');
      chat.select('stored');
      await queueIdle(chat);
      gate.complete((status: 200, body: {}));
      await removed;
      expect((await store.load(scope('work'))).records, isEmpty);
      expect(
        (await store.load(scope('personal'))).records.single.text,
        'keep personal',
      );
      expect(chat.selectedThread!.id, 'stored');
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'keep personal');
    },
  );

  test(
    'session reclaim during enqueue commit retains the draft and never queues',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
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
      final chat = await open();
      await chat.submit('opening', const []);
      final queued = Future.sync(() => chat.submit('kept draft', const []));
      await entered.future;
      transport.sends.single.emit(
        const SessionReclaimed('runtime', 'stored', 'retired'),
      );
      await pumpEventQueue();
      release.complete();
      expect(await queued, false);
      expect((await store.load(scope())).records, isEmpty);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
      expect(transport.sends, hasLength(1));
    },
  );

  test(
    'queue outcomes and user actions contain only fixed states and counts',
    () async {
      await store.commit(scope(), 'private prompt');
      final chat = await open();
      final thread = chat.selectedThread!;
      expect(
        outcomes
            .where((entry) => entry.$1 == 'chat.queue.recovery')
            .map((entry) => entry.$2),
        [
          {'outcome': 'recovered', 'count': 1},
        ],
      );
      chat.sendQueued(thread);
      await transport.prepared;
      await pumpEventQueue();
      expect(
        trail.recent
            .where((entry) => entry.name.startsWith('chat.queue.'))
            .map((entry) => entry.attributes),
        [
          {'count': 1, 'state': 'unsent'},
          {'count': 1, 'state': 'unsent'},
        ],
      );
      expect(outcomes.toString(), isNot(contains('private prompt')));
      expect((await store.load(scope())).records, isEmpty);
    },
  );

  test(
    'a failing recovery logger cannot grant sending or erase ownership',
    () async {
      await store.commit(scope(), 'retained');
      final chat = await open(loggerFails: true);
      expect(chat.queueNeedsReview(chat.selectedThread!), true);
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'retained');
      expect(transport.sends, isEmpty);
      expect(
        (await store.load(scope())).records.single.state,
        QueueRecordState.queued,
      );
    },
  );
}
