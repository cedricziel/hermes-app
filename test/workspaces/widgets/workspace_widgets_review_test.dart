import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/workspaces/widgets/change_folder_confirmation.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';

import '../../files/widgets/files_widget_harness.dart';

const _demo = '/home/me/code/demo';
const _def = WorkspacePickerRow(id: 'default', title: 'demo', path: _demo);
const _rows = [
  WorkspacePickerRow(id: 'a', title: 'alpha', path: '/home/me/alpha'),
  WorkspacePickerRow(id: 'b', title: 'bravo', path: '/home/me/bravo'),
  WorkspacePickerRow(id: 'c', title: 'charlie', path: '/home/me/charlie'),
];

Widget _picker({
  bool offline = false,
  bool scan = false,
  ValueChanged<String>? onPick,
  VoidCallback? onCancel,
  List<WorkspacePickerRow> projects = _rows,
}) => WorkspacePickerView(
  selectedId: 'default',
  serverDefault: _def,
  projects: projects,
  offline: offline,
  scanAvailable: scan,
  onPick: onPick,
  onCancel: onCancel,
  onBrowse: () {},
  onType: () {},
);

ServerPath _p(String t) => ServerPath.tryParse(t)!;

Widget _browser(String path, {FolderBrowserLevel? level}) => FolderBrowserView(
  current: _p(path),
  level: level ?? FolderBrowserLevel.ready,
  rows: [FileRowModel(name: 'demo', isFolder: true, path: _p('$path/demo'))],
  onUse: () {},
  onUp: () {},
  onTryAgain: () {},
);

const _mac = TargetPlatform.macOS;
const _tall = Size(700, 1200);

double _h(WidgetTester t, Finder f) => t.getSize(f.first).height;

