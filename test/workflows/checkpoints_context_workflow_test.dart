import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/changed_files_list.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_checkpoints_row.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/actions_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Invented content only.
const _title = 'Token refresh refactor';
const _prompt = 'Split the token refresh out';
const _thread = 'stored-1';
final _newest = 'a1' * 20;
final _middle = 'b2' * 20;
final _oldest = 'c3' * 20;
final _safety = 'd4' * 20;
final _safetyAll = 'e5' * 20;

const _tokenRefresh = 'src/auth/token_refresh.dart';
const _sessionStore = 'src/auth/session_store.dart';
const _longName =
    'src/auth/token_refresh_with_retry_and_backoff_for_expired_sessions.dart';
const _unsafeName = 'src/auth/session_store[draft].dart';
const _shortened = '.../refresh/token_refresh_scheduler_test.dart';

ChangedFile _file(String path, {bool restorable = true, int changes = 2}) =>
    ChangedFile(
      path: path,
      restorable: restorable,
      added: 1,
      removed: 1,
      changes: changes,
      diff:
          '''diff --git a/$path b/$path
--- a/$path
+++ b/$path
@@ -12,2 +12,2 @@ class TokenRefresh {
-    return _client.post(old.refreshToken);
+    return _store.save(await _client.post(old.refreshToken));
''',
    );

final _changes = Changes([
  _file(_tokenRefresh),
  _file(_sessionStore),
  _file(_longName, changes: 4),
  _file(_unsafeName, restorable: false),
  _file(_shortened, restorable: false, changes: 6),
], truncated: false);

/// After the one file went back, the rest still differ.
final _changesAfterOne = Changes([
  _file(_sessionStore),
  _file(_longName, changes: 4),
  _file(_unsafeName, restorable: false),
  _file(_shortened, restorable: false, changes: 6),
], truncated: false);

final _now = DateTime.now();

CheckpointsOn _three() => CheckpointsOn([
  Checkpoint(
    hash: _newest,
    reason: CheckpointReason.beforeEdit,
    timestamp: _now.subtract(const Duration(minutes: 4)),
  ),
  Checkpoint(
    hash: _middle,
    reason: CheckpointReason.beforeTerminal,
    timestamp: _now.subtract(const Duration(minutes: 12)),
  ),
  Checkpoint(
    hash: _oldest,
    reason: CheckpointReason.beforeEdit,
    timestamp: _now.subtract(const Duration(minutes: 31)),
  ),
]);

/// The list after restores to [target]: one safety checkpoint per restore
/// ([safety], newest first) on top of the three.
CheckpointsOn _withSafety(String target, List<String> safety) => CheckpointsOn([
  for (final hash in safety)
    Checkpoint(
      hash: hash,
      reason: CheckpointReason.beforeRestore,
      restoredFrom: target.substring(0, 8),
      timestamp: DateTime.now(),
    ),
  ..._three().checkpoints,
]);

const _breakdown = Breakdown(
  categories: [
    ContextCategory(ContextCategoryKind.conversation, 71200),
    ContextCategory(ContextCategoryKind.toolDefinitions, 21400),
    ContextCategory(ContextCategoryKind.systemPrompt, 9800),
    ContextCategory(ContextCategoryKind.skills, 6300),
    ContextCategory(ContextCategoryKind.mcp, 5100),
    ContextCategory(ContextCategoryKind.memory, 4200),
    ContextCategory(ContextCategoryKind.rules, 3100),
    ContextCategory(ContextCategoryKind.subagentDefinitions, 2900),
  ],
  used: 124000,
  max: 200000,
  percent: 62,
  source: ContextSource.providerUsage,
);

const _categories = [
  'Conversation',
  'Tools',
  'System prompt',
  'Skills',
  'MCP servers',
  'Memory',
  'Rules files',
  'Sub-agents',
];

/// An earlier exchange, then the prompt and the answer that edited files.
/// Without [withPrompt], what a full restore leaves: the earlier exchange.
List<Map<String, Object?>> _rows({
  bool withPrompt = true,
  bool withEdit = true,
}) => [
  messageRow(
    id: 1,
    role: 'user',
    content: 'Where does the token refresh live now?',
  ),
  messageRow(
    id: 2,
    role: 'assistant',
    content: 'In session_store.dart, mixed in with the storage code.',
  ),
  if (withPrompt) ...[
    messageRow(id: 3, role: 'user', content: _prompt),
    messageRow(
      id: 4,
      role: 'assistant',
      content: withEdit
          ? 'I moved the refresh into token_refresh.dart and updated the '
                'callers.'
          : 'The refresh already lives in its own file.',
      toolCalls: withEdit
          ? [functionCall('write_file', '{"path":"$_tokenRefresh"}')]
          : null,
    ),
  ],
];

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

