import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show CustomMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/transcript_outcome.dart';
import 'package:hermes_app/src/chat/context/context_controller.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/thread_export.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart'
    show latestFinishedReplyId;
import 'package:hermes_app/src/chat/widgets/composer_status_line.dart';
import 'package:hermes_app/src/chat/widgets/transcript_outcome_line.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/widgets/voice_recording_controls.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_attachment_source.dart';
import '../../support/fake_chat_transport.dart';
import '../../support/fake_checkpoints_transport.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/pump_chat.dart';

/// Invented content only.
const _prompt = 'Split the token refresh out';
const _reply = 'Moved it to src/auth/token_refresh.dart.';
final _hash = 'c' * 40;

/// A chat transport that owns runtimes and answers the checkpoint and
/// context calls from a [FakeCheckpointsTransport], for any profile.
class _Source extends FakeChatTransport
    implements OwnedSessionTransport, CheckpointsTransport, ContextTransport {
  final fake = FakeCheckpointsTransport();
  final owned = <String, OwnedSessionBinding>{};
  final changes = StreamController<OwnedSessionChange>.broadcast(sync: true);

  OwnedSessionBinding own(String thread) {
    final binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'rt-$thread',
      profile: null,
    );
    owned[thread] = binding;
    changes.add(OwnedSessionChange(thread, binding));
    return binding;
  }

  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      owned[threadId];

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => const {
    'context_used': 1000,
    'context_max': 10000,
    'context_percent': 10,
  };

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

List<Map<String, Object?>> _rows({bool withPrompt = true, double? later}) => [
  if (withPrompt) messageRow(id: 1, role: 'user', content: _prompt),
  messageRow(id: 2, role: 'assistant', content: _reply),
  if (later != null)
    messageRow(id: 3, role: 'user', content: 'Thanks', timestamp: later),
];

/// Unmounts the screen and lets the chat list's last scroll timer run.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