void main() {
  testWidgets('the harness gives a Mac theme the compact density of a Mac', (
    tester,
  ) async {
    await pumpFiles(tester, const SizedBox(), platform: _mac);
    final context = tester.element(find.byType(SizedBox).first);
    expect(Theme.of(context).visualDensity, VisualDensity.compact);
  });

  group('Mac targets are 28 pt with the real density', () {
    testWidgets('Use, the picker Cancel and Try again', (tester) async {
      await pumpFiles(
        tester,
        _browser('/home/me/code', level: FolderBrowserLevel.unreachable),
        platform: _mac,
        size: _tall,
      );
      expect(_h(tester, find.byKey(const Key('folder-browser-use'))), 28);
      expect(_h(tester, find.widgetWithText(OutlinedButton, 'Try again')), 28);
      // The Mac button keeps its own width instead of stretching.
      expect(
        tester.getSize(find.byKey(const Key('folder-browser-use'))).width,
        lessThan(300),
      );
      await pumpFiles(tester, _picker(), platform: _mac, size: _tall);
      expect(_h(tester, find.byKey(const Key('workspace-picker-cancel'))), 28);
    });

    testWidgets('Change folder… and Check again', (tester) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryDetails(
          folderName: 'api',
          path: _demo,
          move: WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
          moveTarget: '/home/me/other',
        ),
        platform: _mac,
        size: _tall,
      );
      expect(_h(tester, find.byKey(const Key('working-directory-change'))), 28);
      expect(_h(tester, find.widgetWithText(TextButton, 'Check again')), 28);
      await pumpFiles(
        tester,
        const PathEntryView(text: '/x', check: PathEntryCheck.tooSlow),
        platform: _mac,
        size: _tall,
      );
      expect(_h(tester, find.byKey(const Key('path-entry-check-again'))), 28);
    });

    testWidgets('Mac detail rows are 32 pt', (tester) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryDetails(folderName: 'api', path: _demo),
        platform: _mac,
        size: _tall,
      );
      final rows = find.ancestor(
        of: find.text('Folder'),
        matching: find.byType(ConstrainedBox),
      );
      expect(
        tester.getSize(rows.first).height,
        lessThan(40),
        reason: 'a Mac row is 32 pt, not the 40 pt of the grouped list',
      );
    });
  });

  group('touch targets are 44 pt', () {
    testWidgets('Use, Try again and Change folder…', (tester) async {
      await pumpFiles(
        tester,
        _browser('/home/me/code', level: FolderBrowserLevel.unreachable),
      );
      expect(
        _h(tester, find.byKey(const Key('folder-browser-use'))),
        greaterThanOrEqualTo(44),
      );
      expect(
        _h(tester, find.widgetWithText(OutlinedButton, 'Try again')),
        greaterThanOrEqualTo(44),
      );
      await pumpFiles(
        tester,
        const WorkingDirectoryDetails(folderName: 'api', path: _demo),
      );
      expect(
        _h(tester, find.byKey(const Key('working-directory-change'))),
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('Mac bars at large text do not overflow', () {
    for (final scale in [2.0, 3.0]) {
      for (final (name, page) in <(String, Widget)>[
        ('picker', _picker(scan: true)),
        ('browse', _browser('/home/me/code')),
        ('type', const PathEntryView(text: '/home/me')),
      ]) {
        testWidgets('$name at ${scale}x', (tester) async {
          await pumpFiles(
            tester,
            page,
            platform: _mac,
            size: _tall,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          // The title stays; the subtitle makes room at the largest sizes.
          expect(
            find.textContaining('Choose a folder').evaluate().length +
                find.text('Browse folders').evaluate().length +
                find.text('Type a path').evaluate().length,
            greaterThan(0),
          );
        });
      }
    }
  });

  testWidgets('iOS bars at 3x show the whole Cancel and back label', (
    tester,
  ) async {
    await pumpFiles(tester, _picker(), textScale: 3);
    expect(tester.takeException(), isNull);
    final cancel = find.text('Cancel');
    expect(cancel, findsOneWidget);
    final box = tester.renderObject<RenderBox>(cancel);
    final painted = tester.getSize(cancel);
    expect(painted.width, box.size.width);
    // The leading slot is wide enough for the label it holds.
    expect(tester.getTopLeft(cancel).dx + painted.width, lessThan(390 * 0.55));
    await pumpFiles(tester, _browser('/home/me/code'), textScale: 3);
    expect(tester.takeException(), isNull);
  });

  group('picker keyboard and Mac foot', () {
    testWidgets('Return picks the focused row; Cancel is a real button', (
      tester,
    ) async {
      final picked = <String>[];
      var cancelled = 0;
      await pumpFiles(
        tester,
        _picker(onPick: picked.add, onCancel: () => cancelled++),
        platform: _mac,
        size: _tall,
      );
      final row = find.ancestor(
        of: find.textContaining('bravo', findRichText: true),
        matching: find.byType(InkWell),
      );
      final rowRect = tester.getRect(row.first);
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        if (focus != null && rowRect.contains(focus.rect.center)) break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked, ['b']);
      await tester.tap(find.byKey(const Key('workspace-picker-cancel')));
      expect(cancelled, 1);
    });

    testWidgets('Tab moves through the rows in order', (tester) async {
      await pumpFiles(tester, _picker(), platform: _mac, size: _tall);
      final first = find.ancestor(
        of: find.textContaining('demo', findRichText: true),
        matching: find.byType(InkWell),
      );
      Focus.of(tester.element(first.first)).requestFocus();
      await tester.pump();
      final tops = <double>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus!;
        tops.add(focus.rect.top);
      }
      expect(tops, [...tops]..sort(), reason: 'focus moves down the list');
      expect(tops.toSet().length, 3);
    });

    testWidgets('the search field has a semantic label', (tester) async {
      await pumpFiles(
        tester,
        _picker(
          projects: [
            for (var i = 0; i < 9; i++)
              WorkspacePickerRow(id: '$i', title: 'r$i', path: '/r$i'),
          ],
        ),
      );
      final node = tester.getSemantics(
        find.byKey(const Key('settings-search-field')),
      );
      expect(
        '${node.label} ${node.hint}',
        contains('Search projects and folders'),
      );
    });

    testWidgets(
      'offline rows carry their reason in their name; no empty note',
      (tester) async {
        await pumpFiles(
          tester,
          _picker(offline: true, projects: const []),
          size: _tall,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              r"Type a path\. You're offline\. Browse and Type need your server\.",
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Browse your server or type a path.'),
          findsNothing,
        );
      },
    );
  });

  group('Details', () {
    testWidgets('a chat or profile that is gone cannot be moved', (
      tester,
    ) async {
      for (final phase in [
        WorkspaceMovePhase.chatGone,
        WorkspaceMovePhase.profileGone,
      ]) {
        await pumpFiles(
          tester,
          WorkingDirectoryDetails(
            folderName: 'api',
            path: _demo,
            move: WorkspaceMoveState(phase),
          ),
        );
        expect(find.byKey(const Key('working-directory-change')), findsNothing);
      }
    });

    testWidgets('the disabled button is named with its reason', (tester) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryDetails(
          folderName: 'api',
          path: _demo,
          replying: true,
        ),
      );
      expect(
        find.bySemanticsLabel('Change folder…. Wait for the reply to finish.'),
        findsOneWidget,
      );
    });
  });

  group('Browse', () {
    for (final (level, note) in [
      (FolderBrowserLevel.missing, "This folder doesn't exist on your server."),
      (
        FolderBrowserLevel.outside,
        'This folder is outside what this server lets you browse',
      ),
    ]) {
      testWidgets(
        'a disabled Use says why next to the button (${level.name})',
        (tester) async {
          await pumpFiles(tester, _browser('/home/me/code', level: level));
          final bar = find.ancestor(
            of: find.byKey(const Key('folder-browser-use')),
            matching: find.byType(DecoratedBox),
          );
          expect(
            find.descendant(of: bar.first, matching: find.text(note)),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('"Opening code…" is announced once', (tester) async {
      await pumpFiles(
        tester,
        _browser('/home/me/code', level: FolderBrowserLevel.opening),
      );
      expect(find.bySemanticsLabel('Opening code…'), findsOneWidget);
    });
  });

  group('Type a path', () {
    testWidgets('only the messages are live regions, not the field', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const PathEntryView(text: '/x', check: PathEntryCheck.missing),
      );
      final field = tester.getSemantics(
        find.byKey(const Key('path-entry-field')),
      );
      expect(field.flagsCollection.isLiveRegion, isFalse);
      expect(
        tester
            .getSemantics(
              find.text("This folder doesn't exist on your server."),
            )
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });
  });

  group('Confirmation', () {
    Future<void> open(WidgetTester tester, TargetPlatform platform) async {
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showChangeFolderConfirmation(
              context,
              folderName: 'other',
              path: '/home/me/code/other',
            ),
            child: const Text('open'),
          ),
        ),
        platform: platform,
        size: const Size(700, 900),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets(
        '${platform.name}: Cancel is the bold default, Change folder is plain',
        (tester) async {
          await open(tester, platform);
          final actions = tester
              .widgetList<CupertinoDialogAction>(
                find.byType(CupertinoDialogAction),
              )
              .toList();
          final cancel = actions.firstWhere(
            (a) => (a.child as Text).data == 'Cancel',
          );
          final change = actions.firstWhere(
            (a) => (a.child as Text).data == 'Change folder',
          );
          expect(cancel.isDefaultAction, isTrue);
          expect(change.isDefaultAction, isFalse);
          expect(change.isDestructiveAction, isFalse);
          expect(cancel.isDestructiveAction, isFalse);
        },
      );
    }

    testWidgets('Android: two plain text buttons, Cancel first, none red', (
      tester,
    ) async {
      await open(tester, TargetPlatform.android);
      expect(find.byType(FilledButton), findsNothing);
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .where((b) => b.child is Text && (b.child as Text).data != 'open')
          .toList();
      expect(buttons.map((b) => (b.child as Text).data), [
        'Cancel',
        'Change folder',
      ]);
      for (final b in buttons) {
        expect(b.style?.foregroundColor, isNull);
      }
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Change folder')).dx),
      );
    });
  });

  test('elidePathMiddle keeps the last folder of a Windows path', () {
    const path = r'C:\Users\me\code\demo\analysis-scripts';
    final cut = elidePathMiddle(path, (s) => s.length <= 24);
    expect(cut, contains('…'));
    expect(cut, endsWith('analysis-scripts'));
  });

  test('the suffix never breaks inside', () {
    expect(
      serverPathSuffix('on your server'),
      '·\u00A0on\u00A0your\u00A0server',
    );
  });

  testWidgets('a heading that is a path keeps the heading font', (
    tester,
  ) async {
    await pumpFiles(
      tester,
      const PathCutText('/home/me/code/demo/api', monospace: false),
    );
    final text = tester.widget<Text>(find.byType(Text).first);
    final span = text.textSpan! as TextSpan;
    final first = span.children!.first as TextSpan;
    expect(first.style?.fontFamily, isNot('monospace'));
  });
}
