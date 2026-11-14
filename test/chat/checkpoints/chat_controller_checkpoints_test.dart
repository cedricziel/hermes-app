import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_controller.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/transcript_outcome.dart';
import 'package:hermes_app/src/chat/context/context_controller.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_chat_transport.dart';
import '../../support/fake_checkpoints_transport.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/fake_notification_service.dart';

/// Invented text a prompt could hold; it must never reach a record.
const _prompt = 'Draft the quarterly note for the garden club';
final _hash = 'b' * 40;

/// A chat transport that owns runtimes and answers the checkpoint and
/// context calls from a [FakeCheckpointsTransport].
class _Source extends FakeChatTransport
    implements OwnedSessionTransport, CheckpointsTransport, ContextTransport {
  final fake = FakeCheckpointsTransport();
  final owned = <String, OwnedSessionBinding>{};
  final reads = <String>[];
  Map<String, Object?> usage = const {
    'total': 10,
    'context_used': 1000,
    'context_max': 10000,
    'context_percent': 10,
  };
  var changes = StreamController<OwnedSessionChange>.broadcast(sync: true);

  OwnedSessionBinding own(String thread, {String runtime = 'rt-1'}) {
    final binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: runtime,
      profile: 'work',
    );
    owned[thread] = binding;
    changes.add(OwnedSessionChange(thread, binding));
    return binding;
  }

  void lose(String thread, {bool retired = false}) {
    final binding = owned[thread]!;
    if (retired) owned.remove(thread);
    changes.add(
      OwnedSessionChange(thread, binding, connected: false, retired: retired),
    );
  }

  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      profile == 'work' ? owned[threadId] : null;

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async {
    reads.add(method);
    return usage;
  }

  @override
  Future<CheckpointList> listCheckpoints(OwnedSessionBinding binding) =>
      fake.listCheckpoints(binding);

  @override
  Future<CheckpointList> listCheckpointsResuming(
    String threadId, {
    String? profile,
  }) => fake.listCheckpointsResuming(threadId, profile: profile);

  @override
  Future<CheckpointChanges> checkpointChanges(
    OwnedSessionBinding binding,
    String hash,
  ) => fake.checkpointChanges(binding, hash);

  @override
  Future<CheckpointRestore> restoreCheckpoint(
    String threadId, {
    String? profile,
    required String hash,
    String? filePath,
  }) => fake.restoreCheckpoint(
    threadId,
    profile: profile,
    hash: hash,
    filePath: filePath,
  );

  @override
  Future<ContextBreakdown> contextBreakdown(OwnedSessionBinding binding) =>
      fake.contextBreakdown(binding);

  @override
  Future<CompressionResult> compressSession(
    String threadId, {
    String? profile,
    String? focus,
  }) => fake.compressSession(threadId, profile: profile, focus: focus);

  @override
  Future<void> close() async {
    await changes.close();
    await super.close();
  }
}

class _Lock extends AppLockController {
  _Lock() : super(coverWhenInactive: false);
  var _covered = false;
  @override
  bool get covered => _covered;
  void cover(bool value) {
    _covered = value;
    notifyListeners();
  }
}

