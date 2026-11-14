import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_page_scaffold.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_panel.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_working_line.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/changed_files_list.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/changes_page_message.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/checkpoint_list_body.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/checkpoint_row.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_checkpoints_row.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_diff_view.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_outcome_note.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/compress_outcome_note.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_all_bar.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Invented fixtures: file names, folders and times are made up.

const _times = [
  '12 min ago',
  '48 min ago',
  '2 h ago',
  'Yesterday',
  '2 days ago',
  '3 days ago',
  '5 days ago',
];

CheckpointListItem _item(
  int i, {
  CheckpointReason reason = CheckpointReason.beforeEdit,
  bool unknown = false,
}) => CheckpointListItem(
  checkpoint: Checkpoint(
    hash: 'a1b2c3d4e5f6${i.toRadixString(16).padLeft(4, '0')}',
    reason: reason,
  ),
  timeLabel: unknown ? null : _times[i % _times.length],
  timeSemanticsLabel: unknown ? null : '14 November 2026 at 10:${40 - i}',
);

List<CheckpointListItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    _item(
      i,
      reason: switch (i % 4) {
        0 => CheckpointReason.beforeEdit,
        1 => CheckpointReason.beforeTerminal,
        2 => CheckpointReason.beforeEdit,
        _ => CheckpointReason.beforeRestore,
      },
    ),
];

const _diff =
    '''diff --git a/src/auth/token_refresh.dart b/src/auth/token_refresh.dart
--- a/src/auth/token_refresh.dart
+++ b/src/auth/token_refresh.dart
@@ -10,7 +10,9 @@ class TokenRefresh {
   final Clock clock;
-  Future<Token> refresh(Token old) async {
-    return _client.post(old.refreshToken);
+  Future<Token> refresh(Token old) async {
+    final fresh = await _client.post(old.refreshToken);
+    _store.save(fresh);
+    return fresh;
   }

   bool isExpired(Token t) => t.expiresAt.isBefore(clock.now());
''';

final _longDiff = [
  _diff,
  '@@ -40,6 +42,8 @@ class TokenRefresh {',
  for (var i = 0; i < 14; i++)
    '+  final Map<String, Object?> payload$i = {"session": session.id, "refreshToken": token.refreshToken, "scope": scopes.join(" "), "client": clientId};',
  '-  // The old refresh path, kept here for reference only.',
  '   return fresh;',
].join('\n');

const _file = ChangedFile(
  path: 'src/auth/token_refresh.dart',
  restorable: true,
  added: 48,
  removed: 112,
  changes: 160,
  diff: _diff,
);

final _fiveFiles = [
  _file,
  const ChangedFile(
    path: 'src/auth/session_store.dart',
    restorable: true,
    added: 6,
    removed: 2,
    diff: _diff,
  ),
  const ChangedFile(
    path: 'pubspec.yaml',
    restorable: true,
    added: 1,
    removed: 1,
    diff: _diff,
  ),
  const ChangedFile(
    path: 'test/auth/token_refresh_test.dart',
    restorable: true,
    added: 31,
    removed: 0,
    diff: _diff,
  ),
  const ChangedFile(
    path: 'README.md',
    restorable: true,
    added: 3,
    removed: 0,
    diff: _diff,
  ),
];

final _tenFilesCut = [
  for (var i = 0; i < 4; i++)
    ChangedFile(
      path: 'src/auth/part_$i.dart',
      restorable: true,
      added: 10 + i,
      removed: i,
      diff: _diff,
    ),
  for (var i = 4; i < 10; i++)
    ChangedFile(path: 'src/chat/part_$i.dart', restorable: true, changes: 20),
];

const _longNames = [
  ChangedFile(
    path: 'lib/src/chat/widgets/composer_attachment_preview_tile_with_a_very_long_name.dart',
    restorable: true,
    added: 12,
    removed: 3,
    diff: _diff,
  ),
  ChangedFile(
    path: 'docs/architecture/notifications-and-background-work.md',
    restorable: true,
    added: 2,
    removed: 2,
    diff: _diff,
  ),
];

Widget _scaled(Widget child, [double factor = 3]) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(factor)),
    child: child,
  ),
);

Widget _section(Widget row) => GroupedSection(children: [row]);

/// Opens the row's menu once it is on screen, so the catalog shows it open.
class _OpenMenuRow extends StatefulWidget {
  const _OpenMenuRow({this.refusal});

  final RestoreRefusal? refusal;

  @override
  State<_OpenMenuRow> createState() => _OpenMenuRowState();
}

