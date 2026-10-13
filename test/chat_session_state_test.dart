import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: FakeNotificationService(),
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    chat.newThread();
    chat.submit('Observe progress', const []);
  });
  tearDown(() {
    chat.dispose();
    attention.dispose();
  });
  const control = SessionControlSnapshot(
    revision: 'opaque',
    goal: {
      'status': 'paused',
      'turns_used': 2,
      'max_turns': 5,
      'paused_reason': 'Waiting for review',
    },
  );

  test(
    'control pauses and transient waits never complete the assistant reply',
    () async {
      transport.sends.last
        ..emit(const SessionControlUpdated(control, runtimeId: 'runtime-a'))
        ..emit(
          const SessionWaitUpdated(
            'process',
            'Waiting for process',
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const SessionWaitUpdated('process', '', runtimeId: 'runtime-a'));
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.sessionStateIn(thread)!.control, same(control));
      expect(chat.sessionStateIn(thread)!.waits, isEmpty);
      expect(thread.messages.last.isPending, isTrue);
    },
  );

  test(
    'control events between turns do not manufacture another assistant reply',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final before = thread.messages.length;
      transport.followUpStreams['stored-a']!.emit(
        const SessionControlUpdated(control, runtimeId: 'runtime-a'),
      );
      await pumpEventQueue();
      expect(chat.sessionStateIn(thread)!.control, same(control));
      expect(thread.messages, hasLength(before));
    },
  );

  test(
    'profile replacement clears controls and rejects the old event stream',
    () async {
      chat.dispose();
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'shared', title: 'Chat')]),
        )
        ..on(
          'GET',
          '/api/sessions/shared/messages',
          messageListBody('shared', []),
        );
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      await chat.loadThreads('one');
      chat.select('shared');
      await pumpEventQueue();
      chat.submit('First profile', const []);
      final oldThread = chat.selectedThread!;
      final oldSend = transport.sends.last;
      oldSend.emit(
        const SessionControlUpdated(control, runtimeId: 'one-runtime'),
      );
      await pumpEventQueue();
      expect(chat.sessionStateIn(oldThread)!.control, same(control));
      await chat.loadThreads('two');
      chat.select('shared');
      oldSend.emit(
        const SessionControlUpdated(control, runtimeId: 'one-runtime'),
      );
      await pumpEventQueue();
      expect(chat.sessionStateIn(oldThread), isNull);
      expect(chat.sessionStateIn(chat.selectedThread!), isNull);
    },
  );

  test(
    'session inspection breadcrumbs never carry control content or identity',
    () async {
      chat.dispose();
      final trail = BreadcrumbTrail();
      chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
        breadcrumbs: Breadcrumbs.of(trail),
      );
      chat.newThread();
      chat.sessionDetailsOpened();
      chat.reopenSession(chat.selectedThread!);
      expect(
        trail.recent
            .where((crumb) => crumb.name == 'chat.visibility_action')
            .map((crumb) => crumb.attributes),
        [
          {'feature': 'session_state', 'action': 'details'},
          {'feature': 'session_state', 'action': 'reopen'},
        ],
      );
    },
  );

  test(
    'reclaim retires requests and prevents queued prompts and new actions',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(
          const ApprovalRequested(
            ApprovalRequest(
              requestId: 'request-a',
              command: 'Private command',
              description: '',
              choices: ['once', 'deny'],
            ),
          ),
        );
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      chat.submit('Queued prompt', const []);
      transport.sends.last.emit(
        const SessionReclaimed(
          'runtime-a',
          'stored-a',
          'Private reclaim reason',
        ),
      );
      await pumpEventQueue();
      transport.sends.last.finish();
      await pumpEventQueue();
      chat.sendQueued(thread);
      await chat.answerApproval(thread, 'request-a', 'once');
      expect(chat.submit('Another prompt', const []), isFalse);
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread), hasLength(1));
      expect(
        thread.messages.last.inputRequests.single.status,
        InputRequestStatus.expired,
      );
      expect(
        chat.sessionStateIn(thread)!.reclaimedReason,
        'Private reclaim reason',
      );
      chat.reopenSession(thread);
      await pumpEventQueue();
      transport.followUpStreams['stored-a']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyCompleted('Another client finished'))
        ..emit(const SessionInfo(running: false));
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread), hasLength(1));
      chat.sendQueued(thread);
      expect(transport.sends, hasLength(2));
    },
  );

  test('an undo reply after reclaim cannot remove loaded history', () async {
    transport.sends.last
      ..emit(const ThreadBound('stored-a'))
      ..emit(const ReplyCompleted('Loaded answer'))
      ..finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    final before = thread.messages.map((message) => message.content).toList();
    transport.undoGate = Completer<void>();
    final edit = chat.editLastPrompt(thread);
    transport.followUpStreams['stored-a']!.emit(
      const SessionReclaimed(
        'runtime-a',
        'stored-a',
        'Another client took over',
      ),
    );
    await pumpEventQueue();
    transport.undoGate!.complete();
    await edit;

    expect(thread.messages.map((message) => message.content), before);
    expect(chat.sessionStateIn(thread)!.reclaimedReason, isNotNull);
  });

  test(
    'an undo response after reclaim and reopen cannot remove the current turn',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(const ReplyCompleted('Loaded answer'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      transport.undoGate = Completer<void>();
      final edit = chat.editLastPrompt(thread);
      transport.followUpStreams['stored-a']!.emit(
        const SessionReclaimed(
          'runtime-a',
          'stored-a',
          'Another client took over',
        ),
      );
      await pumpEventQueue();
      chat.reopenSession(thread);
      chat.submit('New turn after reopening', const []);
      final before = thread.messages.map((message) => message.content).toList();
      transport.undoGate!.complete();
      await edit;

      expect(thread.messages.map((message) => message.content), before);
      expect(transport.sends, hasLength(2));
    },
  );

  test(
    'a retry response after reclaim and reopen cannot submit the old prompt',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(const ReplyCompleted('Loaded answer'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      transport.undoGate = Completer<void>();
      final retry = chat.retry(thread);
      transport.followUpStreams['stored-a']!.emit(
        const SessionReclaimed(
          'runtime-a',
          'stored-a',
          'Another client took over',
        ),
      );
      await pumpEventQueue();
      chat.reopenSession(thread);
      final before = thread.messages.map((message) => message.content).toList();
      transport.undoGate!.complete();
      await retry;

      expect(thread.messages.map((message) => message.content), before);
      expect(transport.sends, hasLength(1));
    },
  );

  test('deleting a thread retires its pending undo bookkeeping', () async {
    chat.dispose();
    final server = FakeHermesServer()
      ..on('DELETE', '/api/sessions/stored-a', {'ok': true});
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    chat.newThread();
    chat.submit('Loaded prompt', const []);
    transport.sends.last
      ..emit(const ThreadBound('stored-a'))
      ..emit(const ReplyCompleted('Loaded answer'))
      ..finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    transport.undoGate = Completer<void>();
    final edit = chat.editLastPrompt(thread);
    expect(chat.turnActionStatus(thread).running, isNotNull);

    await chat.housekeeping!.delete(thread);
    transport.undoGate!.complete();
    await edit;

    expect(chat.selectedThread, isNull);
    expect(chat.turnActionStatus(thread).running, isNull);
  });

  test(
    'a changed stored session ID retires an earlier undo response',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(const ReplyCompleted('Loaded answer'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final before = thread.messages.map((message) => message.content).toList();
      transport.undoGate = Completer<void>();
      final edit = chat.editLastPrompt(thread);
      transport.followUpStreams['stored-a']!.emit(
        const SessionInfo(storedSessionId: 'stored-b'),
      );
      await pumpEventQueue();
      transport.undoGate!.complete();
      await edit;

      expect(thread.id, 'stored-b');
      expect(thread.messages.map((message) => message.content), before);
      expect(chat.turnActionStatus(thread).running, isNull);
    },
  );

  test('an unchanged stored session ID preserves an active undo', () async {
    transport.sends.last
      ..emit(const ThreadBound('stored-a'))
      ..emit(const ReplyCompleted('Loaded answer'))
      ..finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    transport.undoGate = Completer<void>();
    final edit = chat.editLastPrompt(thread);
    transport.followUpStreams['stored-a']!.emit(
      const SessionInfo(storedSessionId: 'stored-a'),
    );
    await pumpEventQueue();
    transport.undoGate!.complete();
    await edit;

    expect(thread.id, 'stored-a');
    expect(thread.messages, isEmpty);
    expect(chat.turnActionStatus(thread).running, isNull);
  });

  test(
    'hydration failure retains history and reopening does not resubmit prompts',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('stored-a'))
        ..emit(
          const SessionResumeProgress(
            ResumeProgress(
              'history',
              'failed',
              message: 'Could not restore tools',
            ),
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ReplyCompleted('Loaded answer'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.sessionStateIn(thread)!.resume!.status, 'failed');
      final before = thread.messages.length;
      chat.reopenSession(thread);
      await pumpEventQueue();
      expect(thread.messages, hasLength(before));
      expect(transport.sends, hasLength(1));
    },
  );

  test('session state logs carry fixed outcomes and telemetry failure cannot break control', () async {
    chat.dispose();
    final seen = <Map<String, Object>>[];
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      events: (name, [attributes = const {}]) {
        if (name == 'gateway.visibility_outcome') {
          seen.add(Map.from(attributes));
        }
        throw StateError('Telemetry unavailable');
      },
    );
    chat.newThread();
    chat.submit('Private prompt', const []);
    transport.sends.last.emit(
      const SessionControlUpdated(control, runtimeId: 'private-runtime'),
    );
    await pumpEventQueue();
    expect(chat.sessionStateIn(chat.selectedThread!)!.control, same(control));
    expect(seen, [
      {'feature': 'session_state', 'outcome': 'applied'},
    ]);
  });
}