List<Map<String, Object?>> _rows({bool withPrompt = true}) => [
  if (withPrompt) messageRow(id: 1, role: 'user', content: _prompt),
  messageRow(
    id: 2,
    role: 'assistant',
    content: 'Done.',
    toolCalls: [functionCall('write_file', '{}')],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late _Source source;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeNotificationService notifications;
  late BreadcrumbTrail trail;
  late _Lock lock;
  late List<(String, Map<String, Object>)> events;
  late List<String> drafts;

  ChatController build({ValueListenable<bool>? activity}) => ChatController(
    repository: HermesChatRepository(server.client().raw),
    transport: source,
    attention: attention,
    appLock: lock,
    activity: activity,
    breadcrumbs: Breadcrumbs.of(trail),
    events: (name, [attributes = const {}]) => events.add((name, attributes)),
    onDraft: drafts.add,
    report: (_) {},
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'First'),
          sessionRow(id: 'stored-2', title: 'Second'),
        ]),
      )
      ..on('GET', '/api/sessions/stored-1', sessionRow(id: 'stored-1'))
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', _rows()),
      )
      ..on(
        'GET',
        '/api/sessions/stored-2/messages',
        messageListBody('stored-2', []),
      );
    source = _Source();
    notifications = FakeNotificationService();
    attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    trail = BreadcrumbTrail();
    lock = _Lock();
    events = [];
    drafts = [];
    chat = build();
  });

  tearDown(() async {
    chat.dispose();
    attention.dispose();
    lock.dispose();
    await source.close();
  });

  Future<ChatThread> open([String id = 'stored-1']) async {
    await chat.loadThreads('work');
    chat.select(id);
    await pumpEventQueue();
    return chat.selectedThread!;
  }

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);

  /// Opens the panel on a live chat with one checkpoint listed.
  Future<(ChatThread, CheckpointsController)> listed() async {
    final opened = await open();
    source.own('stored-1');
    source.fake.list = CheckpointsOn([
      Checkpoint(hash: _hash, reason: CheckpointReason.beforeEdit),
    ]);
    final checkpoints = chat.checkpointsIn(opened)!;
    await checkpoints.panelOpened();
    return (opened, checkpoints);
  }

  group('creation', () {
    test(
      'one controller of each per stored chat, created when asked for',
      () async {
        final opened = await open();
        final checkpoints = chat.checkpointsIn(opened);
        final context = chat.contextIn(opened);
        expect(checkpoints, isNotNull);
        expect(context, isNotNull);
        expect(chat.checkpointsIn(opened), same(checkpoints));
        expect(chat.contextIn(opened), same(context));
        expect(
          chat.checkpointsIn(thread('stored-2')),
          isNot(same(checkpoints)),
        );
      },
    );

    test('none for a chat not stored yet, an inactive controller, or a '
        'transport without the features', () async {
      await open();
      chat.newThread();
      final draft = chat.selectedThread!;
      expect(draft.remote, isFalse);
      expect(chat.checkpointsIn(draft), isNull);
      expect(chat.contextIn(draft), isNull);

      chat.dispose();
      final gate = ValueNotifier(true);
      addTearDown(gate.dispose);
      chat = build(activity: gate);
      final opened = await open();
      gate.value = false;
      await pumpEventQueue();
      expect(chat.checkpointsIn(opened), isNull);
      expect(chat.contextIn(opened), isNull);

      chat.dispose();
      final plain = FakeChatTransport();
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: plain,
        attention: attention,
        report: (_) {},
      );
      final other = await open();
      expect(chat.checkpointsIn(other), isNull);
      expect(chat.contextIn(other), isNull);
    });
  });

  group('scope binding', () {
    test('a stored chat with no live runtime says "Not checked yet" and '
        'resumes only when opened', () async {
      final opened = await open();
      final checkpoints = chat.checkpointsIn(opened)!;
      expect(checkpoints.rowState, CheckpointsRowState.notChecked);
      await checkpoints.panelOpened();
      expect(source.fake.calls, isEmpty);
      await checkpoints.openResuming();
      expect(source.fake.calls, ['listResuming']);
    });

    test('binds on establish, goes stale on loss, binds again and drops '
        'the runtime when it is retired', () async {
      final opened = await open();
      final checkpoints = chat.checkpointsIn(opened)!;
      final context = chat.contextIn(opened)!;
      source.own('stored-1');
      await pumpEventQueue();
      expect(checkpoints.rowState, CheckpointsRowState.hidden);
      await checkpoints.panelOpened();
      expect(source.fake.calls, ['list']);
      expect(context.compressRefusal, isNull);

      source.lose('stored-1');
      expect(checkpoints.notUpToDate, isTrue);
      expect(context.notUpToDate, isTrue);
      expect(context.compressRefusal, CompressRefusal.disconnected);

      source.own('stored-1', runtime: 'rt-2');
      await pumpEventQueue();
      expect(checkpoints.notUpToDate, isFalse);
      expect(context.notUpToDate, isFalse);
      expect(chat.checkpointsIn(opened), same(checkpoints));

      source.lose('stored-1', retired: true);
      await pumpEventQueue();
      expect(checkpoints.rowState, CheckpointsRowState.notChecked);
      expect(context.compressRefusal, CompressRefusal.unavailable);
    });

    test('a turn that ends re-reads the open list', () async {
      final (_, checkpoints) = await listed();
      expect(source.fake.count('list'), 1);
      chat.submit('Another question', const []);
      await pumpEventQueue();
      source.sends.last
        ..emit(const ReplyCompleted('Answer'))
        ..finish();
      await pumpEventQueue();
      expect(source.fake.count('list'), greaterThanOrEqualTo(2));
      checkpoints.panelClosed();
    });

    test('a thread whose stored id rotates keeps its controllers', () async {
      final opened = await open();
      source.own('stored-1');
      final checkpoints = chat.checkpointsIn(opened)!;
      source.followUpStreams['stored-1']!.emit(
        const SessionInfo(storedSessionId: 'stored-9'),
      );
      await pumpEventQueue();
      expect(opened.id, 'stored-9');
      expect(chat.checkpointsIn(opened), same(checkpoints));
    });
  });

  group('usage push', () {
    test(
      'a usage tick and a session.info usage reach the Context row',
      () async {
        final opened = await open();
        final binding = source.own('stored-1');
        final context = chat.contextIn(opened)!;
        final stream = source.followUpStreams['stored-1']!;
        stream.emit(
          SessionUsageUpdated(
            UsageSnapshot.decode({
              'context_used': 2000,
              'context_max': 10000,
              'context_percent': 20,
            }),
            runtimeId: binding.runtimeId,
            connection: binding.connection,
          ),
        );
        await pumpEventQueue();
        expect(context.figures?.used, 2000);
        expect(chat.usageIn(opened)!.snapshot!.contextUsed, 2000);

        stream.emit(
          SessionInfo(
            running: false,
            usage: UsageSnapshot.decode({
              'context_used': 3000,
              'context_max': 10000,
              'context_percent': 30,
            }),
            usageRuntimeId: binding.runtimeId,
            usageConnection: binding.connection,
          ),
        );
        await pumpEventQueue();
        expect(chat.usageIn(opened)!.snapshot!.contextUsed, 3000);
        expect(context.figures?.percent, 30);

        // Another runtime's usage is not this chat's.
        stream.emit(
          SessionInfo(
            usage: UsageSnapshot.decode({
              'context_used': 9000,
              'context_max': 10000,
              'context_percent': 90,
            }),
            usageRuntimeId: 'rt-other',
            usageConnection: binding.connection,
          ),
        );
        await pumpEventQueue();
        expect(context.figures?.percent, 30);
      },
    );

    test('a retired session leaves the row without usage', () async {
      final opened = await open();
      final binding = source.own('stored-1');
      final context = chat.contextIn(opened)!;
      source.followUpStreams['stored-1']!.emit(
        SessionUsageUpdated(
          UsageSnapshot.decode({
            'context_used': 2000,
            'context_max': 10000,
            'context_percent': 20,
          }),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      expect(context.hasRow, isTrue);
      source.lose('stored-1', retired: true);
      await pumpEventQueue();
      expect(context.hasRow, isFalse);
    });
  });

  group('bridge', () {
    test('a running reply refuses a full restore and a compress', () async {
      final (opened, checkpoints) = await listed();
      final context = chat.contextIn(opened)!;
      expect(checkpoints.restoreRefusal(), isNull);
      chat.submit('Another question', const []);
      await pumpEventQueue();
      expect(opened.isReplying, isTrue);
      expect(checkpoints.restoreRefusal(), RestoreRefusal.replying);
      expect(context.compressRefusal, CompressRefusal.replying);
    });

    test('the quote is the last prompt; failed prompts, commands run here '
        'and rows Hermes typed do not count', () async {
      final (opened, checkpoints) = await listed();
      final prompt = opened.messages.firstWhere((m) => m.isPrompt);
      opened.messages.addAll([
        ChatMessage(
          id: 'stored-1-local-9',
          role: ChatRole.user,
          createdAt: DateTime.utc(2030),
          content: '/usage',
        ),
        ChatMessage(
          id: 'stored-1-10',
          role: ChatRole.user,
          createdAt: DateTime.utc(2030),
          content: 'Continue where you left off',
          displayKind: 'auto_continue',
        ),
        ChatMessage(
          id: 'stored-1-local-11',
          role: ChatRole.user,
          createdAt: DateTime.utc(2030),
          content: 'Never sent',
          status: MessageStatus.error,
        ),
      ]);
      final intent = checkpoints.beginRestore(_hash)!;
      expect(intent.quote?.messageId, prompt.id);
      expect(intent.quote?.text, _prompt);
    });

    test('a file edit tool call tells "off" from hidden', () async {
      final opened = await open();
      source.own('stored-1');
      source.fake.list = const CheckpointsOff();
      final checkpoints = chat.checkpointsIn(opened)!;
      await checkpoints.panelOpened();
      expect(checkpoints.rowState, CheckpointsRowState.off);

      server.on(
        'GET',
        '/api/sessions/stored-2/messages',
        messageListBody('stored-2', [
          messageRow(
            id: 1,
            role: 'assistant',
            content: 'Looked.',
            toolCalls: [functionCall('read_file', '{}')],
          ),
        ]),
      );
      chat.select('stored-2');
      await pumpEventQueue();
      source.own('stored-2', runtime: 'rt-2');
      final other = chat.checkpointsIn(thread('stored-2'))!;
      await other.panelOpened();
      expect(other.rowState, CheckpointsRowState.hidden);
    });

    test('a full restore that removed the prompt hands it back under the '
        'draft, once the re-read chat no longer holds it', () async {
      final (_, checkpoints) = await listed();
      source.fake.restore = const Restored(historyRemoved: 2);
      server.on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', _rows(withPrompt: false)),
      );
      final reads = server.requestsTo('GET', '/api/sessions/stored-1/messages');
      final before = reads.length;
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      expect(
        server.requestsTo('GET', '/api/sessions/stored-1/messages').length,
        before + 1,
      );
      expect(drafts, [_prompt]);
      expect(checkpoints.outcome?.kind, RestoreOutcomeKind.restored);
      expect(checkpoints.outcome?.lastMessageNotRemoved, isFalse);
    });

    test('the composer is left alone while the re-read chat still holds '
        'the prompt', () async {
      final (_, checkpoints) = await listed();
      source.fake.restore = const Restored(historyRemoved: 1);
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      expect(drafts, isEmpty);
      expect(checkpoints.outcome?.lastMessageNotRemoved, isTrue);
    });

    test('a prompt sent in this visit (local id) still counts as held after '
        'the re-read gave it a server id', () async {
      final (opened, checkpoints) = await listed();
      final index = opened.messages.indexWhere((m) => m.isPrompt);
      final prompt = opened.messages[index];
      opened.messages[index] = ChatMessage(
        id: 'stored-1-local-77',
        role: prompt.role,
        createdAt: prompt.createdAt,
        content: prompt.content,
      );
      source.fake.restore = const Restored(historyRemoved: 1);
      // The re-read still holds the same prompt, now under its server id.
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      expect(drafts, isEmpty);
      expect(checkpoints.outcome?.lastMessageNotRemoved, isTrue);
    });

    test('a re-read that fails leaves the composer alone', () async {
      final (_, checkpoints) = await listed();
      source.fake.restore = const Restored(historyRemoved: 1);
      server.on('GET', '/api/sessions/stored-1', null, status: 500);
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      expect(drafts, isEmpty);
      expect(checkpoints.outcome?.kind, RestoreOutcomeKind.restored);
    });

    test(
      'a session gone re-establishes it once and never restores again',
      () async {
        final (_, checkpoints) = await listed();
        source.fake.restore = const RestoreFailed(
          CheckpointFailureKind.sessionGone,
          filesPossiblyChanged: false,
        );
        final checks = source.connectionChecks;
        await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
        expect(source.connectionChecks, checks + 1);
        expect(source.fake.count('restore'), 1);
        expect(checkpoints.outcome?.kind, RestoreOutcomeKind.sessionGone);
      },
    );
  });

  group('send hold', () {
    for (final (name, result) in <(String, CheckpointRestore?)>[
      ('success', const Restored(historyRemoved: 0)),
      (
        'failure',
        const RestoreFailed(
          CheckpointFailureKind.other,
          filesPossiblyChanged: false,
        ),
      ),
      ('lost answer', null),
    ]) {
      test('a prompt queued during a full restore waits for it to settle '
          '($name)', () async {
        final (opened, checkpoints) = await listed();
        final gate = source.fake.restoreGate = Completer<void>();
        if (result != null) source.fake.restore = result;
        final sends = source.sends.length;
        final confirming = checkpoints.confirmRestore(
          checkpoints.beginRestore(_hash)!,
        );
        expect(chat.sendHeldIn(opened), isTrue);
        expect(chat.submit('Next step please', const []), isTrue);
        await pumpEventQueue();
        expect(source.sends.length, sends);
        expect(chat.queuedIn(opened), isNotEmpty);
        if (result == null) {
          gate.completeError(StateError('connection dropped'));
        } else {
          gate.complete();
        }
        await confirming;
        await pumpEventQueue();
        expect(chat.sendHeldIn(opened), isFalse);
        expect(source.sends.length, sends + 1);
        expect(source.fake.count('restore'), 1);
      });
    }

    test('the 2 s settle wait of a queue ending during the hold defers to the '
        'release, which sends once', () async {
      final (opened, checkpoints) = await listed();
      chat.submit('First', const []);
      await pumpEventQueue();
      chat.submit('Second', const []);
      await pumpEventQueue();
      final first = source.sends.last;
      first
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      expect(chat.queuedIn(opened), isNotEmpty);
      final sends = source.sends.length;
      final gate = source.fake.restoreGate = Completer<void>();
      final confirming = checkpoints.confirmRestore(
        checkpoints.beginRestore(_hash)!,
      );
      expect(chat.sendHeldIn(opened), isTrue);
      // The settle timer fires while the hold is on: nothing is sent.
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(source.sends.length, sends);
      gate.complete();
      await confirming;
      await pumpEventQueue();
      expect(source.sends.length, sends + 1);
      expect(source.sends.last.text, 'Second');
    });

    test(
      'a settle wait that ends after no hold sends the queue as before',
      () async {
        final (opened, _) = await listed();
        chat.submit('First', const []);
        await pumpEventQueue();
        chat.submit('Second', const []);
        await pumpEventQueue();
        source.sends.last
          ..emit(const ReplyCompleted('Done'))
          ..finish();
        await pumpEventQueue();
        final sends = source.sends.length;
        await Future<void>.delayed(const Duration(milliseconds: 2300));
        expect(source.sends.length, sends + 1);
        expect(chat.sendHeldIn(opened), isFalse);
      },
    );

    test('clearing the chat ends the hold but never sends the queued prompt: '
        'the restore may still be running on the server', () async {
      final (opened, checkpoints) = await listed();
      source.fake.restoreGate = Completer<void>();
      final sends = source.sends.length;
      unawaited(checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!));
      chat.submit('Next step please', const []);
      await pumpEventQueue();
      expect(source.sends.length, sends);
      // The transport's ownership stream ends: everything owned is cleared.
      await source.changes.close();
      await pumpEventQueue();
      expect(chat.sendHeldIn(opened), isFalse);
      expect(source.sends.length, sends);
      expect(chat.queuedIn(opened), isNotEmpty);
    });

    test('Retry, Edit and Branch wait for a full restore: a second undo would '
        'take a second turn', () async {
      final (opened, checkpoints) = await listed();
      expect(chat.canEditLastPrompt(opened), isTrue);
      expect(chat.canBranch(opened), isTrue);
      source.fake.restoreGate = Completer<void>();
      final confirming = checkpoints.confirmRestore(
        checkpoints.beginRestore(_hash)!,
      );
      expect(chat.canEditLastPrompt(opened), isFalse);
      expect(chat.canBranch(opened), isFalse);
      await chat.retry(opened);
      await pumpEventQueue();
      expect(source.undos, isEmpty);
      source.fake.restoreGate!.complete();
      await confirming;
      expect(chat.canEditLastPrompt(opened), isTrue);
    });

    test('a full restore and a compress are refused while a Retry or Edit '
        'undo is in flight', () async {
      final (opened, checkpoints) = await listed();
      final context = chat.contextIn(opened)!;
      source.undoGate = Completer<void>();
      unawaited(chat.retry(opened));
      await pumpEventQueue();
      expect(checkpoints.restoreRefusal(), RestoreRefusal.replying);
      expect(context.compressRefusal, CompressRefusal.replying);
      source.undoGate!.complete();
      await pumpEventQueue();
    });

    test('a full restore stays refused from the Retry undo to its send: '
        'there is no gap in which the chat looks idle', () async {
      final (opened, checkpoints) = await listed();
      source.undoGate = Completer<void>();
      unawaited(chat.retry(opened));
      await pumpEventQueue();
      source.undoGate!.complete();
      for (var i = 0; i < 40; i++) {
        await Future<void>.value();
        expect(checkpoints.restoreRefusal(), isNotNull, reason: 'step $i');
      }
      await pumpEventQueue();
    });

    test('a compress waits while a full restore runs', () async {
      final (opened, checkpoints) = await listed();
      final context = chat.contextIn(opened)!;
      source.fake.restoreGate = Completer<void>();
      final confirming = checkpoints.confirmRestore(
        checkpoints.beginRestore(_hash)!,
      );
      expect(context.compressRefusal, CompressRefusal.replying);
      expect(context.beginCompress(), isNull);
      source.fake.restoreGate!.complete();
      await confirming;
      expect(context.compressRefusal, isNull);
    });
  });

  group('lock, sign-out and switch', () {
    test('App Lock reaches both controllers', () async {
      final (opened, checkpoints) = await listed();
      final context = chat.contextIn(opened)!;
      expect(checkpoints.checkpoints, isNotEmpty);
      lock.cover(true);
      expect(checkpoints.locked, isTrue);
      expect(checkpoints.checkpoints, isEmpty);
      expect(context.locked, isTrue);
      lock.cover(false);
      expect(checkpoints.locked, isFalse);
      // A controller made under App Lock starts locked.
      lock.cover(true);
      expect(chat.checkpointsIn(thread('stored-2'))!.locked, isTrue);
    });

    test('a profile switch drops every controller and outcome', () async {
      final (opened, checkpoints) = await listed();
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      expect(chat.outcomeLinesIn(opened), hasLength(1));
      await chat.loadThreads('other');
      await chat.loadThreads('work');
      final again = thread('stored-1');
      expect(chat.outcomeLinesIn(again), isEmpty);
      expect(chat.checkpointsIn(again), isNot(same(checkpoints)));
    });

    test('a re-read thread list keeps the controllers and a restore in '
        'flight', () async {
      final (opened, checkpoints) = await listed();
      final gate = source.fake.restoreGate = Completer<void>();
      final confirming = checkpoints.confirmRestore(
        checkpoints.beginRestore(_hash)!,
      );
      await chat.loadThreads('work');
      final same_ = thread('stored-1');
      expect(chat.checkpointsIn(same_), same(checkpoints));
      gate.complete();
      await confirming;
      expect(chat.outcomeLinesIn(same_), hasLength(1));
      expect(opened.id, same_.id);
    });

    test('dispose ends a hold without sending', () async {
      final (_, checkpoints) = await listed();
      source.fake.restoreGate = Completer<void>();
      unawaited(checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!));
      chat.submit('Next step please', const []);
      await pumpEventQueue();
      final sends = source.sends.length;
      chat.dispose();
      await pumpEventQueue();
      expect(source.sends.length, sends);
      chat = build();
    });
  });

  group('outcome lines', () {
    test('a restore started in one chat lands there after another opened, '
        'and its prompt waits for that chat\'s composer', () async {
      final (opened, checkpoints) = await listed();
      final gate = source.fake.restoreGate = Completer<void>();
      source.fake.restore = const Restored(historyRemoved: 2);
      server.on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', _rows(withPrompt: false)),
      );
      final confirming = checkpoints.confirmRestore(
        checkpoints.beginRestore(_hash)!,
      );
      chat.select('stored-2');
      await pumpEventQueue();
      gate.complete();
      await confirming;
      expect(chat.outcomeLinesIn(opened), hasLength(1));
      expect(chat.outcomeLinesIn(thread('stored-2')), isEmpty);
      expect(drafts, isEmpty);
      chat.select('stored-1');
      await pumpEventQueue();
      expect(drafts, [_prompt]);
    });

    test('a line appears once per outcome and survives a re-read', () async {
      final (opened, checkpoints) = await listed();
      final context = chat.contextIn(opened)!;
      source.fake.compress = const Compressed(
        beforeMessages: 42,
        afterMessages: 9,
        fallbackUsed: true,
      );
      await context.confirmCompress(context.beginCompress()!);
      await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
      checkpoints.notifyListeners();
      context.notifyListeners();
      final lines = chat.outcomeLinesIn(opened);
      expect(lines.map((l) => l.kind), [
        TranscriptOutcomeKind.compressed,
        TranscriptOutcomeKind.restored,
      ]);
      expect(lines.first.beforeMessages, 42);
      expect(lines.first.afterMessages, 9);
      expect(lines.first.fallbackUsed, isTrue);
      expect(lines.last.removedMessages, isFalse);
      await chat.refreshThread('stored-1');
      expect(chat.outcomeLinesIn(opened), hasLength(2));
      source.fake.compress = const NothingToCompress();
      await context.confirmCompress(context.beginCompress()!);
      expect(chat.outcomeLinesIn(opened), hasLength(2));
    });
  });

  group('compaction', () {
    test('Hermes compacting on its own re-reads the usage, and nothing '
        'else happens', () async {
      final opened = await open();
      source.own('stored-1');
      chat.contextIn(opened);
      final messages = opened.messages.length;
      final stream = source.followUpStreams['stored-1']!;
      var notified = 0;
      void count() => notified++;
      chat.addListener(count);
      stream.emit(const ContextCompacted(runtimeId: 'rt-1'));
      await pumpEventQueue();
      chat.removeListener(count);
      expect(source.reads, contains('session.usage'));
      expect(opened.messages, hasLength(messages));
      expect(opened.isReplying, isFalse);
      expect(notifications.shown, isEmpty);
      expect(chat.activeThreads, isNot(contains('stored-1')));

      // Another runtime's compaction is not this chat's.
      source.reads.clear();
      stream.emit(const ContextCompacted(runtimeId: 'rt-other'));
      await pumpEventQueue();
      expect(source.reads, isEmpty);
    });

    test('a compaction during a reply neither ends nor advances it', () async {
      final opened = await open();
      source.own('stored-1');
      chat.contextIn(opened);
      chat.submit('Another question', const []);
      await pumpEventQueue();
      final reply = opened.messages.last;
      source.sends.last.emit(const ContextCompacted(runtimeId: 'rt-1'));
      await pumpEventQueue();
      expect(reply.isPending, isTrue);
      expect(reply.status, MessageStatus.thinking);
      expect(reply.content, isEmpty);
      expect(notifications.shown, isEmpty);
    });
  });

  test('no record of the wiring holds the prompt text', () async {
    final (opened, checkpoints) = await listed();
    source.fake.restore = const Restored(historyRemoved: 1);
    server.on(
      'GET',
      '/api/sessions/stored-1/messages',
      messageListBody('stored-1', _rows(withPrompt: false)),
    );
    await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
    final context = chat.contextIn(opened)!;
    await context.confirmCompress(context.beginCompress()!);
    expect(drafts, [_prompt]);
    final records = [
      for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
      for (final (name, attributes) in events) '$name $attributes',
    ].join('\n');
    expect(records, contains('chat.checkpoints.restore_confirmed'));
    expect(records, isNot(contains('quarterly')));
    expect(records, isNot(contains(_hash)));
  });
}