bool _isLine(Object m) =>
    m is CustomMessage && m.metadata?[kMetaKind] == kKindOutcomeLine;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late _Source source;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Token refresh', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on('GET', '/api/sessions/s1', sessionRow(id: 's1'))
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', _rows()))
      ..on('GET', '/api/sessions/s2/messages', messageListBody('s2', []));
    source = _Source();
  });

  tearDown(() => source.close());

  group('transcriptOutcomeText', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final at = DateTime(2026, 11, 14);

    test('a compress gives its counts, and nothing for a placeholder', () {
      expect(
        transcriptOutcomeText(
          en,
          TranscriptOutcome(
            kind: TranscriptOutcomeKind.compressed,
            at: at,
            beforeMessages: 42,
            afterMessages: 9,
            fallbackUsed: true,
          ),
        ),
        'Conversation compressed · 42 → 9 messages',
      );
      expect(
        transcriptOutcomeText(
          en,
          TranscriptOutcome(kind: TranscriptOutcomeKind.compressed, at: at),
        ),
        'Conversation compressed',
      );
    });

    test('a restore says what it removed, and never a message it did not', () {
      String line({int? files, bool removed = false, bool rewound = false}) =>
          transcriptOutcomeText(
            en,
            TranscriptOutcome(
              kind: TranscriptOutcomeKind.restored,
              at: at,
              files: files,
              removedMessages: removed,
              lastMessageNotRemoved: rewound,
            ),
          );
      expect(line(files: 3), 'Restored 3 files');
      expect(line(), 'Files restored');
      expect(
        line(files: 3, removed: true),
        'Restored 3 files · removed your last message',
      );
      expect(
        line(removed: true, rewound: true),
        'Files restored · rewound the chat',
      );
    });
  });

  group('outcome rows in the message list', () {
    late ChatController chat;
    late AttentionNotifier attention;

    setUp(() {
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: source,
        attention: attention,
        report: (_) {},
      );
    });

    tearDown(() {
      chat.dispose();
      attention.dispose();
    });

    Future<(ChatThread, ContextController)> live() async {
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.own('s1');
      await pumpEventQueue();
      source.fake.compress = const Compressed(
        beforeMessages: 42,
        afterMessages: 9,
      );
      return (thread, chat.contextIn(thread)!);
    }

    test('a settled compress adds one row after the reply, which a re-read '
        'keeps', () async {
      final (thread, context) = await live();
      final ids = [for (final m in thread.messages) m.id];
      await context.confirmCompress(context.beginCompress()!);
      context.notifyListeners();

      var flyer = chat.controllerFor(thread).messages;
      expect(flyer.where(_isLine), hasLength(1));
      expect(_isLine(flyer.last), isTrue);

      // A changed chat is read again and its list rewritten.
      server.on(
        'GET',
        '/api/sessions/s1',
        sessionRow(id: 's1', lastActive: 1780000900),
      );
      final reads = server.requestsTo('GET', '/api/sessions/s1/messages');
      final before = reads.length;
      await chat.refreshThread('s1');
      expect(
        server.requestsTo('GET', '/api/sessions/s1/messages').length,
        before + 1,
      );
      flyer = chat.controllerFor(thread).messages;
      expect(flyer.where(_isLine), hasLength(1));
      expect(_isLine(flyer.last), isTrue);
      // The chat's own messages never hold it.
      expect([for (final m in thread.messages) m.id], ids);
    });

    test('a row sits by when it settled, before a later message', () async {
      final (thread, context) = await live();
      await context.confirmCompress(context.beginCompress()!);
      final later =
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch /
          1000;
      server
        ..on(
          'GET',
          '/api/sessions/s1/messages',
          messageListBody('s1', _rows(later: later)),
        )
        ..on(
          'GET',
          '/api/sessions/s1',
          sessionRow(id: 's1', lastActive: later),
        );
      await chat.refreshThread('s1');
      final flyer = chat.controllerFor(thread).messages;
      final line = flyer.indexWhere(_isLine);
      expect(line, flyer.length - 2);
      expect(flyer.last.id, isNot(contains('outcome')));
    });

    test('no reader of the chat sees the row: not the prompt, the last '
        'reply, the transcript or the preview', () async {
      final (thread, context) = await live();
      final transcript = threadTranscript(thread.messages);
      final latest = latestFinishedReplyId(thread);
      final prompt = chat.lastPromptText(thread);
      final preview = thread.preview;
      await context.confirmCompress(context.beginCompress()!);
      expect(chat.outcomeLinesIn(thread), hasLength(1));

      expect(threadTranscript(thread.messages), transcript);
      expect(threadTranscript(thread.messages), isNot(contains('compressed')));
      expect(latestFinishedReplyId(thread), latest);
      expect(chat.lastPromptText(thread), prompt);
      expect(thread.preview, preview);
      expect(thread.messages.where((m) => m.isPrompt), hasLength(1));
    });
  });

  group('Send hold in the composer', () {
    late ChatController chat;
    late AttentionNotifier attention;

    setUp(() {
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: source,
        attention: attention,
        report: (_) {},
      );
    });

    tearDown(() {
      chat.dispose();
      attention.dispose();
    });

    Future<void> pumpView(WidgetTester tester, TextEditingController text) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme(),
            home: Scaffold(
              body: ListenableBuilder(
                listenable: chat,
                builder: (_, _) => boundChatThreadView(
                  chat: chat,
                  thread: chat.selectedThread,
                  composerController: text,
                  composerFocus: FocusNode(),
                  attachments: const [],
                  attachmentSource: FakeAttachmentSource(),
                  onAddAttachments: (_) {},
                  onRemoveAttachment: (_) {},
                  onSend: (typed) => chat.submit(typed, const []),
                  latestReply: LatestReply(),
                ),
              ),
            ),
          ),
        );

    VoidCallback? send(WidgetTester tester) =>
        tester.widget<HoldToRecordSend>(find.byType(HoldToRecordSend)).onSend;

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
      testWidgets('Send is off with a reason while a full restore settles, '
          'and on again after ($name)', (tester) async {
        final text = TextEditingController();
        addTearDown(text.dispose);
        await tester.runAsync(() async {
          await chat.loadThreads();
          chat.select('s1');
          await pumpEventQueue();
          source.own('s1');
          await pumpEventQueue();
        });
        await pumpView(tester, text);
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Next step');
        await tester.pump();
        expect(send(tester), isNotNull);

        final thread = chat.selectedThread!;
        final checkpoints = chat.checkpointsIn(thread)!;
        source.fake.list = CheckpointsOn([
          Checkpoint(hash: _hash, reason: CheckpointReason.beforeEdit),
        ]);
        final gate = source.fake.restoreGate = Completer<void>();
        if (result != null) source.fake.restore = result;
        late Future<void> confirming;
        await tester.runAsync(() async {
          await checkpoints.panelOpened();
          confirming = checkpoints.confirmRestore(
            checkpoints.beginRestore(_hash)!,
          );
          await pumpEventQueue();
        });
        await tester.pump();

        expect(chat.sendHeldIn(thread), isTrue);
        expect(send(tester), isNull);
        expect(find.text('Restoring files…'), findsOneWidget);
        // Typing goes on; a prompt that still arrives waits in the queue.
        await tester.enterText(find.byType(TextField), 'Next step, please');
        expect(text.text, 'Next step, please');
        final sends = source.sends.length;
        expect(chat.submit('Queued meanwhile', const []), isTrue);
        await tester.pump();
        expect(source.sends.length, sends);

        await tester.runAsync(() async {
          if (result == null) {
            gate.completeError(StateError('connection dropped'));
          } else {
            gate.complete();
          }
          await confirming;
          await pumpEventQueue();
        });
        await tester.pump();

        expect(chat.sendHeldIn(thread), isFalse);
        expect(find.text('Restoring files…'), findsNothing);
        expect(source.sends.length, sends + 1);
        expect(source.fake.count('restore'), 1);
        source.sends.last
          ..emit(const ReplyCompleted('Done'))
          ..finish();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(send(tester), isNotNull);
        await _unmount(tester);
      });
    }
  });

  group('the chat screen', () {
    late MacCommandRegistry commands;
    late _Lock lock;
    late List<ContextController> entered;

    setUp(() {
      commands = MacCommandRegistry();
      lock = _Lock();
      entered = [];
    });

    tearDown(() {
      commands.dispose();
      lock.dispose();
    });

    Future<void> confirmThroughEntry(
      BuildContext context,
      ContextController controller,
    ) async {
      entered.add(controller);
      final intent = controller.beginCompress();
      if (intent != null) await controller.confirmCompress(intent);
    }

    Future<void> pump(
      WidgetTester tester, {
      ChatTransport? transport,
      bool withEntry = true,
    }) => pumpChatScreen(
      tester,
      server: server,
      transport: transport ?? source,
      commands: commands,
      platform: TargetPlatform.macOS,
      providers: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
      onCompressConversation: withEntry ? confirmThroughEntry : null,
    );

    bool compressOn() =>
        commands.handlerFor(MacCommand.compress)?.enabled ?? false;

    /// The screen's chat controller, read from the Activity inspector.
    Future<ChatController> chatOf(WidgetTester tester) async {
      if (find.byType(BoundActivityPanel).evaluate().isEmpty) {
        commands.invoke(MacCommand.toggleInspector);
        await tester.pumpAndSettle();
      }
      return tester
          .widget<BoundActivityPanel>(find.byType(BoundActivityPanel))
          .chat;
    }

    testWidgets('Compress Conversation… is on only for an idle, live, '
        'unlocked chat', (tester) async {
      await pump(tester);
      expect(compressOn(), isFalse);
      expect(
        commands.handlerFor(MacCommand.compress)?.title,
        'Compress Conversation…',
      );

      await openThread(tester, 'Token refresh');
      // A stored chat with no live session.
      expect(compressOn(), isFalse);
      source.own('s1');
      await tester.pumpAndSettle();
      expect(compressOn(), isTrue);

      lock.cover(true);
      await tester.pumpAndSettle();
      expect(compressOn(), isFalse);
      lock.cover(false);
      await tester.pumpAndSettle();
      expect(compressOn(), isTrue);

      final chat = await chatOf(tester);
      chat.submit('One more thing', const []);
      await tester.pump();
      expect(compressOn(), isFalse);
      source.sends.last
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await tester.pumpAndSettle();
      expect(compressOn(), isTrue);
    });

    testWidgets('without a custom entry the item uses the shared '
        'confirmation flow, and only once the chat can compress', (
      tester,
    ) async {
      await pump(tester, withEntry: false);
      await openThread(tester, 'Token refresh');
      // No live session yet: nothing to compress.
      expect(compressOn(), isFalse);
      source.own('s1');
      await tester.pumpAndSettle();
      expect(compressOn(), isTrue);
      // Nothing is sent until the user confirms.
      expect(source.fake.compressRequests, isEmpty);
    });

    testWidgets('a plain transport offers nothing to compress', (tester) async {
      final plain = FakeChatTransport();
      addTearDown(plain.close);
      await pump(tester, transport: plain);
      await openThread(tester, 'Token refresh');
      expect(compressOn(), isFalse);
    });

    testWidgets('the item opens the confirmation; the result is one line '
        'in the transcript, read once', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await openThread(tester, 'Token refresh');
      source.own('s1');
      await tester.pumpAndSettle();
      source.fake.compress = const Compressed(
        beforeMessages: 42,
        afterMessages: 9,
      );

      expect(commands.invoke(MacCommand.compress), isTrue);
      await tester.pumpAndSettle();

      expect(entered, hasLength(1));
      expect(source.fake.compressRequests, hasLength(1));
      const line = 'Conversation compressed · 42 → 9 messages';
      expect(find.text(line), findsOneWidget);
      expect(find.bySemanticsLabel(line), findsOneWidget);
      expect(find.byType(TranscriptOutcomeLine), findsOneWidget);
      await _unmount(tester);
      semantics.dispose();
    });

    testWidgets('a restore that hands the last message back says so above '
        'the composer until the next edit', (tester) async {
      await pump(tester);
      await openThread(tester, 'Token refresh');
      source.own('s1');
      await tester.pumpAndSettle();
      final chat = await chatOf(tester);
      final thread = chat.selectedThread!;
      final checkpoints = chat.checkpointsIn(thread)!;
      source.fake
        ..list = CheckpointsOn([
          Checkpoint(hash: _hash, reason: CheckpointReason.beforeEdit),
        ])
        ..restore = const Restored(historyRemoved: 2);
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', _rows(withPrompt: false)),
      );
      await tester.runAsync(() async {
        await checkpoints.panelOpened();
        await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
        await pumpEventQueue();
      });
      await tester.pumpAndSettle();

      expect(find.text(_prompt), findsWidgets);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        _prompt,
      );
      expect(find.text('Your last message is back in the box.'), findsOne);
      expect(
        find.text('Restored 3 files · removed your last message'),
        findsNothing,
      );
      expect(find.text('Files restored · removed your last message'), findsOne);

      await tester.enterText(composerField, '$_prompt now');
      await tester.pumpAndSettle();
      expect(find.text('Your last message is back in the box.'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a restore that leaves the prompt shows no hand-back line', (
      tester,
    ) async {
      await pump(tester);
      await openThread(tester, 'Token refresh');
      source.own('s1');
      await tester.pumpAndSettle();
      final chat = await chatOf(tester);
      final checkpoints = chat.checkpointsIn(chat.selectedThread!)!;
      source.fake
        ..list = CheckpointsOn([
          Checkpoint(hash: _hash, reason: CheckpointReason.beforeEdit),
        ])
        ..restore = const Restored(historyRemoved: 1);
      await tester.runAsync(() async {
        await checkpoints.panelOpened();
        await checkpoints.confirmRestore(checkpoints.beginRestore(_hash)!);
        await pumpEventQueue();
      });
      await tester.pumpAndSettle();
      expect(find.byType(ComposerStatusLine), findsNothing);
      expect(find.text('Files restored · rewound the chat'), findsOne);
      await _unmount(tester);
    });
  });

  group('a conversation window', () {
    testWidgets('shows no outcome line or hold, and asks nothing of the '
        'features', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      source.own('s1');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: ConversationWindowScreen(
            args: const ConversationWindowArgs(
              threadId: 's1',
              profile: null,
              title: 'Token refresh',
              baseUrl: 'https://hermes.test',
              authRequired: true,
            ),
            link: _NoLink(),
            chat: HermesChatRepository(server.client().raw),
            transport: source,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_reply), findsOneWidget);
      expect(find.byType(TranscriptOutcomeLine), findsNothing);
      expect(find.byType(ComposerStatusLine), findsNothing);
      expect(source.fake.calls, isEmpty);
      await tester.enterText(find.byType(TextField).last, 'Hello');
      await tester.pump();
      expect(
        tester.widget<HoldToRecordSend>(find.byType(HoldToRecordSend)).onSend,
        isNotNull,
      );
      await _unmount(tester);
    });
  });
}

class _NoLink implements ConversationWindowLink {
  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};

  @override
  Stream<String> get commands => const Stream.empty();

  @override
  Stream<bool> get keyChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.isMethod ? Future<void>.value() : null;
}
