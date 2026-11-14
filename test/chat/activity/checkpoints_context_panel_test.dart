import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/widgets/composer_status_line.dart';
import 'package:hermes_app/src/chat/activity/activity_tier.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/activity/checkpoints_context_panel.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_dock.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_controller.dart';
import 'package:hermes_app/src/chat/checkpoints/pages/checkpoints_page.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/changed_files_list.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_checkpoints_row.dart';
import 'package:hermes_app/src/chat/context/context_controller.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/actions_chat_transport.dart';
import '../../support/fake_attachment_source.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/fake_notification_service.dart';

/// Invented content only.
const _prompt = 'Split the token refresh out';
final _hash = 'b' * 40;
const _path = 'src/auth/token_refresh.dart';
const _diff =
    '''diff --git a/src/auth/token_refresh.dart b/src/auth/token_refresh.dart
--- a/src/auth/token_refresh.dart
+++ b/src/auth/token_refresh.dart
@@ -1,2 +1,2 @@
-  return _client.post(old.refreshToken);
+  return _store.save(await _client.post(old.refreshToken));
''';

const _changes = Changes([
  ChangedFile(
    path: _path,
    restorable: true,
    added: 1,
    removed: 1,
    changes: 2,
    diff: _diff,
  ),
  ChangedFile(
    path: 'README.md',
    restorable: true,
    added: 3,
    removed: 0,
    changes: 3,
    diff: _diff,
  ),
], truncated: false);

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
  late ActionsChatTransport source;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeNotificationService notifications;
  late _Lock lock;
  late List<String> drafts;

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
    source = ActionsChatTransport();
    notifications = FakeNotificationService();
    attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    lock = _Lock();
    drafts = [];
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: source,
      attention: attention,
      appLock: lock,
      onDraft: drafts.add,
      report: (_) {},
    );
  });

  tearDown(() async {
    chat.dispose();
    attention.dispose();
    lock.dispose();
    await source.close();
  });

  /// Opens stored-1, live, with one checkpoint and its changes scripted.
  Future<ChatThread> open({bool live = true}) async {
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
    if (live) source.own('stored-1');
    source.fake
      ..list = CheckpointsOn([
        Checkpoint(
          hash: _hash,
          reason: CheckpointReason.beforeEdit,
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ])
      ..changes = _changes;
    await pumpEventQueue();
    return chat.selectedThread!;
  }

  Future<void> pumpPanel(WidgetTester tester, {bool rows = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 380,
              child: ListenableBuilder(
                listenable: chat,
                builder: (_, _) => BoundActivityPanel(
                  chat: chat,
                  thread: chat.selectedThread,
                  checkpointsAndContext: rows,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  CheckpointsController checkpointsOf() =>
      chat.checkpointsIn(chat.selectedThread!)!;
  ContextController contextOf() => chat.contextIn(chat.selectedThread!)!;

  Future<void> openCheckpoints(WidgetTester tester) async {
    await tester.tap(find.byType(FileCheckpointsRow));
    await settle(tester);
    expect(find.text('File checkpoints'), findsOneWidget);
  }

  group('rows', () {
    testWidgets('a live chat lists its checkpoints in the row, after the '
        'Context row', (tester) async {
      await tester.runAsync(() async {
        await open();
        source.reportUsage('stored-1', 62);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      expect(find.text('File checkpoints · 1'), findsOneWidget);
      expect(find.text('Restore files Hermes changed'), findsOneWidget);
      expect(find.byType(ContextRow), findsOneWidget);
      final context = tester.getTopLeft(find.byType(ContextRow));
      final files = tester.getTopLeft(find.byType(FileCheckpointsRow));
      expect(context.dy, lessThan(files.dy));
      expect(source.fake.count('list'), 1);
    });

    testWidgets('a layout change replaces the panel presence without closing '
        'the list its replacement just opened', (tester) async {
      await tester.runAsync(() async {
        await open();
        await pumpEventQueue();
      });
      final controller = checkpointsOf();
      Widget presence(Key key) => MaterialApp(
        home: CheckpointsPanelPresence(
          key: key,
          controller: controller,
          child: const SizedBox(),
        ),
      );
      await tester.pumpWidget(presence(const ValueKey('docked')));
      await tester.pump();
      expect(controller.panelOpen, isTrue);
      // The inspector turns to an overlay: one presence goes, one comes.
      await tester.pumpWidget(presence(const ValueKey('overlay')));
      await tester.pump();
      await tester.pump();
      expect(controller.panelOpen, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.panelOpen, isFalse);
    });

    testWidgets('a standalone page and a panel presence share one hold: the '
        'page leaving does not close the list under the presence', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open();
        await pumpEventQueue();
      });
      final controller = checkpointsOf();
      final thread = chat.selectedThread!;
      final navigator = GlobalKey<NavigatorState>();
      final showPresence = ValueNotifier(false);
      addTearDown(showPresence.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ValueListenableBuilder<bool>(
            valueListenable: showPresence,
            builder: (_, shown, _) => shown
                ? CheckpointsPanelPresence(
                    controller: controller,
                    child: const SizedBox(),
                  )
                : const SizedBox(),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          CheckpointsPage.route(chat: chat, thread: thread),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.panelOpen, isTrue);
      // A resize mounts a panel under the page; then the page is popped.
      showPresence.value = true;
      await tester.pump();
      await tester.pump();
      navigator.currentState!.pop();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(controller.panelOpen, isTrue);
      expect(controller.panelHolds, 1);
      showPresence.value = false;
      await tester.pump();
      await tester.pump();
      expect(controller.panelOpen, isFalse);
    });

    testWidgets('a stored chat with no runtime says "Not checked yet" and '
        'resumes only once its row is opened', (tester) async {
      await tester.runAsync(() => open(live: false));
      await pumpPanel(tester);
      expect(find.text('Not checked yet'), findsOneWidget);
      expect(source.fake.calls, isEmpty);
      await tester.tap(find.byType(FileCheckpointsRow));
      await settle(tester);
      expect(source.fake.calls, ['listResuming']);

      // The resume gives the chat its runtime: the open list is read for it.
      // The chat's subscriptions were made in the real zone by open().
      await tester.runAsync(() async {
        source.own('stored-1');
        await pumpEventQueue();
      });
      await settle(tester);
      expect(source.fake.calls, ['listResuming', 'list']);
      expect(find.text('Before editing a file'), findsOneWidget);
    });

    testWidgets('an old server shows neither row', (tester) async {
      await tester.runAsync(() async {
        await open();
        source.fake.list = const CheckpointsUnsupported();
      });
      await pumpPanel(tester);
      expect(find.byType(FileCheckpointsRow), findsNothing);
      expect(find.byType(ContextRow), findsNothing);
    });

    testWidgets('off with edits says so; a failed read says so', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open();
        source.fake.list = const CheckpointsOff();
      });
      await pumpPanel(tester);
      expect(find.text('File checkpoints are off'), findsOneWidget);
      expect(find.text('See how to turn them on'), findsOneWidget);

      source.fake.list = const CheckpointsFailed(CheckpointFailureKind.other);
      await tester.runAsync(() => checkpointsOf().refresh());
      await tester.pump();
      expect(find.text("Couldn't read checkpoints"), findsOneWidget);
    });

    testWidgets('a conversation window draws neither row', (tester) async {
      await tester.runAsync(() async {
        await open();
        source.reportUsage('stored-1', 62);
        await pumpEventQueue();
      });
      await pumpPanel(tester, rows: false);
      expect(find.byType(FileCheckpointsRow), findsNothing);
      expect(find.byType(ContextRow), findsNothing);
      expect(source.fake.calls, isEmpty);
    });
  });

  group('context details', () {
    testWidgets('loading, failed with Try again, and unsupported', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open();
        source.reportUsage('stored-1', 62);
        await pumpEventQueue();
      });
      final gate = source.fake.breakdownGate = Completer<void>();
      source.fake.breakdown = const BreakdownFailed(
        CheckpointFailureKind.other,
      );
      await pumpPanel(tester);
      await tester.tap(find.byType(ContextRow));
      await settle(tester);
      expect(
        find.bySemanticsLabel('Reading what fills the context…'),
        findsOneWidget,
      );
      gate.complete();
      await settle(tester);
      expect(
        find.text("Couldn't read what fills the context."),
        findsOneWidget,
      );

      source.fake
        ..breakdownGate = null
        ..breakdown = const Breakdown(
          categories: [ContextCategory(ContextCategoryKind.conversation, 900)],
        );
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Conversation'), findsOneWidget);
      expect(source.fake.count('breakdown'), 2);

      // Back drops the breakdown.
      await tester.tap(find.byKey(const Key('activity-page-back')));
      await settle(tester);
      expect(contextOf().breakdown, isNull);

      source.fake.breakdown = const BreakdownUnsupported();
      await tester.tap(find.byType(ContextRow));
      await settle(tester);
      expect(find.text("What's in it"), findsNothing);
      expect(find.text('Compress conversation…'), findsOneWidget);
    });
  });

  group('compress', () {
    testWidgets('confirm, work in Now, the outcome note and a re-read usage', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open();
        source.reportUsage('stored-1', 86);
        await pumpEventQueue();
      });
      final gate = source.fake.compressGate = Completer<void>();
      source.fake.compress = const Compressed(
        beforeMessages: 42,
        afterMessages: 9,
        beforeTokens: 120000,
        afterTokens: 30000,
      );
      await pumpPanel(tester);
      await tester.tap(find.byType(ContextRow));
      await settle(tester);
      await tester.tap(find.text('Compress conversation…'));
      await settle(tester);
      expect(find.text('Compress this conversation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Compress'));
      await settle(tester);
      expect(find.text('Compress this conversation?'), findsNothing);
      expect(source.fake.compressRequests, hasLength(1));
      // In flight: the page and, back in the panel, Now say so.
      expect(find.text('Compressing the conversation…'), findsWidgets);
      await tester.tap(find.byKey(const Key('activity-page-back')));
      await settle(tester);
      expect(find.byKey(const Key('working-compress')), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);

      final reads = source.reads.length;
      gate.complete();
      await tester.runAsync(pumpEventQueue);
      await settle(tester);
      expect(find.byKey(const Key('working-compress')), findsNothing);
      expect(find.byKey(const Key('panel-compress-outcome')), findsOneWidget);
      expect(find.text('Conversation compressed'), findsOneWidget);
      expect(source.reads.length, greaterThan(reads));
      expect(source.fake.count('compress'), 1);
    });

    testWidgets('the suggestion opens the details with the confirmation, '
        'and a reply that starts disables Compress', (tester) async {
      await tester.runAsync(() async {
        await open();
        source.reportUsage('stored-1', 90);
        await pumpEventQueue();
      });
      source.fake.breakdown = const Breakdown(
        categories: [ContextCategory(ContextCategoryKind.conversation, 900)],
      );
      await pumpPanel(tester);
      expect(find.text('Compress to make room?'), findsOneWidget);
      await tester.tap(find.text('Compress…'));
      await settle(tester);
      expect(find.text('Compress this conversation?'), findsOneWidget);
      expect(find.text("What's in it"), findsOneWidget);

      chat.submit('Another question', const []);
      await settle(tester);
      expect(find.text('Wait for the reply to finish.'), findsWidgets);
      final compress = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Compress'),
      );
      expect(compress.onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(source.fake.compressRequests, isEmpty);
    });
  });

  group('restore', () {
    testWidgets('one file: confirm on its page, back to Changes read again '
        'with the outcome note on top', (tester) async {
      await tester.runAsync(open);
      await pumpPanel(tester);
      await openCheckpoints(tester);
      await tester.tap(find.text('Before editing a file'));
      await settle(tester);
      expect(find.text('Changes'), findsOneWidget);
      expect(find.text('Since 12 min ago · Before editing a file'), findsOne);
      await tester.tap(find.text(breakableFileName('token_refresh.dart')));
      await settle(tester);
      expect(find.text('Restore this file…'), findsOneWidget);
      await tester.tap(find.text('Restore this file…'));
      await settle(tester);
      expect(find.text('Restore this file?'), findsOneWidget);
      source.fake.changes = const Changes([
        ChangedFile(path: 'README.md', restorable: true, diff: _diff),
      ], truncated: false);
      await tester.tap(find.text('Restore file'));
      await tester.runAsync(pumpEventQueue);
      await settle(tester);

      expect(source.fake.restoreRequests.single.file, _path);
      expect(find.text('Changes'), findsOneWidget);
      expect(find.byKey(const Key('changes-outcome')), findsOneWidget);
      expect(find.text('Restored 1 file'), findsOneWidget);
      expect(source.fake.count('changes:'), 2);
      expect(find.text(breakableFileName('token_refresh.dart')), findsNothing);
    });

    testWidgets('all files: back to the re-read list with the note on top, '
        'Send held until it settled, the prompt handed back', (tester) async {
      await tester.runAsync(open);
      await pumpPanel(tester);
      await openCheckpoints(tester);
      await tester.tap(find.text('Before editing a file'));
      await settle(tester);
      await tester.tap(find.text('Restore all files…'));
      await settle(tester);
      expect(find.text('Restore all files?'), findsOneWidget);
      expect(find.text(_prompt), findsOneWidget);

      final gate = source.fake.restoreGate = Completer<void>();
      source.fake.restore = const Restored(historyRemoved: 2);
      server.on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', _rows(withPrompt: false)),
      );
      await tester.tap(find.text('Restore all files'));
      await settle(tester);
      expect(chat.sendHeldIn(chat.selectedThread!), isTrue);
      expect(find.text('File checkpoints'), findsOneWidget);
      expect(find.text('Restoring files…'), findsOneWidget);

      gate.complete();
      await tester.runAsync(() => pumpEventQueue(times: 50));
      await settle(tester);
      expect(chat.sendHeldIn(chat.selectedThread!), isFalse);
      expect(source.fake.restoreRequests.single.file, isNull);
      expect(find.byKey(const Key('checkpoints-outcome')), findsOneWidget);
      expect(find.text('Restored 2 files'), findsOneWidget);
      expect(drafts, [_prompt]);
      expect(source.fake.count('list'), greaterThanOrEqualTo(2));
    });

    testWidgets('a lost answer says so and offers it again behind a new '
        'confirmation; nothing is resent', (tester) async {
      await tester.runAsync(open);
      await pumpPanel(tester);
      await openCheckpoints(tester);
      source.fake.restore = const RestoreMayHaveHappened();
      await tester.tap(find.byType(IconButton).last);
      await settle(tester);
      await tester.tap(find.text('Restore all files…').last);
      await settle(tester);
      await tester.tap(find.text('Restore all files'));
      await tester.runAsync(() => pumpEventQueue(times: 50));
      await settle(tester);
      expect(find.text("Hermes didn't answer"), findsOneWidget);
      expect(source.fake.count('restore'), 1);

      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Restore all files?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(source.fake.count('restore'), 1);
    });

    testWidgets('while replying: all files waits, one file goes with the '
        'warning', (tester) async {
      await tester.runAsync(open);
      await pumpPanel(tester);
      await openCheckpoints(tester);
      await tester.tap(find.text('Before editing a file'));
      await settle(tester);
      chat.submit('Another question', const []);
      await settle(tester);
      expect(find.text('Wait for the reply to finish.'), findsOneWidget);
      final bar = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Restore all files…'),
      );
      expect(bar.onPressed, isNull);

      await tester.tap(find.text(breakableFileName('token_refresh.dart')));
      await settle(tester);
      await tester.tap(find.text('Restore this file…'));
      await settle(tester);
      expect(
        find.textContaining('Hermes is working in this folder right now.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(source.fake.restoreRequests, isEmpty);
    });
  });

  testWidgets('App Lock closes the pages and leaves only the count', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await open();
      source.reportUsage('stored-1', 62);
      await pumpEventQueue();
    });
    await pumpPanel(tester);
    await openCheckpoints(tester);
    await tester.tap(find.text('Before editing a file'));
    await settle(tester);
    lock.cover(true);
    await settle(tester);
    expect(find.text('Changes'), findsNothing);
    expect(find.text('1 checkpoint'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.textContaining('tokens'), findsNothing);
    expect(checkpointsOf().changes, isNull);
    await tester.tap(find.byType(FileCheckpointsRow));
    await settle(tester);
    expect(find.text('Newest first'), findsNothing);
  });

  testWidgets('a full context and a restore in flight make no Needs-you '
      'item, no strip entry, no Working sentence and no notification', (
    tester,
  ) async {
    final composer = TextEditingController();
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    await tester.runAsync(() async {
      await open();
      source.reportUsage('stored-1', 97);
      await pumpEventQueue();
      await checkpointsOf().panelOpened();
    });
    final state = chat.sessionStateIn(chat.selectedThread!);
    final tierBefore = state == null ? null : sessionStateTier(state);
    source.fake.restoreGate = Completer<void>();
    unawaited(
      checkpointsOf().confirmRestore(checkpointsOf().beginRestore(_hash)!),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: chat,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  key: const Key('strip-side'),
                  child: boundChatThreadView(
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
                SizedBox(
                  width: 380,
                  child: BoundActivityPanel(
                    chat: chat,
                    thread: chat.selectedThread,
                    checkpointsAndContext: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(contextOf().level, ContextLevel.critical);
    expect(checkpointsOf().restoring, isTrue);
    // The panel shows both, under Now and This session.
    expect(find.byKey(const Key('working-restore')), findsOneWidget);
    expect(find.text('Nearly full'), findsOneWidget);
    // Nothing reaches the chat side: no Needs-you dock, no activity line,
    // no strip text.
    final strip = find.byKey(const Key('strip-side'));
    for (final finder in [
      find.byType(NeedsYouDock),
      find.byType(ActivityLine),
      find.text('Nearly full'),
      find.text('97%'),
    ]) {
      expect(find.descendant(of: strip, matching: finder), findsNothing);
    }
    // The only place the chat side says a restore runs is the composer's own
    // line, which gives the reason Send is held: it is no strip entry.
    final restoring = find.descendant(
      of: strip,
      matching: find.text('Restoring files…'),
    );
    expect(
      find.descendant(of: find.byType(ComposerStatusLine), matching: restoring),
      findsOneWidget,
    );
    expect(restoring, findsOneWidget);
    // Both kinds are For reference, and nothing feeds the Working summary.
    expect(ActivityKind.context.tier, ActivityTier.reference);
    expect(ActivityKind.checkpoints.tier, ActivityTier.reference);
    expect(WorkingSummary.compute(), isNull);
    final after = chat.sessionStateIn(chat.selectedThread!);
    expect(after == null ? null : sessionStateTier(after), tierBefore);
    expect(notifications.shown, isEmpty);
    source.fake.restoreGate!.complete();
    await tester.runAsync(() => pumpEventQueue(times: 50));
    await settle(tester);
    expect(notifications.shown, isEmpty);
  });
}

/// Pumps until nothing is scheduled, without waiting on endless animations.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