class _OpenMenuRowState extends State<_OpenMenuRow> {
  final _menu = AdaptiveMenuController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menu.open();
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: Align(
      alignment: Alignment.topCenter,
      child: _section(
        CheckpointRow(
          reason: CheckpointReason.beforeEdit,
          timeLabel: _times.first,
          timeSemanticsLabel: '14 November 2026 at 10:40',
          restoreRefusal: widget.refusal,
          menuController: _menu,
          onSeeChanges: () {},
          onRestoreAll: () {},
        ),
      ),
    ),
  );
}

CheckpointListBody _list(
  CheckpointListStatus status, {
  List<CheckpointListItem> items = const [],
  bool disconnected = false,
  RestoreRefusal? refusal,
  int? lockedCount,
}) => CheckpointListBody(
  status: status,
  lockedCount: lockedCount,
  items: items,
  disconnected: disconnected,
  restoreRefusal: refusal,
  onSeeChanges: (_) {},
  onRestoreAll: (_) {},
  onRetry: () {},
  onRefresh: () async {},
);

/// The Changes page as it stands with files: the list scrolls over the
/// sticky footer.
Widget _changesPage({
  required List<ChangedFile> files,
  bool truncated = false,
  int? count,
  RestoreRefusal? refusal,
  double? scale,
}) {
  final page = Column(
    children: [
      Expanded(
        child: GroupedListView(
          children: [
            ChangedFilesList(
              files: files,
              truncated: truncated,
              onOpen: (_) {},
            ),
          ],
        ),
      ),
      RestoreAllBar(
        fileCount: count ?? files.length,
        refusal: refusal,
        onRestoreAll: () {},
      ),
    ],
  );
  return fill(scale == null ? page : _scaled(page, scale));
}

Widget _fileRow(
  CheckpointsRowState state, {
  int? count = 3,
  bool locked = false,
}) => frame(
  maxWidth: 380,
  FileCheckpointsRow(
    state: state,
    count: count,
    locked: locked,
    onOpen: locked ? null : () {},
  ),
);

const _panelFigures = ContextFigures(
  used: 172000,
  max: 200000,
  percent: 86,
  estimated: false,
  source: ContextSource.providerUsage,
);

/// The panel as the chat shows it: Context first, File checkpoints next,
/// then the outcome notes, and the working lines under Now.
Widget _panel({
  bool working = false,
  bool locked = false,
  bool suggestion = false,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: 380,
    height: 640,
    child: Material(
      child: ActivityPanel(
        now: [
          if (working) ...[_compressingLine(), _restoringLine()],
        ],
        session: [
          ContextRow(
            figures: _panelFigures,
            level: ContextLevel.nearlyFull,
            locked: locked,
            compressing: working,
            suggestionVisible: suggestion,
            onOpen: locked ? null : () {},
            onCompress: () {},
            onDismissSuggestion: () {},
          ),
          FileCheckpointsRow(
            state: CheckpointsRowState.count,
            count: 3,
            locked: locked,
            onOpen: locked ? null : () {},
          ),
          if (!locked && !working) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CompressOutcomeNote(
                outcome: CompressOutcome(
                  CompressOutcomeKind.compressed,
                  beforeMessages: 42,
                  afterMessages: 9,
                  beforeTokens: 120000,
                  afterTokens: 30000,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: RestoreOutcomeNote(
                outcome: RestoreOutcome(
                  RestoreOutcomeKind.restored,
                  filesRestored: 1,
                  safetyCheckpoint: true,
                ),
                filesWereFile: true,
              ),
            ),
          ],
        ],
      ),
    ),
  ),
);

Widget _compressingLine() => Builder(
  builder: (context) =>
      ActivityWorkingLine(label: context.l10n.chatContextCompressing),
);

Widget _restoringLine() => Builder(
  builder: (context) =>
      ActivityWorkingLine(label: context.l10n.chatCheckpointsPageRestoring),
);

/// A page pushed inside the panel, at a phone sheet's or an inspector's size.
Widget _page({
  String title = 'Changes',
  String? subtitle = 'Since 12 min ago · Before editing a file',
  bool withBottom = false,
  double width = 380,
}) => Builder(
  builder: (context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: 560,
      child: ActivityPageScaffold(
        title: title,
        subtitle: subtitle,
        onBack: () {},
        actions: [
          ActivityPageAction(
            label: context.l10n.chatCheckpointsPageRefresh,
            icon: AppIcons.refresh,
            onPressed: () {},
          ),
        ],
        body: GroupedListView(
          children: [ChangedFilesList(files: _fiveFiles, onOpen: (_) {})],
        ),
        framedBottom: false,
        bottom: withBottom
            ? RestoreAllBar(fileCount: 5, onRestoreAll: () {})
            : null,
      ),
    ),
  ),
);

