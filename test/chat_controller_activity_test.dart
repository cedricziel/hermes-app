import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ValueNotifier<bool> activity;
  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late FakeNotificationService notifications;
  late List<String> reports;
  late List<String> drafts;
  late ChatController chat;

  ChatController create({
    FakeHermesServer? server,
    bool profiles = false,
    VoidCallback? onShowChat,
  }) {
    final api = server?.client().raw;
    final controller = ChatController(
      activity: activity,
      transport: transport,
      repository: api == null ? null : HermesChatRepository(api),
      profiles: profiles ? HermesProfilesRepository(api!) : null,
      attention: attention,
      report: reports.add,
      onPrefill: drafts.add,
      onDraft: drafts.add,
      onShowChat: onShowChat,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    activity = ValueNotifier(true);
    transport = FakeChatTransport();
    reports = [];
    drafts = [];
    notifications = FakeNotificationService();
    attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    addTearDown(activity.dispose);
    addTearDown(notifications.dispose);
    addTearDown(attention.dispose);
  });

  test('an earlier pause listener cannot start a protected send', () {
    late FutureOr<bool> submitted;
    activity.addListener(() {
      if (!activity.value) submitted = chat.submit('blocked', const []);
    });
    chat = create();
    chat.newThread();
    final selected = chat.selectedThread!;

    activity.value = false;

    expect(submitted, isFalse);
    expect(transport.sends, isEmpty);
    expect(selected.messages, isEmpty);
  });

  test('a reentrant resume invalidates a held slash result', () async {
    activity.addListener(() {
      if (!activity.value) activity.value = true;
    });
    chat = create();
    chat.newThread();
    final selected = chat.selectedThread!;
    final gate = transport.slashGate = Completer<SlashCommandResult>();
    final running = chat.runSlashCommand('/review');

    activity.value = false;
    gate.complete(
      const SlashCommandResult(
        threadId: 'late',
        output: 'late',
        prefill: 'draft',
        prompt: 'expanded',
      ),
    );
    await running;

    expect(transport.sends, isEmpty);
    expect(selected.messages, isEmpty);
    expect(drafts, isEmpty);
  });

  testWidgets('a reentrant resume cannot drain an old reply queue', (
    tester,
  ) async {
    activity.addListener(() {
      if (!activity.value) activity.value = true;
    });
    chat = create();
    chat.newThread();
    chat.submit('original', const []);
    chat.submit('queued', const []);
    final selected = chat.selectedThread!;
    final send = transport.sends.single;

    activity.value = false;
    send.emit(const ReplyCompleted('late'));
    send.finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(transport.sends, hasLength(1));
    expect(chat.queuedIn(selected).single.text, 'queued');
    expect(selected.messages.last.content, isEmpty);
  });

  test('an earlier pause listener cannot start sidebar mutation', () async {
    late Future<void> renaming;
    activity.addListener(() {
      if (!activity.value) {
        renaming = chat.housekeeping!.rename(chat.threads.single, 'Blocked');
      }
    });
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'selected', title: 'Before')]),
      )
      ..on('PATCH', '/api/sessions/selected', {'title': 'Blocked'});
    chat = create(server: server);
    await chat.loadThreads('work');

    activity.value = false;
    await renaming;

    expect(server.requestsTo('PATCH', '/api/sessions/selected'), isEmpty);
    expect(chat.threads.single.title, 'Before');
  });

  test('pause during send notification prevents transport dispatch', () {
    chat = create();
    chat.newThread();
    final selected = chat.selectedThread!;
    chat.addListener(() {
      if (activity.value && selected.messages.isNotEmpty) {
        activity.value = false;
      }
    });

    final submitted = chat.submit('typed', const []);

    expect(transport.sends, isEmpty);
    expect(submitted, isFalse);
  });

  test(
    'pause during rename notification prevents the protected write',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Before')]),
        )
        ..on('PATCH', '/api/sessions/selected', {'title': 'Typed'});
      chat = create(server: server);
      await chat.loadThreads('work');
      final selected = chat.threads.single;
      chat.addListener(() {
        if (activity.value && selected.title == 'Typed') activity.value = false;
      });

      await chat.housekeeping!.rename(selected, 'Typed');

      expect(server.requestsTo('PATCH', '/api/sessions/selected'), isEmpty);
    },
  );

  test(
    'pause during command publication prevents expansion and prefill',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      final gate = transport.slashGate = Completer<SlashCommandResult>();
      final running = chat.runSlashCommand('/review');
      var suspended = false;
      chat.addListener(() {
        if (!suspended && selected.messages.isNotEmpty) {
          suspended = true;
          activity.value = false;
          activity.value = true;
        }
      });

      gate.complete(
        const SlashCommandResult(
          threadId: 'late',
          output: 'done',
          prefill: 'draft',
          prompt: 'expanded',
        ),
      );
      await running;

      expect(suspended, isTrue);
      expect(transport.sends, isEmpty);
      expect(drafts, isEmpty);
    },
  );

  test(
    'pause during reply publication prevents its private announcement',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      chat.submit('original', const []);
      chat.clearSelection();
      var suspended = false;
      chat.addListener(() {
        if (!suspended &&
            selected.messages.last.content == 'private completion') {
          suspended = true;
          activity.value = false;
          activity.value = true;
        }
      });

      transport.sends.single.emit(const ReplyCompleted('private completion'));
      await pumpEventQueue();

      expect(suspended, isTrue);
      expect(notifications.shown, isEmpty);
    },
  );

  test(
    'a local queue can be sent explicitly after its stream is suspended',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]));
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.newThread();
      final local = chat.selectedThread!;
      chat.submit('original', const []);
      chat.submit('queued', const []);
      activity.value = false;
      activity.value = true;
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      expect(chat.selectedThread, same(local));

      chat.sendQueued(local);

      expect(transport.sends, hasLength(2));
      expect(transport.sends.last.threadId, isNull);
      expect(transport.sends.last.text, 'queued');
    },
  );

  test(
    'pause during refreshed title publication prevents another lookup',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Before')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected',
          sessionRow(id: 'selected', title: 'Changed', lastActive: 1780001000),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        );
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('selected');
      await pumpEventQueue();
      final before = server
          .requestsTo('GET', '/api/sessions/selected/messages')
          .length;
      chat.addListener(() {
        if (activity.value && chat.selectedThread?.title == 'Changed') {
          activity.value = false;
        }
      });

      await chat.refreshThread('selected');

      expect(
        server.requestsTo('GET', '/api/sessions/selected/messages'),
        hasLength(before),
      );
    },
  );

  test(
    'reconciliation retains a fresh local send started after resume',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]));
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.newThread();
      final local = chat.selectedThread!;
      activity.value = false;
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/sessions', (_) => gate.future);

      activity.value = true;
      chat.submit('fresh', const []);
      await pumpEventQueue();
      gate.complete((status: 200, body: sessionListBody([])));
      await pumpEventQueue();

      expect(chat.selectedThread, same(local));
      expect(local.isReplying, isTrue);
      expect(local.messages.first.content, 'fresh');
      expect(local.messages.last.isPending, isTrue);
      expect(transport.sends, hasLength(1));
      expect(transport.sends.single.threadId, isNull);
    },
  );

  test('reconciliation retains a queue created during its lookup', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]));
    chat = create(server: server);
    await chat.loadThreads('work');
    chat.newThread();
    final local = chat.selectedThread!;
    activity.value = false;
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions', (_) => gate.future);
    activity.value = true;
    await pumpEventQueue();

    chat.submit('fresh', const []);
    chat.submit('new queue', const []);
    gate.complete((status: 200, body: sessionListBody([])));
    await pumpEventQueue();

    expect(chat.selectedThread, same(local));
    expect(local.isReplying, isTrue);
    expect(chat.queuedIn(local).single.text, 'new queue');
    expect(transport.sends, hasLength(1));
    expect(transport.sends.single.threadId, isNull);
  });

  test(
    'reconciliation retains a new local thread created during its lookup',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]));
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.newThread();
      final original = chat.selectedThread!;
      activity.value = false;
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/sessions', (_) => gate.future);
      activity.value = true;
      await pumpEventQueue();

      chat.newThread();
      final fresh = chat.selectedThread!;
      chat.submit('fresh', const []);
      chat.submit('new queue', const []);
      gate.complete((status: 200, body: sessionListBody([])));
      await pumpEventQueue();

      expect(chat.selectedThread, same(fresh));
      expect(chat.threads, containsAll([original, fresh]));
      expect(fresh.messages.first.content, 'fresh');
      expect(fresh.isReplying, isTrue);
      expect(chat.queuedIn(fresh).single.text, 'new queue');
      expect(transport.sends, hasLength(1));
      expect(transport.sends.single.threadId, isNull);
    },
  );

  test(
    'pause during external show callback retains the unapplied opening',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        );
      chat = create(
        server: server,
        onShowChat: () {
          activity.value = false;
          activity.value = true;
        },
      );
      await chat.loadThreads('work');

      chat.open(
        const NotificationTarget(threadId: 'selected', profile: 'work'),
        fetchMissing: false,
        prompt: 'retained intent',
      );
      await pumpEventQueue();

      expect(chat.selectedId, isNull);
      expect(
        server.requestsTo('GET', '/api/sessions/selected/messages'),
        isEmpty,
      );
      expect(drafts, isEmpty);
      expect(chat.takeInterruptedOpening()!.prompt, 'retained intent');
    },
  );

  test(
    'inactive actions preserve selection and issue no protected work',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      activity.value = false;

      expect(chat.submit('blocked', const []), isFalse);
      await chat.runSlashCommand('/new');
      await chat.slashCommands();
      chat.newThread();
      chat.select(chat.threads.last.id);
      chat.clearSelection();
      chat.open(
        const NotificationTarget(threadId: 'missing'),
        fetchMissing: true,
        prompt: 'blocked draft',
      );
      chat.checkConnection();
      await chat.refreshActive();
      await chat.stopReply(selected);

      expect(chat.selectedThread, same(selected));
      expect(selected.messages, isEmpty);
      expect(transport.sends, isEmpty);
      expect(transport.slashRuns, isEmpty);
      expect(transport.catalogContexts, isEmpty);
      expect(transport.activeAsked, isEmpty);
      expect(transport.stops, isEmpty);
      expect(transport.connectionChecks, 0);
      expect(drafts, isEmpty);
    },
  );

  test('a held slash result cannot publish output or an expanded prompt after pause', () async {
    chat = create();
    chat.newThread();
    final selected = chat.selectedThread!;
    final gate = transport.slashGate = Completer<SlashCommandResult>();
    final run = chat.runSlashCommand('/review');
    activity.value = false;
    expect(chat.takeInterruptedOpening(), isNull);
    gate.complete(
      const SlashCommandResult(
        threadId: 'late',
        output: 'late',
        prompt: 'expanded',
        prefill: 'draft',
      ),
    );
    await run;

    expect(chat.selectedThread, same(selected));
    expect(selected.messages, isEmpty);
    expect(transport.sends, isEmpty);
    expect(drafts, isEmpty);
  });

  test('late command errors are silent after pause and recovery', () async {
    chat = create();
    chat.newThread();
    final gate = transport.slashGate = Completer<SlashCommandResult>();
    final run = chat.runSlashCommand('/help');
    activity.value = false;
    activity.value = true;
    gate.completeError(StateError('old socket'));
    await run;

    expect(reports, isEmpty);
    expect(chat.selectedThread!.messages, isEmpty);
  });

  test(
    'reply and follow-up streams stop before late events mutate state',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      chat.submit('original', const []);
      final send = transport.sends.single;
      send.emit(const ThreadBound('remote'));
      await pumpEventQueue();
      activity.value = false;
      send.emit(const ReplyCompleted('late'));
      send.fail(StateError('old socket'));
      send.finish();
      await pumpEventQueue();

      expect(selected.messages.last.content, isEmpty);
      expect(reports, isEmpty);
      expect(transport.followUpCalls, 0);
      expect(notifications.shown, isEmpty);
    },
  );

  test(
    'a pending approval answer does not mutate the paused request',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      chat.submit('original', const []);
      transport.sends.single.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'approval',
            command: 'cmd',
            description: '',
            choices: ['once'],
          ),
        ),
      );
      await pumpEventQueue();
      final gate = transport.answerGate = Completer<void>();
      final answer = chat.answerApproval(selected, 'approval', 'once');
      activity.value = false;
      gate.complete();
      await answer;

      expect(
        (selected.messages.last.inputRequests.single as ApprovalRequest).choice,
        isNull,
      );
    },
  );

  test(
    'a held undo cannot remove the prompt or retry it after pause',
    () async {
      chat = create();
      chat.newThread();
      final selected = chat.selectedThread!;
      chat.submit('original', const []);
      final send = transport.sends.single;
      send.emit(const ThreadBound('remote'));
      send.emit(const ReplyCompleted('done'));
      send.finish();
      await pumpEventQueue();
      final gate = transport.undoGate = Completer<void>();
      final retry = chat.retry(selected);
      activity.value = false;
      gate.complete();
      await retry;

      expect(selected.messages.map((m) => m.content), ['original', 'done']);
      expect(transport.sends, hasLength(1));
      expect(transport.followUpStreams['remote']!.hasListener, isFalse);
    },
  );

  test('pause during undo publication prevents the protected write', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
      )
      ..on(
        'GET',
        '/api/sessions/selected/messages',
        messageListBody('selected', [
          messageRow(id: 1, role: 'user', content: 'original'),
          messageRow(id: 2, role: 'assistant', content: 'done'),
        ]),
      );
    chat = create(server: server);
    await chat.loadThreads('work');
    chat.select('selected');
    await pumpEventQueue();
    final selected = chat.selectedThread!;
    var suspended = false;
    chat.addListener(() {
      if (!suspended && chat.turnActionStatus(selected).running != null) {
        suspended = true;
        activity.value = false;
        activity.value = true;
      }
    });

    await chat.retry(selected);
    await pumpEventQueue();

    expect(suspended, isTrue);
    expect(transport.undos, isEmpty);
    expect(transport.sends, isEmpty);
    expect(selected.messages.map((message) => message.content), [
      'original',
      'done',
    ]);
    expect(drafts, isEmpty);
  });

  testWidgets('pause cancels the settle timer without submitting the queue', (
    tester,
  ) async {
    chat = create();
    chat.newThread();
    chat.submit('original', const []);
    chat.submit('queued', const []);
    final selected = chat.selectedThread!;
    final send = transport.sends.single;
    send.emit(const ReplyCompleted('done'));
    send.finish();
    await tester.pump();
    activity.value = false;
    await tester.pump(const Duration(seconds: 3));

    expect(transport.sends, hasLength(1));
    expect(chat.queuedIn(selected).single.text, 'queued');
  });

  test('late thread loading cannot replace retained profile state', () async {
    final server = FakeHermesServer();
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions', (_) => gate.future);
    chat = create(server: server);
    final load = chat.loadThreads('profile');
    await pumpEventQueue();
    activity.value = false;
    gate.complete((
      status: 200,
      body: sessionListBody([sessionRow(id: 'late', title: 'Late')]),
    ));
    await load;

    expect(chat.profile, isNull);
    expect(chat.threads, isEmpty);
    expect(chat.threadsFailed, isFalse);
  });

  testWidgets(
    'paused search ignores a held result and does not restart its timer',
    (tester) async {
      final server = FakeHermesServer();
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/sessions/search', (_) => gate.future);
      chat = create(server: server);
      chat.search!.update('first');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      activity.value = false;
      gate.complete((
        status: 200,
        body: {
          'results': [
            {'id': 'late', 'title': 'Late'},
          ],
        },
      ));
      await tester.pumpAndSettle();
      chat.search!.update('blocked');
      await tester.pump(const Duration(seconds: 1));

      expect(chat.search!.hits, isEmpty);
      expect(chat.search!.query, 'first');
      expect(server.requestsTo('GET', '/api/sessions/search'), hasLength(1));
    },
  );

  test(
    'resume reloads the selected profile and transcript without sending again',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/profiles', {
          'profiles': [
            {'name': 'work'},
          ],
        })
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', [
            messageRow(id: 1, role: 'assistant', content: 'before'),
          ]),
        );
      chat = create(server: server, profiles: true);
      await chat.loadThreads('work');
      chat.select('selected');
      await pumpEventQueue();
      activity.value = false;
      server.on(
        'GET',
        '/api/sessions/selected/messages',
        messageListBody('selected', [
          messageRow(id: 2, role: 'assistant', content: 'refreshed'),
        ]),
      );
      activity.value = true;
      await pumpEventQueue();

      expect(chat.profile, 'work');
      expect(chat.selectedId, 'selected');
      expect(chat.selectedThread!.messages.single.content, 'refreshed');
      expect(transport.sends, isEmpty);
      expect(server.requestsTo('GET', '/api/sessions'), hasLength(2));
    },
  );
  test(
    'an initially inactive controller never starts profile lookup or search',
    () async {
      final server = FakeHermesServer();
      activity.value = false;
      chat = create(server: server, profiles: true);
      await chat.loadThreads();
      chat.search!.update('blocked');
      await chat.housekeeping!.loadMore();

      expect(server.requests, isEmpty);
      expect(chat.profile, isNull);
      expect(chat.search!.query, isEmpty);
    },
  );

  test(
    'pause during profile lookup prevents the next session request',
    () async {
      final server = FakeHermesServer();
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles/active', (_) => gate.future);
      chat = create(server: server, profiles: true);
      final load = chat.loadThreads();
      await pumpEventQueue();
      activity.value = false;
      gate.complete((status: 200, body: {'active': 'work', 'current': 'work'}));
      await load;

      expect(server.requestsTo('GET', '/api/sessions'), isEmpty);
      expect(chat.profile, isNull);
    },
  );

  test('a late message page cannot change the retained transcript', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
      );
    final gate = Completer<FakeResponse>();
    server.onRequest(
      'GET',
      '/api/sessions/selected/messages',
      (_) => gate.future,
    );
    chat = create(server: server);
    await chat.loadThreads('work');
    chat.select('selected');
    final selected = chat.selectedThread!;
    await pumpEventQueue();
    activity.value = false;
    gate.complete((
      status: 200,
      body: messageListBody('selected', [
        messageRow(id: 1, role: 'assistant', content: 'late'),
      ]),
    ));
    await pumpEventQueue();

    expect(chat.selectedThread, same(selected));
    expect(selected.messages, isEmpty);
    expect(reports, isEmpty);
  });

  test(
    'late sidebar failure cannot roll back retained title or report an error',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Before')]),
        );
      final gate = Completer<FakeResponse>();
      server.onRequest('PATCH', '/api/sessions/selected', (_) => gate.future);
      chat = create(server: server);
      await chat.loadThreads('work');
      final selected = chat.threads.single;
      final rename = chat.housekeeping!.rename(selected, 'Typed title');
      await pumpEventQueue();
      activity.value = false;
      gate.complete((status: 500, body: {'detail': 'late'}));
      await rename;
      await chat.housekeeping!.rename(selected, 'blocked');
      await chat.housekeeping!.delete(selected);
      await chat.housekeeping!.archive(selected);
      await chat.housekeeping!.setPinned(selected, true);

      expect(selected.title, 'Typed title');
      expect(reports, isEmpty);
      expect(server.requests.where((r) => r.method != 'GET'), hasLength(1));
    },
  );

  test('a late approval error is ignored even after recovery', () async {
    chat = create();
    chat.newThread();
    final selected = chat.selectedThread!;
    chat.submit('original', const []);
    transport.sends.single.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'approval',
          command: 'cmd',
          description: '',
          choices: ['once'],
        ),
      ),
    );
    await pumpEventQueue();
    final gate = transport.answerGate = Completer<void>();
    final answer = chat.answerApproval(selected, 'approval', 'once');
    activity.value = false;
    activity.value = true;
    gate.completeError(StateError('retired'));
    await answer;

    expect(
      (selected.messages.last.inputRequests.single as ApprovalRequest).choice,
      isNull,
    );
    expect(reports, isEmpty);
  });

  testWidgets(
    'resume retains queued prompts without draining them on a remote completion',
    (tester) async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        );
      chat = create(server: server);
      await tester.runAsync(() async {
        await chat.loadThreads('work');
        chat.select('selected');
        await pumpEventQueue();
        chat.submit('original', const []);
        chat.submit('queued', const []);
        activity.value = false;
        activity.value = true;
        await pumpEventQueue();
      });
      transport.followUpStreams['selected']!.emit(const ReplyStarted());
      transport.followUpStreams['selected']!.emit(
        const ReplyCompleted('reconciled'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'queued');
    },
  );

  test('a held open cannot restore its draft after recovery', () async {
    final server = FakeHermesServer();
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions', (_) => gate.future);
    server.on(
      'GET',
      '/api/sessions/selected/messages',
      messageListBody('selected', []),
    );
    chat = create(server: server);
    final load = chat.loadThreads('work');
    await pumpEventQueue();
    chat.open(
      const NotificationTarget(threadId: 'selected', profile: 'work'),
      fetchMissing: true,
      prompt: 'retired draft',
    );
    activity.value = false;
    gate.complete((
      status: 200,
      body: sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
    ));
    await load;
    activity.value = true;
    await pumpEventQueue();

    expect(drafts, isEmpty);
    expect(chat.selectedId, isNull);
    final interrupted = chat.takeInterruptedOpening()!;
    expect(interrupted.target.threadId, 'selected');
    expect(interrupted.target.profile, 'work');
    expect(interrupted.prompt, 'retired draft');
    expect(interrupted.fetchMissing, isTrue);
    expect(chat.takeInterruptedOpening(), isNull);
  });

  test(
    'resume retains the queue of a selected chat outside the first page',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected',
          sessionRow(id: 'selected', title: 'Selected'),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        );
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('selected');
      await pumpEventQueue();
      chat.submit('original', const []);
      chat.submit('queued', const []);
      activity.value = false;
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'recent', title: 'Recent')]),
      );
      activity.value = true;
      await pumpEventQueue();

      expect(chat.selectedId, 'selected');
      expect(chat.queuedIn(chat.selectedThread!).map((prompt) => prompt.text), [
        'queued',
      ]);
      expect(transport.sends, hasLength(1));
    },
  );

  test(
    'resume preserves every older queue, including unavailable targets',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 'valid', title: 'Valid'),
            sessionRow(id: 'missing', title: 'Missing'),
            sessionRow(id: 'unreadable', title: 'Unreadable'),
            sessionRow(id: 'recent', title: 'Recent'),
          ]),
        )
        ..on(
          'GET',
          '/api/sessions/valid/messages',
          messageListBody('valid', []),
        )
        ..on(
          'GET',
          '/api/sessions/missing/messages',
          messageListBody('missing', []),
        )
        ..on(
          'GET',
          '/api/sessions/unreadable/messages',
          messageListBody('unreadable', []),
        )
        ..on(
          'GET',
          '/api/sessions/recent/messages',
          messageListBody('recent', []),
        )
        ..on(
          'GET',
          '/api/sessions/valid',
          sessionRow(id: 'valid', title: 'Refreshed'),
        )
        ..on('GET', '/api/sessions/unreadable', {
          'detail': 'Unavailable',
        }, status: 500);
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('valid');
      await pumpEventQueue();
      chat.submit('original valid', const []);
      chat.submit('queued valid', const []);
      chat.select('missing');
      await pumpEventQueue();
      chat.submit('original missing', const []);
      chat.submit('queued missing', const []);
      chat.select('unreadable');
      await pumpEventQueue();
      chat.submit('original unreadable', const []);
      chat.submit('queued unreadable', const []);
      chat.select('recent');
      await pumpEventQueue();
      activity.value = false;
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'recent', title: 'Recent')]),
      );
      activity.value = true;
      await pumpEventQueue();

      expect(
        chat.threads.map((thread) => thread.id),
        containsAll(['valid', 'missing', 'unreadable']),
      );
      final valid = chat.threads.firstWhere((thread) => thread.id == 'valid');
      final missing = chat.threads.firstWhere(
        (thread) => thread.id == 'missing',
      );
      final unreadable = chat.threads.firstWhere(
        (thread) => thread.id == 'unreadable',
      );
      expect(chat.queuedIn(valid).single.text, 'queued valid');
      expect(chat.queuedIn(missing).single.text, 'queued missing');
      expect(chat.queuedIn(unreadable).single.text, 'queued unreadable');
      expect(valid.remote, isTrue);
      expect(missing.remote, isFalse);
      expect(unreadable.remote, isFalse);
      expect(chat.queuePaused(missing), isTrue);
      expect(chat.queuePaused(unreadable), isTrue);
      expect(transport.sends, hasLength(3));
      expect(chat.selectedId, 'recent');
    },
  );

  test(
    'an interrupted HTTP open cannot block a fresh new chat after recovery',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        );
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/sessions/held', (_) => gate.future);
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('selected');
      await pumpEventQueue();
      chat.open(
        const NotificationTarget(threadId: 'held', profile: 'work'),
        fetchMissing: true,
        prompt: 'interrupted',
      );
      await pumpEventQueue();
      activity.value = false;
      activity.value = true;
      await pumpEventQueue();
      final fresh = chat.newThreadWhenOpened();
      await pumpEventQueue();

      try {
        expect(chat.selectedThread!.remote, isFalse);
        expect(chat.selectedThread!.messages, isEmpty);
        expect(drafts, isEmpty);
        final interrupted = chat.takeInterruptedOpening()!;
        expect(interrupted.target.threadId, 'held');
        expect(interrupted.prompt, 'interrupted');
      } finally {
        gate.complete((status: 404, body: {'detail': 'Missing'}));
        await fresh;
      }
    },
  );

  test('a newer explicit open supersedes the interrupted opening', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
      )
      ..on(
        'GET',
        '/api/sessions/selected/messages',
        messageListBody('selected', []),
      );
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions/held', (_) => gate.future);
    chat = create(server: server);
    await chat.loadThreads('work');
    chat.open(
      const NotificationTarget(threadId: 'held', profile: 'work'),
      fetchMissing: true,
      prompt: 'old intent',
    );
    await pumpEventQueue();
    activity.value = false;
    expect(chat.takeInterruptedOpening(), isNull);
    activity.value = true;
    await pumpEventQueue();
    chat.open(
      const NotificationTarget(threadId: 'selected', profile: 'work'),
      fetchMissing: false,
      prompt: 'new intent',
    );
    gate.complete((status: 404, body: {'detail': 'Missing'}));
    await pumpEventQueue();

    expect(chat.takeInterruptedOpening(), isNull);
    expect(chat.selectedId, 'selected');
    expect(drafts, ['new intent']);
  });

  test(
    'pause while publishing a fetched thread keeps its opening unapplied',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'selected', title: 'Selected')]),
        )
        ..on(
          'GET',
          '/api/sessions/selected/messages',
          messageListBody('selected', []),
        )
        ..on('GET', '/api/sessions/held', sessionRow(id: 'held', title: 'Held'))
        ..on('GET', '/api/sessions/held/messages', messageListBody('held', []));
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('selected');
      await pumpEventQueue();
      var suspended = false;
      chat.addListener(() {
        if (!suspended && chat.threads.any((thread) => thread.id == 'held')) {
          suspended = true;
          activity.value = false;
          activity.value = true;
        }
      });

      chat.open(
        const NotificationTarget(threadId: 'held', profile: 'work'),
        fetchMissing: true,
        prompt: 'interrupted draft',
      );
      await pumpEventQueue();

      expect(suspended, isTrue);
      expect(server.requestsTo('GET', '/api/sessions/held/messages'), isEmpty);
      expect(chat.selectedId, 'selected');
      expect(drafts, isEmpty);
      final interrupted = chat.takeInterruptedOpening()!;
      expect(interrupted.target.threadId, 'held');
      expect(interrupted.target.profile, 'work');
      expect(interrupted.fetchMissing, isTrue);
      expect(interrupted.prompt, 'interrupted draft');
      expect(chat.takeInterruptedOpening(), isNull);
    },
  );

  test('a removed profile cannot attach its queue to a same-ID chat on another profile', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles', profileListBody([profileRow(name: 'home')]))
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'home'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'shared', title: 'Work chat')]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'shared', title: 'Home chat')]),
        query: {'profile': 'home'},
      )
      ..on(
        'GET',
        '/api/sessions/shared/messages',
        messageListBody('shared', []),
      );
    chat = create(server: server, profiles: true);
    await chat.loadThreads('work');
    chat.select('shared');
    await pumpEventQueue();
    chat.submit('original work', const []);
    chat.submit('queued work', const []);
    activity.value = false;
    activity.value = true;
    await pumpEventQueue();

    final remote = chat.threads.singleWhere((thread) => thread.remote);
    expect(chat.profile, 'home');
    expect(remote.title, 'Home chat');
    expect(chat.queuedIn(remote), isEmpty);
    final draft = chat.threads.singleWhere((thread) => !thread.remote);
    expect(draft.title, 'Work chat');
    expect(chat.queuedIn(draft).single.text, 'queued work');
    expect(chat.selectedThread, same(draft));
    expect(transport.sends, hasLength(1));
  });

  test(
    'explicit send of an unavailable recovered queue creates a new session',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'missing', title: 'Missing')]),
        )
        ..on(
          'GET',
          '/api/sessions/missing/messages',
          messageListBody('missing', []),
        );
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.select('missing');
      await pumpEventQueue();
      chat.submit('original', const []);
      chat.submit('queued', const []);
      activity.value = false;
      server.on('GET', '/api/sessions', sessionListBody([]));
      activity.value = true;
      await pumpEventQueue();
      final draft = chat.selectedThread!;
      expect(transport.sends, hasLength(1));

      chat.sendQueued(draft);

      expect(transport.sends, hasLength(2));
      expect(transport.sends.last.threadId, isNull);
      expect(transport.sends.last.text, 'queued');
      expect(transport.sends.last.profile, 'work');
    },
  );

  test(
    'a retained unsent local thread stays unbound until a server binding',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]));
      chat = create(server: server);
      await chat.loadThreads('work');
      chat.newThread();
      final local = chat.selectedThread!;
      activity.value = false;
      activity.value = true;
      await pumpEventQueue();

      expect(chat.selectedThread, same(local));
      chat.submit('fresh', const []);

      expect(transport.sends.single.threadId, isNull);
      expect(transport.sends.single.profile, 'work');
    },
  );

  test(
    'suspension during loading notification prevents profile lookup',
    () async {
      final server = FakeHermesServer();
      chat = create(server: server, profiles: true);
      chat.addListener(() {
        if (chat.loadingThreads) activity.value = false;
      });

      await chat.loadThreads();

      expect(server.requests, isEmpty);
      expect(chat.profile, isNull);
      expect(chat.loadingThreads, isFalse);
    },
  );
  test('memory-only queue does not require durable recovery review', () async {
    chat = create();
    chat.newThread();
    final local = chat.selectedThread!;
    chat.submit('original', const []);
    chat.submit('queued', const []);
    activity.value = false;
    activity.value = true;
    await pumpEventQueue();
    expect(chat.queueNeedsReview(local), false);
    expect(chat.queuedIn(local).single.text, 'queued');
  });
}