/// The chat screen with one chat in the `work` profile, its REST from a
/// [FakeHermesServer] and its gateway from an [ActionsChatTransport].
class _Harness {
  _Harness(this.tester, this.shots);

  final WidgetTester tester;
  final ScreenshotRecorder shots;
  late FakeHermesServer server;
  late ActionsChatTransport source;
  late _Lock lock;

  Future<void> pump({
    required Size size,
    required TargetPlatform platform,
    required bool dark,
    List<Map<String, Object?>>? rows,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: _thread, title: _title)]),
      )
      ..on(
        'GET',
        '/api/sessions/$_thread',
        sessionRow(id: _thread, title: _title),
      )
      ..on(
        'GET',
        '/api/sessions/$_thread/messages',
        messageListBody(_thread, rows ?? _rows()),
      );
    source = ActionsChatTransport();
    final lock = this.lock = _Lock();
    addTearDown(lock.dispose);
    final profiles = ChatProfiles(
      HermesProfilesRepository(server.client().raw),
    );
    addTearDown(profiles.dispose);
    await shots.start(tester, size);
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: source,
      chatProfiles: profiles,
      size: size,
      platform: platform,
      theme: withScreenshotFont(
        dark
            ? buildHermesDarkTheme(platform: platform)
            : buildHermesLightTheme(platform: platform),
      ),
      wrap: shots.frame,
      providers: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (_) async => null,
    );
  }

  /// Lets the fake answers land and the animations run out, without
  /// `pumpAndSettle` (a spinner may be on screen).
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => pumpEventQueue(times: 20));
      await tester.pump();
    }
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens the chat and gives it a live runtime, its context [percent]
  /// full; with null, a usage answer without context figures.
  Future<void> openLive({int? percent = 62}) async {
    await openThread(tester, _title, settle: false);
    await settle();
    source.own(_thread);
    if (percent == null) {
      source.usage = const {'total': 10};
    } else {
      usage(percent);
    }
    await settle();
  }

  /// The chat's context is [percent] full, as the next read and the pushed
  /// update both say.
  void usage(int percent) {
    source.usage = {
      'context_used': 2000 * percent,
      'context_max': 200000,
      'context_percent': percent,
    };
    source.reportUsage(_thread, percent);
  }

  int get chatReads =>
      server.requestsTo('GET', '/api/sessions/$_thread/messages').length;

  /// Scrolls [finder] into view (a phone's sheet is short) and taps it.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle();
  }

  /// The Activity button: the header's, or the toolbar's on a Mac.
  Finder get activityButton {
    final header = find.byKey(const Key('header-activity'));
    return header.evaluate().isNotEmpty
        ? header
        : find.byKey(const Key('toolbar-activity'));
  }

  Future<void> openActivity() => tap(activityButton);

  /// Closes the Activity panel: the sheet's close button on a phone, the
  /// toolbar button on a Mac.
  Future<void> closeActivity() async {
    final close = find.byKey(const Key('activity-close'));
    // A phone's sheet offers Close on the panel, under the pages.
    final page = find.byKey(const Key('activity-page-back'));
    while (find.byKey(const Key('header-activity')).evaluate().isNotEmpty &&
        page.evaluate().isNotEmpty) {
      await back();
    }
    await tap(close.evaluate().isNotEmpty ? close : activityButton);
  }

  Future<void> back() => tap(find.byKey(const Key('activity-page-back')));

  Future<void> capture(String name) => shots.capture(tester, name);

  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(source.close);
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Nothing about the context or checkpoints reaches the chat side: no
/// Needs-you item, no mark on the Activity button, no activity line.
void _expectChatSideQuiet(WidgetTester tester) {
  expect(find.byKey(const Key('needs-you-dock')), findsNothing);
  expect(find.byKey(const Key('activity-waiting-marker')), findsNothing);
  final toolbar = find.byKey(const Key('toolbar-activity'));
  if (toolbar.evaluate().isNotEmpty) {
    expect(tester.widget<MacToolbarButton>(toolbar).marked, isFalse);
  }
  // The line is always built; it says nothing while there is no summary.
  for (final line in tester.widgetList<ActivityLine>(
    find.byType(ActivityLine),
  )) {
    expect(line.model, isNull);
  }
}

