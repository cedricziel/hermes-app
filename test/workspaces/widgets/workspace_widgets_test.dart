import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/workspaces/widgets/change_folder_confirmation.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_mismatch_notice.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_toolbar_button.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';

import '../../files/widgets/files_widget_harness.dart';

const _demo = '/home/me/code/demo';
const _long =
    '/srv/workspaces/research-group-north/field-campaign-2026/soil-moisture-survey/analysis-scripts-and-notebooks';

Size _size(WidgetTester tester, Finder f) => tester.getSize(f.first);

/// A window tall enough to build every row of the picker.
Future<void> pumpTall(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(500, 2400),
}) => pumpFiles(
  tester,
  child,
  platform: platform,
  locale: locale,
  textScale: textScale,
  size: size,
);

void main() {
  group('ServerPathText', () {
    testWidgets(
      'cuts a long path in the middle, keeps the suffix, long press shows it all',
      (tester) async {
        await pumpFiles(
          tester,
          SizedBox(width: 260, child: ServerPathText.text(_long)),
        );
        final text = tester.widget<Text>(find.byType(Text).first);
        final shown = text.textSpan!.toPlainText();
        expect(shown, contains('…'));
        expect(shown, endsWith(' ${serverPathSuffix('on your server')}'));
        await tester.longPress(find.byType(PathCutText));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(_long), findsOneWidget);
      },
    );

    testWidgets('reads the full path and "on your server" as one label', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        SizedBox(width: 200, child: ServerPathText.text(_long)),
      );
      expect(find.bySemanticsLabel('$_long on your server'), findsOneWidget);
    });

    testWidgets('wraps in full at the largest text size', (tester) async {
      await pumpFiles(
        tester,
        SingleChildScrollView(
          child: SizedBox(width: 300, child: ServerPathText.text(_long)),
        ),
        textScale: 3,
      );
      expect(find.text(_long), findsOneWidget);
      expect(find.text(serverPathSuffix('on your server')), findsOneWidget);
    });

    test('elidePathMiddle keeps the last folder and fits', () {
      final cut = elidePathMiddle(_long, (s) => s.length <= 30);
      expect(cut.length, lessThanOrEqualTo(30));
      expect(cut, contains('…'));
      expect(cut, endsWith('notebooks'));
    });
  });

  group('WorkingDirectoryRow', () {
    testWidgets('server default shows every part and is one 48 pt button', (
      tester,
    ) async {
      var taps = 0;
      await pumpFiles(
        tester,
        WorkingDirectoryRow(
          folderName: 'demo',
          path: _demo,
          branch: 'main',
          serverDefault: true,
          onTap: () => taps++,
        ),
      );
      expect(find.textContaining('Runs in'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      expect(find.text('Server default'), findsOneWidget);
      expect(
        find.textContaining(
          serverPathSuffix('on your server'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Folder: demo, $_demo on your server, branch main, Server default',
        ),
        findsOneWidget,
      );
      expect(
        _size(tester, find.byType(InkWell)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('looking up is not a button and has a spinner', (tester) async {
      await pumpFiles(
        tester,
        WorkingDirectoryRow(
          state: WorkingDirectoryRowState.lookingUp,
          onTap: () => fail('not tappable'),
        ),
      );
      expect(find.text('Looking up your folder…'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('stalled lookup reads the server default and is tappable', (
      tester,
    ) async {
      var taps = 0;
      await pumpFiles(
        tester,
        WorkingDirectoryRow(
          state: WorkingDirectoryRowState.stalled,
          onTap: () => taps++,
        ),
      );
      expect(find.text("Runs in the server's default folder"), findsOneWidget);
      expect(
        find.textContaining(
          serverPathSuffix('on your server'),
          findRichText: true,
        ),
        findsNothing,
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('home folder and offline carry words, not only colour', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryRow(
          folderName: 'me',
          path: '/home/me',
          homeFolder: true,
          offline: true,
        ),
      );
      expect(
        find.text(
          "This is your server's home folder, which holds many projects.",
        ),
        findsOneWidget,
      );
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('German', (tester) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryRow(
          folderName: 'demo',
          path: _demo,
          serverDefault: true,
        ),
        locale: const Locale('de'),
      );
      expect(find.textContaining('Läuft in'), findsOneWidget);
      expect(find.text('Serverstandard'), findsOneWidget);
      expect(
        find.textContaining(
          serverPathSuffix('auf deinem Server'),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Mac row is 36 pt; nothing overflows at 3x', (tester) async {
      await pumpFiles(
        tester,
        WorkingDirectoryRow(
          state: WorkingDirectoryRowState.stalled,
          onTap: () {},
        ),
        platform: TargetPlatform.macOS,
        size: const Size(600, 400),
      );
      expect(_size(tester, find.byType(InkWell)).height, 36);
      await pumpFiles(
        tester,
        const WorkingDirectoryRow(
          folderName: 'api',
          path: _demo,
          branch: 'main',
          projectName: 'Demo',
        ),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WorkingDirectoryLine', () {
    testWidgets('shows folder and branch, is a 44 pt button', (tester) async {
      var taps = 0;
      await pumpFiles(
        tester,
        WorkingDirectoryLine(
          folderName: 'api',
          branch: 'main',
          title: 'Weekly planning',
          onTap: () => taps++,
        ),
      );
      expect(find.text('api · main'), findsOneWidget);
      expect(
        _size(tester, find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        find.bySemanticsLabel('Weekly planning. Folder: api, branch main'),
        findsOneWidget,
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('offline adds a word and the large form is a full-width row', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const WorkingDirectoryLine(folderName: 'api', offline: true),
        textScale: 3,
      );
      expect(find.text('api · Offline'), findsOneWidget);
      expect(tester.getSize(find.byType(InkWell).first).width, 390);
    });
  });

  group('WorkingDirectoryDetails', () {
    Widget details({
      bool replying = false,
      bool offline = false,
      bool canChange = true,
      bool window = false,
      WorkspaceMoveState move = WorkspaceMoveState.idle,
      VoidCallback? onChange,
      VoidCallback? onCheckAgain,
      bool timedOut = false,
    }) => WorkingDirectoryDetails(
      folderName: 'api',
      path: '$_demo/api',
      branch: 'main',
      projectName: 'Demo',
      replying: replying,
      offline: offline,
      canChange: canChange,
      conversationWindow: window,
      move: move,
      moveTarget: '/home/me/code/other',
      moveTimedOut: timedOut,
      onChange: onChange,
      onCheckAgain: onCheckAgain,
      onClose: () {},
    );

    testWidgets('normal: rows, button and footnote', (tester) async {
      var changes = 0;
      await pumpFiles(tester, details(onChange: () => changes++));
      expect(find.text('Working folder'), findsOneWidget);
      for (final label in ['Folder', 'Path', 'Branch', 'Project']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.text('Hermes runs commands and edits files in this folder.'),
        findsOneWidget,
      );
      final button = find.byKey(const Key('working-directory-change'));
      expect(_size(tester, button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      expect(changes, 1);
    });

    for (final (name, replying, offline, reason) in [
      ('replying', true, false, 'Wait for the reply to finish.'),
      ('offline', false, true, "You're offline."),
    ]) {
      testWidgets('$name: disabled with its reason, linked as description', (
        tester,
      ) async {
        await pumpFiles(
          tester,
          details(
            replying: replying,
            offline: offline,
            onChange: () => fail('disabled'),
          ),
        );
        expect(find.text(reason), findsOneWidget);
        final button = find.byKey(const Key('working-directory-change'));
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        // The reason is in the name: a hint never reaches VoiceOver on macOS.
        expect(tester.getSemantics(button).label, contains(reason));
      });
    }

    testWidgets(
      'old server has no button, a conversation window points to the main window',
      (tester) async {
        await pumpFiles(tester, details(canChange: false));
        expect(find.byKey(const Key('working-directory-change')), findsNothing);
        await pumpFiles(tester, details(window: true, canChange: false));
        expect(
          find.text(
            'Hermes runs commands and edits files in this folder. To change it, use the main window.',
          ),
          findsOneWidget,
        );
      },
    );

    for (final (phase, title) in [
      (WorkspaceMovePhase.moving, 'Changing the folder to other…'),
      (WorkspaceMovePhase.checking, "Couldn't change the folder. Checking…"),
      (WorkspaceMovePhase.changed, 'Folder changed to other.'),
      (WorkspaceMovePhase.unchanged, "The folder wasn't changed. Try again."),
      (WorkspaceMovePhase.couldNotConfirm, "Couldn't confirm the change"),
      (
        WorkspaceMovePhase.folderMissing,
        "That folder doesn't exist on your server.",
      ),
      (
        WorkspaceMovePhase.chatGone,
        'This chat no longer exists on your server.',
      ),
      (
        WorkspaceMovePhase.profileGone,
        "This chat's profile no longer exists on your server.",
      ),
    ]) {
      testWidgets('move phase ${phase.name} says "$title"', (tester) async {
        await pumpFiles(
          tester,
          details(
            move: WorkspaceMoveState(phase, folder: '/home/me/code/other'),
          ),
        );
        expect(find.text(title), findsOneWidget);
      });
    }

    testWidgets('in-flight moves disable the button with their reason', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        details(move: const WorkspaceMoveState(WorkspaceMovePhase.moving)),
      );
      expect(find.text('Changing the folder…'), findsOneWidget);
      await pumpFiles(
        tester,
        details(
          move: const WorkspaceMoveState(WorkspaceMovePhase.checking),
          timedOut: true,
        ),
      );
      expect(find.text('Checking the folder…'), findsOneWidget);
      expect(
        find.textContaining("Hermes hasn't answered for 10 seconds"),
        findsOneWidget,
      );
    });

    testWidgets(
      'could not confirm offers Check again, with the button enabled',
      (tester) async {
        var checks = 0;
        await pumpFiles(
          tester,
          details(
            move: const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
            onChange: () {},
            onCheckAgain: () => checks++,
          ),
        );
        await tester.tap(find.text('Check again'));
        expect(checks, 1);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('working-directory-change')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('the full path is shown and selectable on a Mac', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        details(),
        platform: TargetPlatform.macOS,
        size: const Size(600, 700),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.textContaining('$_demo/api'), findsOneWidget);
    });

    testWidgets('German at 3x scrolls without overflow', (tester) async {
      await pumpFiles(
        tester,
        details(
          move: const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
        ),
        locale: const Locale('de'),
        textScale: 3,
      );
      expect(find.text('Arbeitsordner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('WorkspacePickerView', () {
    const def = WorkspacePickerRow(
      id: 'default',
      title: 'demo',
      path: _demo,
      projectName: 'Demo',
    );
    const projects = [
      WorkspacePickerRow(
        id: 'p1',
        title: 'Demo',
        label: 'api',
        path: '$_demo/api',
      ),
    ];
    const recent = [
      WorkspacePickerRow(
        id: 'r1',
        title: 'sandbox',
        path: '/home/me/sandbox',
        chatCount: 12,
      ),
      WorkspacePickerRow(
        id: 'r2',
        title: 'ledger',
        path: '/home/me/ledger',
        isNew: true,
      ),
    ];

    Widget picker({
      List<WorkspacePickerRow> projects = projects,
      List<WorkspacePickerRow> recent = recent,
      WorkspacePickerCatalog catalog = WorkspacePickerCatalog.ready,
      bool offline = false,
      bool locked = false,
      bool scan = false,
      bool scanning = false,
      WorkspacePickerScanOutcome? outcome,
      int found = 0,
      String query = '',
      String selected = 'default',
      ValueChanged<String>? onPick,
      VoidCallback? onBrowse,
    }) => WorkspacePickerView(
      selectedId: selected,
      serverDefault: def,
      projects: projects,
      recent: recent,
      catalog: catalog,
      offline: offline,
      browseLocked: locked,
      scanAvailable: scan,
      scanning: scanning,
      scanOutcome: outcome,
      scanFound: found,
      query: query,
      onPick: onPick,
      onBrowse: onBrowse,
      onType: () {},
    );

    testWidgets('sections, meta and the footer rows', (tester) async {
      await pumpTall(tester, picker());
      expect(find.text('Choose a folder'), findsOneWidget);
      expect(find.text('On your server'), findsOneWidget);
      expect(find.textContaining('Server default · Demo'), findsOneWidget);
      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('SOMEWHERE ELSE'), findsOneWidget);
      expect(find.textContaining('12 chats'), findsOneWidget);
      expect(find.textContaining('New'), findsOneWidget);
      expect(find.text('Browse folders on your server'), findsOneWidget);
      expect(find.text('Type a path'), findsOneWidget);
    });

    testWidgets('a tap on a row picks it; the selected row is checked', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpTall(tester, picker(onPick: picked.add, selected: 'r1'));
      await tester.tap(find.textContaining('ledger', findRichText: true).first);
      expect(picked, ['r2']);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('sandbox')).first),
        isSemantics(isChecked: true),
      );
    });

    testWidgets(
      'search shows only with more than eight rows or a query, and is labelled',
      (tester) async {
        await pumpTall(tester, picker());
        expect(find.byKey(const Key('settings-search-field')), findsNothing);
        final many = [
          for (var i = 0; i < 9; i++)
            WorkspacePickerRow(
              id: 'x$i',
              title: 'repo-$i',
              path: '/home/me/repo-$i',
            ),
        ];
        await pumpTall(tester, picker(recent: many));
        expect(find.byKey(const Key('settings-search-field')), findsOneWidget);
        expect(find.text('Search projects and folders'), findsOneWidget);
      },
    );

    testWidgets('no match names the query and keeps the other sections', (
      tester,
    ) async {
      await pumpTall(
        tester,
        picker(projects: const [], recent: const [], query: 'zzz'),
      );
      expect(find.text('No projects or folders match “zzz”'), findsOneWidget);
      expect(find.textContaining('Server default'), findsOneWidget);
      expect(find.text('Type a path'), findsOneWidget);
    });

    testWidgets('empty, loading, failed and unknown profile', (tester) async {
      await pumpTall(tester, picker(projects: const [], recent: const []));
      expect(
        find.text(
          'No projects or recent folders yet. Browse your server or type a path.',
        ),
        findsOneWidget,
      );
      await pumpTall(tester, picker(catalog: WorkspacePickerCatalog.loading));
      expect(find.bySemanticsLabel('Loading projects…'), findsOneWidget);
      await pumpTall(
        tester,
        picker(catalog: WorkspacePickerCatalog.projectsFailed),
      );
      expect(
        find.textContaining(
          "Couldn't load your projects. You can still browse or type a path.",
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      await pumpTall(
        tester,
        picker(catalog: WorkspacePickerCatalog.unknownProfile),
      );
      expect(
        find.text('This profile no longer exists on your server.'),
        findsOneWidget,
      );
      expect(find.text('Pick another profile for this chat.'), findsOneWidget);
    });

    testWidgets('offline disables Browse and Type with the reason', (
      tester,
    ) async {
      await pumpTall(
        tester,
        picker(offline: true, onBrowse: () => fail('disabled')),
      );
      expect(
        find.text("You're offline. Connect to choose a folder on your server."),
        findsOneWidget,
      );
      expect(
        find.text("You're offline. Browse and Type need your server."),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Browse folders on your server'),
        warnIfMissed: false,
      );
    });

    testWidgets('locked server hides Browse and says why', (tester) async {
      await pumpTall(tester, picker(locked: true));
      expect(find.text('Browse folders on your server'), findsNothing);
      expect(
        find.text(
          'This server only lets you browse its own folders. Choose a project or type a path.',
        ),
        findsOneWidget,
      );
    });

    for (final (outcome, found, text) in [
      (WorkspacePickerScanOutcome.found, 3, 'Found 3 new folders.'),
      (WorkspacePickerScanOutcome.found, 1, 'Found 1 new folder.'),
      (WorkspacePickerScanOutcome.nothingNew, 0, 'No new folders found.'),
      (
        WorkspacePickerScanOutcome.nothingToScan,
        0,
        'No folders to scan. Scan folders are set on the server.',
      ),
      (
        WorkspacePickerScanOutcome.tooSlow,
        0,
        "Couldn't finish looking for projects. Try again.",
      ),
    ]) {
      testWidgets('scan outcome "$text"', (tester) async {
        await pumpTall(
          tester,
          picker(scan: true, outcome: outcome, found: found),
        );
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('scanning shows a busy bar and keeps the list usable', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpTall(tester, picker(scanning: true, onPick: picked.add));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(
        find.textContaining('sandbox', findRichText: true).first,
      );
      expect(picked, ['r1']);
    });

    testWidgets('More menu holds the scan only when the server can scan', (
      tester,
    ) async {
      await pumpTall(tester, picker());
      expect(find.byKey(const Key('workspace-picker-more')), findsNothing);
      await pumpTall(tester, picker(scan: true));
      await tester.tap(find.byKey(const Key('workspace-picker-more')));
      await tester.pumpAndSettle();
      expect(find.text('Look for projects on your server'), findsOneWidget);
    });

    testWidgets(
      'Mac has a Cancel button at the foot; Return picks the focused row',
      (tester) async {
        final picked = <String>[];
        await pumpTall(
          tester,
          picker(onPick: picked.add),
          platform: TargetPlatform.macOS,
          size: const Size(700, 900),
        );
        final cancel = find.byKey(const Key('workspace-picker-cancel'));
        expect(cancel, findsOneWidget);
        expect(_size(tester, cancel).height, greaterThanOrEqualTo(28));
        final row = find.textContaining('ledger', findRichText: true).first;
        Focus.of(tester.element(row)).requestFocus();
        await tester.tap(row);
        expect(picked, ['r2']);
      },
    );

    testWidgets('German; no overlapping rows at 3x', (tester) async {
      await pumpTall(
        tester,
        picker(scan: true, outcome: WorkspacePickerScanOutcome.found, found: 1),
        locale: const Locale('de'),
        textScale: 3,
      );
      expect(find.text('Ordner wählen'), findsOneWidget);
      expect(find.text('1 neuer Ordner gefunden.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final rows = [
        for (final e in find.byType(GroupedRow).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].top, greaterThanOrEqualTo(rows[i - 1].bottom - 1));
      }
    });
  });

  group('FolderBrowserView', () {
    ServerPath p(String t) => ServerPath.tryParse(t)!;
    final rows = [
      FileRowModel(name: 'demo', isFolder: true, path: p('/home/me/code/demo')),
      FileRowModel(
        name: 'notes.txt',
        isFolder: false,
        path: p('/home/me/code/notes.txt'),
      ),
    ];

    Widget browser(
      String path, {
      FolderBrowserLevel level = FolderBrowserLevel.ready,
      List<FileRowModel>? list,
      ValueChanged<ServerPath>? onOpenPath,
      VoidCallback? onUse,
      VoidCallback? onUp,
    }) => FolderBrowserView(
      current: p(path),
      level: level,
      rows: list ?? rows,
      onOpenPath: onOpenPath,
      onUse: onUse ?? () {},
      onUp: onUp,
    );

    testWidgets('folders only, Up with the parent, Use names the folder', (
      tester,
    ) async {
      var ups = 0;
      var uses = 0;
      await pumpFiles(
        tester,
        browser('/home/me/code', onUp: () => ups++, onUse: () => uses++),
      );
      expect(find.text('Browse folders'), findsOneWidget);
      expect(find.text('demo'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
      expect(find.text('Back up one folder'), findsOneWidget);
      expect(find.text('me'), findsWidgets);
      await tester.tap(find.byKey(const Key('folder-browser-up')));
      expect(ups, 1);
      await tester.tap(find.text('Use “code”'));
      expect(uses, 1);
    });

    testWidgets(
      'breadcrumb segments are buttons labelled with their full path',
      (tester) async {
        final opened = <String>[];
        await pumpFiles(
          tester,
          browser('/home/me/code', onOpenPath: (s) => opened.add(s.value)),
        );
        expect(
          find.bySemanticsLabel('/home/me, folder, go to'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'me'));
        expect(opened, ['/home/me']);
      },
    );

    testWidgets('the root has no Up row', (tester) async {
      await pumpFiles(tester, browser('/', list: const []));
      expect(find.text('Back up one folder'), findsNothing);
      expect(find.text('No folders here.'), findsOneWidget);
      expect(find.text('Use “/”'), findsOneWidget);
    });

    for (final (level, title, enabled) in [
      (FolderBrowserLevel.notAllowed, "Couldn't open this folder", true),
      (
        FolderBrowserLevel.outside,
        'This folder is outside what this server lets you browse',
        false,
      ),
      (
        FolderBrowserLevel.missing,
        "This folder doesn't exist on your server.",
        false,
      ),
      (FolderBrowserLevel.unreachable, "Couldn't open this folder.", true),
      (FolderBrowserLevel.opening, 'Opening code…', true),
    ]) {
      testWidgets(
        '${level.name}: "$title", Use ${enabled ? 'enabled' : 'disabled'}',
        (tester) async {
          await pumpFiles(tester, browser('/home/me/code', level: level));
          expect(find.text(title), findsWidgets);
          final use = tester.widget<FilledButton>(
            find.byKey(const Key('folder-browser-use')),
          );
          expect(use.onPressed != null, enabled);
          if (level == FolderBrowserLevel.notAllowed) {
            expect(
              find.text('Hermes may not be able to work here.'),
              findsOneWidget,
            );
          }
          if (level == FolderBrowserLevel.unreachable) {
            expect(find.text('Try again'), findsOneWidget);
          }
        },
      );
    }

    testWidgets(
      'Use is at least 44 pt, 28 pt on a Mac, and nothing overlaps at 3x',
      (tester) async {
        await pumpFiles(tester, browser('/home/me/code'));
        expect(
          _size(tester, find.byKey(const Key('folder-browser-use'))).height,
          greaterThanOrEqualTo(44),
        );
        await pumpFiles(
          tester,
          browser('/home/me/code'),
          platform: TargetPlatform.macOS,
          size: const Size(700, 700),
        );
        expect(
          _size(tester, find.byKey(const Key('folder-browser-use'))).height,
          greaterThanOrEqualTo(28),
        );
        await pumpFiles(tester, browser('/home/me/code'), textScale: 3);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PathEntryView', () {
    Widget entry(
      String text, {
      PathEntryCheck check = PathEntryCheck.idle,
      List<PathEntrySuggestion> suggestions = const [],
      bool capped = false,
      VoidCallback? onUse,
      ValueChanged<PathEntrySuggestion>? onPick,
      VoidCallback? onCheckAgain,
    }) => PathEntryView(
      text: text,
      check: check,
      suggestions: suggestions,
      capped: capped,
      onUse: onUse ?? () {},
      onPickSuggestion: onPick,
      onCheckAgain: onCheckAgain,
      onChanged: (_) {},
    );

    for (final (check, message, enabled) in [
      (PathEntryCheck.relative, 'Start with / or ~', false),
      (PathEntryCheck.checking, 'Checking…', false),
      (
        PathEntryCheck.missing,
        "This folder doesn't exist on your server.",
        false,
      ),
      (PathEntryCheck.tooSlow, "Couldn't check this folder.", false),
      (PathEntryCheck.found, 'Folder found.', true),
      (
        PathEntryCheck.notAllowed,
        "Hermes isn't allowed to read this folder.",
        true,
      ),
      (
        PathEntryCheck.cannotCheck,
        "This server doesn't let the app check folders. If Hermes starts somewhere else, the chat says so.",
        true,
      ),
    ]) {
      testWidgets(
        '${check.name}: "$message", Use ${enabled ? 'enabled' : 'disabled'}',
        (tester) async {
          await pumpFiles(tester, entry('/home/me/code/demo', check: check));
          expect(find.text(message), findsOneWidget);
          final use = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use this folder'),
          );
          expect(use.onPressed != null, enabled);
          if (check == PathEntryCheck.notAllowed) {
            expect(
              find.text('Hermes may not be able to work here.'),
              findsOneWidget,
            );
          }
          if (check == PathEntryCheck.tooSlow) {
            expect(find.text('Check again'), findsOneWidget);
          }
        },
      );
    }

    testWidgets('the field is labelled, monospace and has a URL keyboard', (
      tester,
    ) async {
      await pumpFiles(tester, entry(''));
      final field = tester.widget<TextField>(
        find.byKey(const Key('path-entry-field')),
      );
      expect(field.keyboardType, TextInputType.url);
      expect(field.autocorrect, isFalse);
      expect(field.decoration!.labelText, 'Folder on your server');
      expect(field.decoration!.hintText, '/home/you/code/project');
      expect(field.style!.fontFamily, 'monospace');
    });

    testWidgets('suggestions fill the field; thirty items say keep typing', (
      tester,
    ) async {
      final picked = <String>[];
      await pumpFiles(
        tester,
        entry(
          '/home/me/code/',
          capped: true,
          suggestions: const [
            PathEntrySuggestion(name: 'demo', path: '/home/me/code/demo/'),
          ],
          onPick: (s) => picked.add(s.path),
        ),
      );
      expect(find.text('Keep typing to narrow the list.'), findsOneWidget);
      await tester.tap(find.text('demo'));
      expect(picked, ['/home/me/code/demo/']);
    });

    testWidgets(
      'thirty items with no folder show only the hint; no suggestions say so',
      (tester) async {
        await pumpFiles(tester, entry('/home/me/code/', capped: true));
        expect(find.text('Keep typing to narrow the list.'), findsOneWidget);
        expect(find.text('No folders start with this.'), findsNothing);
        await pumpFiles(tester, entry('/home/me/code/zz'));
        expect(find.text('No folders start with this.'), findsOneWidget);
      },
    );

    testWidgets(
      'Return in the field uses the folder only when it can be used',
      (tester) async {
        var uses = 0;
        await pumpFiles(
          tester,
          entry(
            '/home/me/code/demo',
            check: PathEntryCheck.missing,
            onUse: () => uses++,
          ),
        );
        await tester.tap(find.byKey(const Key('path-entry-field')));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(uses, 0);
        await pumpFiles(
          tester,
          entry(
            '/home/me/code/demo',
            check: PathEntryCheck.found,
            onUse: () => uses++,
          ),
        );
        await tester.tap(find.byKey(const Key('path-entry-field')));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(uses, 1);
      },
    );

    testWidgets('German at 3x does not overflow', (tester) async {
      await pumpFiles(
        tester,
        entry('/home/me/private', check: PathEntryCheck.notAllowed),
        locale: const Locale('de'),
        textScale: 3,
      );
      expect(find.text('Pfad eingeben'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FolderMismatchNotice', () {
    testWidgets(
      'words, warning glyph and one action; the profile clause only after a retry',
      (tester) async {
        var taps = 0;
        await pumpFiles(
          tester,
          FolderMismatchNotice(
            startedIn: 'me',
            picked: 'other',
            onChoose: () => taps++,
          ),
        );
        expect(
          find.textContaining('Hermes started in me instead of other.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('The folder may not exist on your server.'),
          findsOneWidget,
        );
        expect(find.textContaining('use its own folder'), findsNothing);
        expect(find.byType(AppIcon), findsWidgets);
        expect(
          _size(tester, find.byKey(const Key('folder-mismatch-choose'))).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.text('Choose another folder'));
        expect(taps, 1);
        await pumpFiles(
          tester,
          const FolderMismatchNotice(
            startedIn: 'me',
            picked: 'other',
            profileMayUseOwnFolder: true,
          ),
        );
        expect(
          find.textContaining('or this profile may use its own folder.'),
          findsOneWidget,
        );
      },
    );
  });

  group('FolderToolbarButton', () {
    testWidgets('28 pt, labelled with the full path, tooltip shows it', (
      tester,
    ) async {
      var taps = 0;
      await pumpFiles(
        tester,
        FolderToolbarButton(
          folderName: 'demo',
          path: _demo,
          branch: 'main',
          onPressed: () => taps++,
        ),
        platform: TargetPlatform.macOS,
        size: const Size(600, 200),
      );
      final button = find.byKey(const Key('folder-toolbar-button'));
      expect(_size(tester, button).height, greaterThanOrEqualTo(28));
      expect(
        find.bySemanticsLabel(
          'Folder: demo, $_demo on your server, branch main',
        ),
        findsOneWidget,
      );
      await tester.tap(button);
      expect(taps, 1);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(button));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('$_demo on your server'), findsWidgets);
    });

    testWidgets('disabled is not tappable and still names the folder', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const FolderToolbarButton(folderName: 'demo', path: _demo),
        platform: TargetPlatform.macOS,
      );
      expect(find.text('demo'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('folder-toolbar-button')))
            .onPressed,
        isNull,
      );
    });
  });

  group('ChangeFolderConfirmation', () {
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

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      testWidgets(
        '${platform.name}: the whole text, Cancel first, nothing filled or red',
        (tester) async {
          await open(tester, platform);
          expect(find.text('Change the folder for this chat?'), findsOneWidget);
          expect(
            find.textContaining(
              'Hermes will read files, edit them and run commands in other for new messages. '
              'Nothing is moved or deleted. Files already written stay where they are.',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('/home/me/code/other · on your server'),
            findsOneWidget,
          );
          expect(find.text('Cancel'), findsOneWidget);
          expect(find.text('Change folder'), findsOneWidget);
          expect(find.byType(FilledButton), findsNothing);
          final cancelAt = tester.getTopLeft(find.text('Cancel'));
          final changeAt = tester.getTopLeft(find.text('Change folder'));
          expect(
            platform == TargetPlatform.android
                ? cancelAt.dx < changeAt.dx
                : cancelAt.dy < changeAt.dy || cancelAt.dx < changeAt.dx,
            isTrue,
          );
        },
      );
    }

    testWidgets('Cancel resolves false and Change folder true', (tester) async {
      bool? result;
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showChangeFolderConfirmation(
              context,
              folderName: 'other',
              path: '/home/me/code/other',
            ),
            child: const Text('open'),
          ),
        ),
        platform: TargetPlatform.android,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change folder'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Escape dismisses without confirming', (tester) async {
      bool? result;
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showChangeFolderConfirmation(
              context,
              folderName: 'other',
              path: '/home/me/code/other',
            ),
            child: const Text('open'),
          ),
        ),
        platform: TargetPlatform.android,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
