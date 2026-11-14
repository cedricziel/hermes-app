import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/changed_files_list.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/checkpoint_list_body.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_diff_view.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_all_bar.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

Widget _app(Widget child, {double scale = 1, TargetPlatform? platform}) =>
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

const _longName = 'composer_attachment_preview_tile_with_a_very_long_name.dart';

/// A text whose content is [name] once the invisible break opportunities the
/// widgets add (`breakableFileName`) are taken out.
Finder _named(String name) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u200B', '') == name,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ChangedFilesList', () {
    testWidgets('a long file name wraps at 3x text and keeps its extension', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ChangedFilesList(
            files: const [
              ChangedFile(
                path: 'lib/src/chat/widgets/$_longName',
                restorable: true,
                added: 12,
                removed: 3,
              ),
            ],
            onOpen: (_) {},
          ),
          scale: 3,
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(_named(_longName));
      expect(title.maxLines, isNull);
      expect(title.overflow, isNot(TextOverflow.ellipsis));
      final paragraph = tester.renderObject<RenderParagraph>(_named(_longName));
      expect(paragraph.didExceedMaxLines, isFalse);
      // The extension is never split from its dot: the name only breaks at
      // underscores, hyphens and before the dot.
      expect(breakableFileName(_longName), contains('\u200B.'));
      expect(
        breakableFileName('a_b-c.dart').replaceAll('\u200B', '|'),
        'a_|b-|c|.dart',
      );
      // More than one line: it wrapped instead of being cut.
      expect(
        paragraph.size.height,
        greaterThan(paragraph.text.style!.fontSize! * 3 * 1.5),
      );
      expect(_longName.endsWith('.dart'), isTrue);
    });

    testWidgets('the line under the name has the folder and the counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ChangedFilesList(
            files: const [
              ChangedFile(
                path: 'src/auth/token_refresh.dart',
                added: 48,
                removed: 112,
              ),
              ChangedFile(path: 'pubspec.yaml', added: 1, removed: 0),
              ChangedFile(path: 'src/chat/part.dart', changes: 20),
              ChangedFile(path: 'assets/logo.png', binary: true),
            ],
          ),
        ),
      );
      expect(find.text('src/auth · +48 −112'), findsOneWidget);
      expect(find.text('Top of the folder · +1 −0'), findsOneWidget);
      expect(find.text('src/chat · 20 lines changed'), findsOneWidget);
      expect(find.text('assets · Not text, no preview'), findsOneWidget);
    });

    testWidgets('a file without a diff says so only when the diff was cut', (
      tester,
    ) async {
      const files = [ChangedFile(path: 'a/b.dart', changes: 3)];
      await tester.pumpWidget(_app(const ChangedFilesList(files: files)));
      expect(find.textContaining('Hermes cut this diff short'), findsNothing);
      expect(find.textContaining('first part of a large diff'), findsNothing);

      await tester.pumpWidget(
        _app(const ChangedFilesList(files: files, truncated: true)),
      );
      expect(find.textContaining('Hermes cut this diff short'), findsOneWidget);
      expect(find.textContaining('The file list is complete.'), findsOneWidget);
    });

    testWidgets('a row reads its name and counts to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          ChangedFilesList(
            files: const [
              ChangedFile(path: 'src/a.dart', added: 12, removed: 3),
            ],
            onOpen: (_) {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('a.dart, 12 lines added, 3 removed'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('FileDiffView', () {
    CheckpointChanges parse(String stat) =>
        parseCheckpointChanges({'stat': stat, 'diff': ''});

    testWidgets('offers Restore this file for a name read back exactly', (
      tester,
    ) async {
      var restored = 0;
      await tester.pumpWidget(
        _app(
          FileDiffView(
            file: const ChangedFile(
              path: 'src/a.dart',
              restorable: true,
              added: 1,
              removed: 0,
              diff: '@@ -1 +1 @@\n+x\n',
            ),
            onRestore: () => restored++,
          ),
        ),
      );
      await tester.tap(find.text('Restore this file…'));
      expect(restored, 1);
      expect(_named('Changes in a.dart'), findsOneWidget);
      expect(find.text('1 added, 0 removed'), findsOneWidget);
    });

    testWidgets('a name that cannot be restored alone gets a line, no button', (
      tester,
    ) async {
      final changes =
          parse(' notes/[draft] plan.md | 3 ++-\n 1 file changed') as Changes;
      final file = changes.files.single;
      expect(file.restorable, isFalse);
      await tester.pumpWidget(_app(FileDiffView(file: file, onRestore: () {})));
      expect(find.byType(DestructiveTintButton), findsNothing);
      expect(
        find.text(
          "This file's name can't be restored one at a time. Use Restore all files.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a name git shortened says so instead', (tester) async {
      final changes = parse(
        ' .../deep/token_refresh.dart | 3 ++-\n 1 file changed',
      ) as Changes;
      final file = changes.files.single;
      expect(isShortenedChangedPath(file), isTrue);
      await tester.pumpWidget(_app(FileDiffView(file: file, onRestore: () {})));
      expect(find.byType(DestructiveTintButton), findsNothing);
      expect(find.textContaining('Git shortened this name'), findsOneWidget);
    });

    testWidgets('disconnected disables the button and says why', (
      tester,
    ) async {
      var restored = 0;
      await tester.pumpWidget(
        _app(
          FileDiffView(
            file: const ChangedFile(path: 'a.dart', restorable: true),
            restoreRefusal: RestoreRefusal.disconnected,
            onRestore: () => restored++,
          ),
        ),
      );
      expect(find.text('Reconnect to restore files.'), findsOneWidget);
      await tester.tap(find.text('Restore this file…'), warnIfMissed: false);
      expect(restored, 0);
    });

    testWidgets('binary and cut files get their notes', (tester) async {
      await tester.pumpWidget(
        _app(
          const FileDiffView(
            file: ChangedFile(path: 'logo.png', binary: true),
            showAction: false,
          ),
        ),
      );
      expect(
        find.text("This file isn't text, so there is no preview."),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _app(
          const FileDiffView(
            file: ChangedFile(path: 'a.dart', changes: 4),
            truncated: true,
            showAction: false,
          ),
        ),
      );
      expect(find.text('Hermes cut this diff short.'), findsOneWidget);
    });
  });

  group('RestoreAllBar', () {
    Future<void> pump(
      WidgetTester tester, {
      RestoreRefusal? refusal,
      int? count = 5,
      VoidCallback? onTap,
    }) => tester.pumpWidget(
      _app(
        RestoreAllBar(fileCount: count, refusal: refusal, onRestoreAll: onTap),
      ),
    );

    testWidgets('idle counts the files and starts the restore', (tester) async {
      var taps = 0;
      await pump(tester, onTap: () => taps++);
      expect(find.text('5 files differ'), findsOneWidget);
      await tester.tap(find.text('Restore all files…'));
      expect(taps, 1);
    });

    testWidgets('an unknown count reads Some files differ', (tester) async {
      await pump(tester, count: null);
      expect(find.text('Some files differ'), findsOneWidget);
    });

    for (final (refusal, reason) in [
      (RestoreRefusal.replying, 'Wait for the reply to finish.'),
      (RestoreRefusal.disconnected, 'Reconnect to restore files.'),
    ]) {
      testWidgets('$refusal disables the button and says why', (tester) async {
        var taps = 0;
        await pump(tester, refusal: refusal, onTap: () => taps++);
        expect(find.text(reason), findsOneWidget);
        await tester.tap(find.text('Restore all files…'), warnIfMissed: false);
        expect(taps, 0);
      });
    }

    testWidgets('restoring shows the button busy with no reason', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        refusal: RestoreRefusal.restoring,
        onTap: () => taps++,
      );
      expect(find.text('Restoring…'), findsOneWidget);
      expect(find.text('Wait for the restore to finish.'), findsNothing);
      await tester.tap(find.text('Restoring…'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('CheckpointListBody', () {
    testWidgets('a row title is a fixed sentence, never the reason text', (
      tester,
    ) async {
      final parsed =
          parseCheckpointList({
                'enabled': true,
                'checkpoints': [
                  {
                    'hash': 'aaa111bbb222',
                    'timestamp': '2026-09-29T10:00:00+00:00',
                    'message': 'before terminal: rm -rf build_secret_dir',
                  },
                  {
                    'hash': 'ccc333ddd444',
                    'timestamp': '2026-09-29T09:00:00+00:00',
                    'message': 'before write_file: src/secret_name.dart',
                  },
                  {
                    'hash': 'eee555fff666',
                    'message': 'pre-rollback snapshot (restoring to 1234abcd)',
                  },
                  {'hash': '0a0b0c0d0e0f', 'message': 'something else'},
                ],
              })!
              as CheckpointsOn;
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 800,
            child: CheckpointListBody(
              status: CheckpointListStatus.loaded,
              items: [
                for (final c in parsed.checkpoints)
                  CheckpointListItem(checkpoint: c, timeLabel: '12 min ago'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Before a terminal command'), findsOneWidget);
      expect(find.text('Before editing a file'), findsOneWidget);
      expect(find.text('Before a restore'), findsOneWidget);
      expect(find.text('Checkpoint'), findsOneWidget);
      for (final raw in [
        'rm -rf',
        'build_secret_dir',
        'secret_name',
        'write_file',
        'pre-rollback',
        '1234abcd',
      ]) {
        expect(find.textContaining(raw), findsNothing);
      }
    });

    testWidgets('a null time reads Unknown time', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 800,
            child: CheckpointListBody(
              status: CheckpointListStatus.loaded,
              items: const [
                CheckpointListItem(
                  checkpoint: Checkpoint(
                    hash: 'aaa111bbb222',
                    reason: CheckpointReason.beforeEdit,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Unknown time'), findsOneWidget);
    });

    testWidgets('the off message keeps the config key as selectable code', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            height: 800,
            child: CheckpointListBody(status: CheckpointListStatus.off),
          ),
        ),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        find.textContaining('checkpoints.enabled', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('App Lock shows only the count', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 800,
            child: CheckpointListBody(
              status: CheckpointListStatus.locked,
              items: [
                for (var i = 0; i < 3; i++)
                  CheckpointListItem(
                    checkpoint: Checkpoint(
                      hash: 'aaa111bbb22$i',
                      reason: CheckpointReason.beforeEdit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('3 checkpoints'), findsOneWidget);
      expect(find.text('Before editing a file'), findsNothing);
    });

    testWidgets('disconnected keeps the list and marks it not up to date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 800,
            child: CheckpointListBody(
              status: CheckpointListStatus.loaded,
              disconnected: true,
              items: const [
                CheckpointListItem(
                  checkpoint: Checkpoint(
                    hash: 'aaa111bbb222',
                    reason: CheckpointReason.beforeEdit,
                  ),
                  timeLabel: '12 min ago',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.text('Not up to date · reconnect to restore'),
        findsOneWidget,
      );
      expect(find.text('Before editing a file'), findsOneWidget);
    });
  });
}