ContextLevel _level(WidgetTester tester) =>
    tester.widget<ContextRow>(find.byType(ContextRow)).level;

ChatComposer _composer(WidgetTester tester) =>
    tester.widget<ChatComposer>(find.byType(ChatComposer));

/// The row of [path] in the Changes list, by its file name.
Finder _fileRow(String path) =>
    find.text(breakableFileName(path.split('/').last));

/// The Activity panel, in the inspector or the sheet.
final _panel = find.byType(BoundActivityPanel);

/// Whatever on screen says [text], in a Text or a RichText.
Finder _says(String text) => find.textContaining(text, findRichText: true);

/// Context: the row, its details, the suggestion past 85%, nearly full at
/// 97%, and a compress from confirmation to the transcript line.
Future<void> _contextFlow(
  WidgetTester tester,
  String name,
  Size size,
  TargetPlatform platform,
  bool dark,
) async {
  final mode = dark ? 'dark' : 'light';
  final app = _Harness(tester, ScreenshotRecorder('context-$name-$mode'));
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake
    ..list = _three()
    ..breakdown = _breakdown;
  await app.openLive();
  await app.capture('chat');

  await app.openActivity();
  expect(
    find.descendant(of: find.byType(ContextRow), matching: find.text('62%')),
    findsOneWidget,
  );
  expect(_level(tester), ContextLevel.normal);
  await app.capture('panel-context-row');

  await app.tap(find.byType(ContextRow));
  expect(find.text("What's in it"), findsOneWidget);
  for (final category in _categories) {
    expect(find.text(category), findsOneWidget, reason: category);
  }
  expect(app.source.fake.count('breakdown'), 1);
  await app.capture('context-details');
  await app.back();

  // Past 85% while idle: the suggestion, in the panel only.
  app.usage(86);
  await app.settle();
  expect(find.text('Compress to make room?'), findsOneWidget);
  expect(_level(tester), ContextLevel.nearlyFull);
  _expectChatSideQuiet(tester);
  await app.capture('suggestion-86');

  await app.tap(find.text('Not now'));
  expect(find.text('Compress to make room?'), findsNothing);
  app.usage(88);
  await app.settle();
  expect(find.text('Compress to make room?'), findsNothing);
  await app.capture('suggestion-dismissed');

  app.usage(97);
  await app.settle();
  expect(find.text('Nearly full'), findsOneWidget);
  expect(_level(tester), ContextLevel.critical);
  expect(find.text('Compress to make room?'), findsNothing);
  _expectChatSideQuiet(tester);
  expect(app.source.fake.compressRequests, isEmpty);
  await app.capture('nearly-full-97');

  // Compress: a confirmation with Cancel as the default, then the work in Now.
  await app.tap(find.byType(ContextRow));
  await app.tap(find.byKey(const Key('context-compress')));
  expect(find.text('Compress this conversation?'), findsOneWidget);
  final cancel = find.ancestor(
    of: find.text('Cancel'),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(tester.widget<ButtonStyleButton>(cancel).autofocus, isTrue);
  expect(app.source.fake.compressRequests, isEmpty);
  await app.capture('compress-confirmation');

  final gate = app.source.fake.compressGate = Completer<void>();
  app.source.fake.compress = const Compressed(
    beforeMessages: 42,
    afterMessages: 9,
    beforeTokens: 194000,
    afterTokens: 42000,
  );
  await app.tap(find.text('Compress'));
  expect(find.text('Compress this conversation?'), findsNothing);
  expect(app.source.fake.compressRequests, hasLength(1));
  await app.back();
  expect(find.byKey(const Key('working-compress')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(const Key('working-compress')),
      matching: _says('Compressing the conversation…'),
    ),
    findsOneWidget,
  );
  _expectChatSideQuiet(tester);
  await app.capture('compressing-in-now');

  final reads = app.source.reads.length;
  final chatReads = app.chatReads;
  app.source.usage = {
    'context_used': 42000,
    'context_max': 200000,
    'context_percent': 21,
  };
  gate.complete();
  await app.settle();
  expect(find.byKey(const Key('working-compress')), findsNothing);
  expect(find.byKey(const Key('panel-compress-outcome')), findsOneWidget);
  expect(app.source.reads.length, greaterThan(reads));
  expect(app.chatReads, greaterThan(chatReads));
  expect(
    find.descendant(of: find.byType(ContextRow), matching: find.text('21%')),
    findsOneWidget,
  );
  expect(app.source.fake.count('compress'), 1);
  await app.capture('compressed-panel');

  await app.closeActivity();
  expect(_says('Conversation compressed · 42 → 9 messages'), findsOneWidget);
  await app.capture('compressed-transcript');
  await app.finish();
}

/// Checkpoints: the list, one checkpoint's changes, one file's diff, a file
/// restore and a full restore that hands the last message back.
Future<void> _checkpointsFlow(
  WidgetTester tester,
  String name,
  Size size,
  TargetPlatform platform,
  bool dark,
) async {
  final mode = dark ? 'dark' : 'light';
  final app = _Harness(tester, ScreenshotRecorder('checkpoints-$name-$mode'));
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake
    ..list = _three()
    ..changes = _changes;
  await app.openLive();
  await app.openActivity();
  expect(find.text('File checkpoints · 3'), findsOneWidget);
  await app.capture('panel-checkpoints-row');

  await app.tap(find.byType(FileCheckpointsRow));
  expect(find.text('File checkpoints'), findsOneWidget);
  expect(find.text('Before editing a file'), findsNWidgets(2));
  expect(find.text('Before a terminal command'), findsOneWidget);
  // Reasons only: no command, tool name or hash.
  for (final hidden in ['write_file', _tokenRefresh, _newest.substring(0, 7)]) {
    expect(find.descendant(of: _panel, matching: _says(hidden)), findsNothing);
  }
  await app.capture('checkpoint-list');

  await app.tap(find.text('Before editing a file').first);
  expect(find.text('Changes'), findsOneWidget);
  expect(_says('5 files differ'), findsOneWidget);
  for (final path in [
    _tokenRefresh,
    _sessionStore,
    _longName,
    _unsafeName,
    _shortened,
  ]) {
    expect(_fileRow(path), findsOneWidget, reason: path);
  }
  // The long name wraps instead of being cut.
  final long = tester.renderObject<RenderParagraph>(_fileRow(_longName));
  expect(long.didExceedMaxLines, isFalse);
  expect(
    tester.getSize(_fileRow(_longName)).height,
    greaterThan(tester.getSize(_fileRow(_tokenRefresh)).height),
  );
  await app.capture('changes');

  await app.tap(_fileRow(_unsafeName));
  expect(
    _says("This file's name can't be restored one at a time."),
    findsOneWidget,
  );
  expect(find.text('Restore this file…'), findsNothing);
  await app.capture('unsafe-name');
  await app.back();

  await app.tap(_fileRow(_shortened));
  expect(find.text('Restore this file…'), findsNothing);
  await app.capture('shortened-name');
  await app.back();

  await app.tap(_fileRow(_tokenRefresh));
  expect(find.text('Restore this file…'), findsOneWidget);
  await app.capture('file-diff');

  await app.tap(find.text('Restore this file…'));
  expect(find.text('Restore this file?'), findsOneWidget);
  await app.capture('restore-file-confirmation');
  app.source.fake
    ..changes = _changesAfterOne
    ..list = _withSafety(_newest, [_safety]);
  await app.tap(find.text('Restore file'));
  expect(app.source.fake.restoreRequests.single.file, _tokenRefresh);
  expect(find.text('Changes'), findsOneWidget);
  expect(find.byKey(const Key('changes-outcome')), findsOneWidget);
  final changesNote = find.byKey(const Key('changes-outcome'));
  expect(
    find.descendant(of: changesNote, matching: _says('Restored 1 file')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: changesNote, matching: _says('Before a restore')),
    findsOneWidget,
  );
  expect(_says('4 files differ'), findsOneWidget);
  expect(_fileRow(_tokenRefresh), findsNothing);
  await app.capture('restored-one-file');

  // All files: the confirmation quotes the last message.
  final quoted = _says(_prompt).evaluate().length;
  await app.tap(find.text('Restore all files…'));
  expect(find.text('Restore all files?'), findsOneWidget);
  expect(_says(_prompt).evaluate().length, greaterThan(quoted));
  await app.capture('restore-all-confirmation');

  final gate = app.source.fake.restoreGate = Completer<void>();
  app.source.fake
    ..restore = const Restored(historyRemoved: 1)
    ..list = _withSafety(_newest, [_safetyAll, _safety]);
  app.server.on(
    'GET',
    '/api/sessions/$_thread/messages',
    messageListBody(_thread, _rows(withPrompt: false)),
  );
  final lists = app.source.fake.count('list');
  await app.tap(find.text('Restore all files'));
  expect(_composer(tester).sendHeld, isTrue);
  expect(find.byKey(const Key('composer-send-held')), findsOneWidget);
  // The panel is back on the list, which says so too.
  expect(find.text('File checkpoints'), findsOneWidget);
  expect(
    find.descendant(of: _panel, matching: _says('Restoring files…')),
    findsOneWidget,
  );
  await app.capture('restoring-send-held');

  gate.complete();
  await app.settle();
  expect(_composer(tester).sendHeld, isFalse);
  expect(app.source.fake.restoreRequests, hasLength(2));
  expect(app.source.fake.restoreRequests.last.file, isNull);
  expect(app.source.fake.restoreRequests.last.hash, _newest);
  expect(app.source.fake.count('list'), greaterThan(lists));
  expect(find.text('File checkpoints'), findsOneWidget);
  final listNote = find.byKey(const Key('checkpoints-outcome'));
  expect(
    find.descendant(of: listNote, matching: _says('Restored 4 files')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: listNote, matching: _says('Before a restore')),
    findsOneWidget,
  );
  expect(find.text('Before a restore'), findsNWidgets(2));
  await app.capture('restored-all-list');

  await app.closeActivity();
  expect(_says('Restored 4 files · removed your last message'), findsOneWidget);
  expect(_says(_prompt), findsOneWidget);
  expect(tester.widget<EditableText>(composerField).controller.text, _prompt);
  expect(find.byKey(const Key('composer-handed-back')), findsOneWidget);
  expect(_says('Your last message is back in the box.'), findsOneWidget);
  await app.capture('handed-back');
  await app.finish();
}

/// A full restore whose answer never comes: "Hermes didn't answer", and
/// Restore offered again only behind a new confirmation.
Future<void> _lostAnswerFlow(
  WidgetTester tester,
  String name,
  Size size,
  TargetPlatform platform,
  bool dark,
) async {
  final mode = dark ? 'dark' : 'light';
  final app = _Harness(
    tester,
    ScreenshotRecorder('checkpoints-lost-$name-$mode'),
  );
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake
    ..list = _three()
    ..changes = _changes;
  await app.openLive();
  await app.openActivity();
  await app.tap(find.byType(FileCheckpointsRow));
  await app.tap(find.text('Before a terminal command'));
  await app.tap(find.text('Restore all files…'));
  expect(find.text('Restore all files?'), findsOneWidget);

  // The gateway gives up waiting: the restore may have happened.
  final gate = app.source.fake.restoreGate = Completer<void>();
  app.source.fake.restore = const RestoreMayHaveHappened();
  await app.tap(find.text('Restore all files'));
  expect(_composer(tester).sendHeld, isTrue);
  await app.capture('waiting');
  gate.complete();
  await app.settle();
  expect(_says("Hermes didn't answer"), findsOneWidget);
  expect(_composer(tester).sendHeld, isFalse);
  expect(app.source.fake.count('restore'), 1);
  await app.capture('no-answer');

  await app.tap(find.text('Try again'));
  expect(find.text('Restore all files?'), findsOneWidget);
  expect(app.source.fake.count('restore'), 1);
  await app.capture('offered-again');
  await app.tap(find.text('Cancel'));
  expect(find.text('Restore all files?'), findsNothing);
  expect(app.source.fake.count('restore'), 1);
  expect(app.source.fake.restoreRequests.single.hash, _middle);
  await app.finish();
}

/// An old server, checkpoints off with and without edits, and App Lock.
Future<void> _offFlow(
  WidgetTester tester,
  String name,
  Size size,
  TargetPlatform platform,
  bool dark,
) async {
  final mode = dark ? 'dark' : 'light';
  final app = _Harness(
    tester,
    ScreenshotRecorder('checkpoints-off-$name-$mode'),
  );

  // A server from before checkpoints: `rollback.list` is not a method and
  // its usage carries no context figures. Neither row, and no error.
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake.list = const CheckpointsUnsupported();
  await app.openLive(percent: null);
  await app.openActivity();
  expect(find.byType(ContextRow), findsNothing);
  expect(find.byType(FileCheckpointsRow), findsNothing);
  expect(
    find.descendant(of: _panel, matching: _says("Couldn't")),
    findsNothing,
  );
  expect(app.source.fake.count('list'), 1);
  await app.capture('old-server');
  await app.finish();

  // Off, and the chat never edited a file: no row.
  await app.pump(
    size: size,
    platform: platform,
    dark: dark,
    rows: _rows(withEdit: false),
  );
  app.source.fake.list = const CheckpointsOff();
  await app.openLive();
  await app.openActivity();
  expect(find.byType(FileCheckpointsRow), findsNothing);
  expect(find.byType(ContextRow), findsOneWidget);
  await app.capture('off-without-edits');
  await app.finish();

  // Off, after an edit: the row says so.
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake.list = const CheckpointsOff();
  await app.openLive();
  await app.openActivity();
  expect(find.text('File checkpoints are off'), findsOneWidget);
  await app.capture('off-with-edits');
  await app.finish();

  // App Lock: only the count and the percentage, and the pages close.
  await app.pump(size: size, platform: platform, dark: dark);
  app.source.fake
    ..list = _three()
    ..changes = _changes;
  await app.openLive();
  await app.openActivity();
  await app.tap(find.byType(FileCheckpointsRow));
  await app.tap(find.text('Before editing a file').first);
  expect(find.text('Changes'), findsOneWidget);
  app.lock.cover(true);
  await app.settle();
  expect(find.text('Changes'), findsNothing);
  expect(find.text('3 checkpoints'), findsOneWidget);
  expect(find.text('62%'), findsOneWidget);
  for (final hidden in ['tokens', 'token_refresh', 'Before editing']) {
    expect(find.descendant(of: _panel, matching: _says(hidden)), findsNothing);
  }
  await app.capture('app-lock');
  await app.finish();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('phone-android', phoneSize, TargetPlatform.android),
    ('desktop', desktopSize, TargetPlatform.macOS),
  ]) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        '$name, $mode: context, the suggestion and a compress',
        (tester) => _contextFlow(tester, name, size, platform, dark),
      );
      testWidgets(
        '$name, $mode: checkpoints, changes and restores',
        (tester) => _checkpointsFlow(tester, name, size, platform, dark),
      );
      testWidgets(
        '$name, $mode: a restore whose answer is lost',
        (tester) => _lostAnswerFlow(tester, name, size, platform, dark),
      );
      testWidgets(
        '$name, $mode: old server, off, App Lock',
        (tester) => _offFlow(tester, name, size, platform, dark),
      );
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('a conversation window shows neither row, '
        '${brightness.name}', (tester) async {
      final shots = ScreenshotRecorder(
        'checkpoints-conversation-window-${brightness.name}',
      );
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: _thread, title: _title)]),
        )
        ..on(
          'GET',
          '/api/sessions/$_thread',
          sessionRow(id: _thread, title: _title),
        )
        ..on(
          'GET',
          '/api/sessions/$_thread/messages',
          messageListBody(_thread, _rows()),
        );
      final source = ActionsChatTransport();
      source.fake.list = _three();
      await pumpScreen(
        tester,
        shots,
        ConversationWindowScreen(
          args: const ConversationWindowArgs(
            threadId: _thread,
            profile: 'work',
            title: _title,
            baseUrl: 'https://hermes.test',
            authRequired: true,
          ),
          link: _QuietLink(),
          chat: HermesChatRepository(server.client().raw),
          transport: source,
        ),
        size: const Size(760, 760),
        brightness: brightness,
        platform: TargetPlatform.macOS,
        providers: [Provider<MediaStore?>.value(value: null)],
      );
      source.own(_thread);
      source.reportUsage(_thread, 62);
      await tester.runAsync(() => pumpEventQueue(times: 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('window-activity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-inspector')), findsOneWidget);
      expect(find.byType(ContextRow), findsNothing);
      expect(find.byType(FileCheckpointsRow), findsNothing);
      expect(source.fake.calls, isEmpty);
      await shots.capture(tester, 'activity');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(source.close);
    });
  }
}

class _QuietLink implements ConversationWindowLink {
  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};

  @override
  Stream<String> get commands => const Stream.empty();

  @override
  Stream<bool> get keyChanges => const Stream.empty();

  @override
  void reportFocus(bool focused) {}

  @override
  void reportThread(String title, {required bool pinned}) {}

  @override
  Future<void> showInMain(String threadId, String? profile) async {}

  @override
  Future<void> showMain() async {}

  @override
  Future<void> present({
    required String frameName,
    required String title,
  }) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> share(String text, Rect anchor) async {}
}