WidgetbookNode chatCheckpointsNode() => WidgetbookFolder(
  name: 'Chat checkpoints',
  children: [
    WidgetbookComponent(
      name: 'File checkpoints row',
      useCases: [
        ...onEachPlatform('Count', (_) => _fileRow(CheckpointsRowState.count)),
        WidgetbookUseCase(
          name: 'Not checked yet',
          builder: (_) => _fileRow(CheckpointsRowState.notChecked),
        ),
        ...onEachPlatform(
          'Loading',
          (_) => _fileRow(CheckpointsRowState.loading),
        ),
        WidgetbookUseCase(
          name: 'Off with edits',
          builder: (_) => _fileRow(CheckpointsRowState.off),
        ),
        WidgetbookUseCase(
          name: 'Failed',
          builder: (_) => _fileRow(CheckpointsRowState.failed),
        ),
        WidgetbookUseCase(
          name: 'App Lock (count only)',
          builder: (_) =>
              _fileRow(CheckpointsRowState.count, count: 3, locked: true),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(_fileRow(CheckpointsRowState.count)),
        ),
        WidgetbookUseCase(
          name: 'Largest text, off',
          builder: (_) => _scaled(_fileRow(CheckpointsRowState.off)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Panel with Context and File checkpoints',
      useCases: [
        ...onEachPlatform('Rows and notes', (_) => _panel()),
        WidgetbookUseCase(
          name: 'Suggestion',
          builder: (_) => _panel(suggestion: true),
        ),
        WidgetbookUseCase(
          name: 'Compress and restore running',
          builder: (_) => _panel(working: true),
        ),
        WidgetbookUseCase(
          name: 'App Lock',
          builder: (_) => _panel(locked: true),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(_panel(suggestion: true)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Activity page',
      useCases: [
        ...onEachPlatform('Title, subtitle and action', (_) => _page()),
        ...onEachPlatform(
          'With the Restore all bar',
          (_) => _page(withBottom: true),
        ),
        WidgetbookUseCase(
          name: 'No subtitle',
          builder: (_) => _page(title: 'File checkpoints', subtitle: null),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(_page(withBottom: true)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Working line',
      useCases: [
        ...onEachPlatform(
          'Restoring files',
          (_) => frame(_restoringLine(), maxWidth: 380),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(frame(_compressingLine(), maxWidth: 380)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Checkpoint row',
      useCases: [
        ...onEachPlatform(
          'Newest',
          (_) => frame(
            _section(
              CheckpointRow(
                reason: CheckpointReason.beforeEdit,
                timeLabel: _times.first,
                timeSemanticsLabel: '14 November 2026 at 10:40',
                onSeeChanges: () {},
                onRestoreAll: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Unknown time',
          builder: (_) => frame(
            _section(
              CheckpointRow(
                reason: CheckpointReason.other,
                onSeeChanges: () {},
                onRestoreAll: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Before a terminal command',
          builder: (_) => frame(
            _section(
              CheckpointRow(
                reason: CheckpointReason.beforeTerminal,
                timeLabel: _times[1],
                onSeeChanges: () {},
                onRestoreAll: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Before a restore',
          builder: (_) => frame(
            _section(
              CheckpointRow(
                reason: CheckpointReason.beforeRestore,
                timeLabel: _times[2],
                timeSemanticsLabel: '14 November 2026 at 08:12',
                onSeeChanges: () {},
                onRestoreAll: () {},
              ),
            ),
          ),
        ),
        ...onEachPlatform(
          'Menu open',
          (_) => frame(const _OpenMenuRow(), maxWidth: 480),
        ),
        ...onEachPlatform(
          'Menu open, disconnected',
          (_) => frame(
            const _OpenMenuRow(refusal: RestoreRefusal.disconnected),
            maxWidth: 480,
          ),
        ),
        WidgetbookUseCase(
          name: 'Disconnected (restore disabled)',
          builder: (_) => frame(
            _section(
              CheckpointRow(
                reason: CheckpointReason.beforeEdit,
                timeLabel: _times.first,
                restoreRefusal: RestoreRefusal.disconnected,
                onSeeChanges: () {},
                onRestoreAll: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => frame(
            _scaled(
              _section(
                CheckpointRow(
                  reason: CheckpointReason.beforeTerminal,
                  timeLabel: _times.first,
                  onSeeChanges: () {},
                  onRestoreAll: () {},
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Checkpoint list',
      useCases: [
        WidgetbookUseCase(
          name: 'Five checkpoints',
          builder: (_) =>
              fill(_list(CheckpointListStatus.loaded, items: _items(5))),
        ),
        WidgetbookUseCase(
          name: 'Twenty checkpoints',
          builder: (_) =>
              fill(_list(CheckpointListStatus.loaded, items: _items(20))),
        ),
        WidgetbookUseCase(
          name: 'Unknown times',
          builder: (_) => fill(
            _list(
              CheckpointListStatus.loaded,
              items: [
                _item(0, unknown: true),
                _item(1, reason: CheckpointReason.other, unknown: true),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Empty',
          builder: (_) => fill(_list(CheckpointListStatus.empty)),
        ),
        WidgetbookUseCase(
          name: 'Off on the server',
          builder: (_) => fill(_list(CheckpointListStatus.off)),
        ),
        WidgetbookUseCase(
          name: 'Loading',
          builder: (_) => fill(_list(CheckpointListStatus.loading)),
        ),
        WidgetbookUseCase(
          name: 'Failed',
          builder: (_) => fill(_list(CheckpointListStatus.failed)),
        ),
        WidgetbookUseCase(
          name: 'Workspace not covered',
          builder: (_) => fill(_list(CheckpointListStatus.notCovered)),
        ),
        WidgetbookUseCase(
          name: 'Disconnected (list kept, restore disabled)',
          builder: (_) => fill(
            _list(
              CheckpointListStatus.loaded,
              items: _items(5),
              disconnected: true,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Reply running (restore disabled)',
          builder: (_) => fill(
            _list(
              CheckpointListStatus.loaded,
              items: _items(3),
              refusal: RestoreRefusal.replying,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'App Lock (count only)',
          builder: (_) =>
              fill(_list(CheckpointListStatus.locked, lockedCount: 5)),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => fill(
            _scaled(_list(CheckpointListStatus.loaded, items: _items(3))),
          ),
        ),
        WidgetbookUseCase(
          name: 'Off, largest text',
          builder: (_) => fill(_scaled(_list(CheckpointListStatus.off))),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Changed files list',
      useCases: [
        WidgetbookUseCase(
          name: 'Five files',
          builder: (_) => frame(
            ChangedFilesList(files: _fiveFiles, onOpen: (_) {}),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Ten files, diff cut short',
          builder: (_) => frame(
            ChangedFilesList(
              files: _tenFilesCut,
              truncated: true,
              onOpen: (_) {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Binary file',
          builder: (_) => frame(
            ChangedFilesList(
              files: const [
                ChangedFile(
                  path: 'assets/images/logo.png',
                  restorable: true,
                  binary: true,
                  changes: 0,
                ),
                _file,
              ],
              onOpen: (_) {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Renamed file (no restore hint)',
          builder: (_) => frame(
            ChangedFilesList(
              files: const [
                ChangedFile(
                  path: 'src/auth/token_store.dart',
                  renamed: true,
                  changes: 4,
                  added: 2,
                  removed: 2,
                  diff: _diff,
                ),
                ChangedFile(
                  path: '...ts/very/deep/token_refresh.dart',
                  changes: 9,
                ),
              ],
              onOpen: (_) {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Long names, 1x',
          builder: (_) => frame(
            ChangedFilesList(files: _longNames, onOpen: (_) {}),
            maxWidth: 360,
          ),
        ),
        WidgetbookUseCase(
          name: 'Long names, 2x text',
          builder: (_) => frame(
            _scaled(ChangedFilesList(files: _longNames, onOpen: (_) {}), 2),
            maxWidth: 390,
          ),
        ),
        WidgetbookUseCase(
          name: 'Long names, 3x text',
          builder: (_) => frame(
            _scaled(ChangedFilesList(files: _longNames, onOpen: (_) {})),
            maxWidth: 390,
          ),
        ),
        WidgetbookUseCase(
          name: 'One selected (diff beside the list)',
          builder: (_) => frame(
            ChangedFilesList(
              files: _fiveFiles,
              selectedPath: _fiveFiles[1].path,
              onOpen: (_) {},
            ),
            maxWidth: 320,
          ),
        ),
        WidgetbookUseCase(
          name: 'Disconnected (rows stay openable)',
          builder: (_) => _changesPage(
            files: _fiveFiles,
            refusal: RestoreRefusal.disconnected,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Restore all bar',
      useCases: [
        ...onEachPlatform(
          'Idle',
          (_) => frame(
            RestoreAllBar(fileCount: 5, onRestoreAll: () {}),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Count unknown',
          builder: (_) =>
              frame(RestoreAllBar(onRestoreAll: () {}), maxWidth: 600),
        ),
        ...onEachPlatform(
          'Reply running',
          (_) => frame(
            RestoreAllBar(
              fileCount: 5,
              refusal: RestoreRefusal.replying,
              onRestoreAll: () {},
            ),
            maxWidth: 600,
          ),
        ),
        ...onEachPlatform(
          'Disconnected',
          (_) => frame(
            RestoreAllBar(
              fileCount: 5,
              refusal: RestoreRefusal.disconnected,
              onRestoreAll: () {},
            ),
            maxWidth: 600,
          ),
        ),
        ...onEachPlatform(
          'Restoring',
          (_) => frame(
            RestoreAllBar(
              fileCount: 5,
              refusal: RestoreRefusal.restoring,
              onRestoreAll: () {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => frame(
            _scaled(
              RestoreAllBar(
                fileCount: 5,
                refusal: RestoreRefusal.replying,
                onRestoreAll: () {},
              ),
            ),
            maxWidth: 390,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'File diff view',
      useCases: [
        WidgetbookUseCase(
          name: 'Short',
          builder: (_) =>
              frame(FileDiffView(file: _file, onRestore: () {}), maxWidth: 600),
        ),
        WidgetbookUseCase(
          name: 'Long (scrolls sideways)',
          builder: (_) => frame(
            FileDiffView(
              file: ChangedFile(
                path: 'src/auth/token_refresh.dart',
                restorable: true,
                added: 14,
                removed: 3,
                diff: _longDiff,
              ),
              onRestore: () {},
            ),
            maxWidth: 390,
          ),
        ),
        WidgetbookUseCase(
          name: 'Cut short',
          builder: (_) => frame(
            FileDiffView(
              file: const ChangedFile(
                path: 'src/chat/part_7.dart',
                restorable: true,
                changes: 20,
              ),
              truncated: true,
              onRestore: () {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Not text',
          builder: (_) => frame(
            FileDiffView(
              file: const ChangedFile(
                path: 'assets/images/logo.png',
                restorable: true,
                binary: true,
              ),
              onRestore: () {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Name that can\'t be restored alone',
          builder: (_) => frame(
            FileDiffView(
              file: const ChangedFile(
                path: 'notes/[draft] plan?.md',
                added: 4,
                removed: 1,
                diff: _diff,
              ),
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Shortened name',
          builder: (_) => frame(
            FileDiffView(
              file: const ChangedFile(
                path: '...ts/very/deep/token_refresh.dart',
                added: 4,
                removed: 1,
                diff: _diff,
              ),
            ),
            maxWidth: 600,
          ),
        ),
        ...onEachPlatform(
          'Disconnected',
          (_) => frame(
            FileDiffView(
              file: _file,
              restoreRefusal: RestoreRefusal.disconnected,
              onRestore: () {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Restoring',
          builder: (_) => frame(
            FileDiffView(
              file: _file,
              restoreRefusal: RestoreRefusal.restoring,
              restoring: true,
              onRestore: () {},
            ),
            maxWidth: 600,
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => frame(
            _scaled(FileDiffView(file: _file, onRestore: () {})),
            maxWidth: 390,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Changes page states',
      useCases: [
        WidgetbookUseCase(
          name: 'Five files with footer',
          builder: (_) => _changesPage(files: _fiveFiles),
        ),
        WidgetbookUseCase(
          name: 'Ten files cut short',
          builder: (_) =>
              _changesPage(files: _tenFilesCut, truncated: true, count: 10),
        ),
        WidgetbookUseCase(
          name: 'Reply running',
          builder: (_) =>
              _changesPage(files: _fiveFiles, refusal: RestoreRefusal.replying),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _changesPage(files: _fiveFiles, scale: 3),
        ),
        WidgetbookUseCase(
          name: 'Loading',
          builder: (_) =>
              fill(const ChangesPageMessage(status: ChangesPageStatus.loading)),
        ),
        WidgetbookUseCase(
          name: 'Unreadable',
          builder: (_) => fill(
            ChangesPageMessage(
              status: ChangesPageStatus.unreadable,
              onRetry: () {},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'No changes',
          builder: (_) => fill(
            const ChangesPageMessage(
              status: ChangesPageStatus.none,
              sinceLabel: '12 min ago',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Container refusal',
          builder: (_) =>
              fill(const ChangesPageMessage(status: ChangesPageStatus.refused)),
        ),
      ],
    ),
  ],
);
