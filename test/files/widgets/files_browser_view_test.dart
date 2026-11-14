import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_problems.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/files_browser_view.dart';
import 'package:hermes_app/src/files/widgets/files_failures.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/files/widgets/files_page_menu.dart';

import 'files_widget_harness.dart';

final _rows = [
  FileRowModel(
    name: 'reports',
    isFolder: true,
    path: serverPath('/srv/demo/field-notes/reports'),
  ),
  FileRowModel(
    name: 'notes.txt',
    isFolder: false,
    path: serverPath('/srv/demo/field-notes/notes.txt'),
  ),
  FileRowModel(
    name: '.env',
    isFolder: false,
    looksSecret: true,
    path: serverPath('/srv/demo/field-notes/.env'),
  ),
];

class _Calls {
  final taps = <String>[];
  var tryAgain = 0;
  var refresh = 0;
  var showHidden = 0;
  var up = 0;
  var goBack = 0;

  Widget view(FolderViewState state, {ServerPath? selected}) =>
      FilesBrowserView(
        state: state,
        selected: selected,
        onOpen: (row) => taps.add(row.name),
        onTryAgain: () => tryAgain++,
        onRefresh: () => refresh++,
        onShowHidden: () => showHidden++,
        onUp: () => up++,
        onGoBack: () => goBack++,
      );
}

void main() {
  group('FilesBrowserView', () {
    testWidgets('lists folders and files, and a tap opens the row', (
      tester,
    ) async {
      final calls = _Calls();
      await pumpFiles(tester, calls.view(FolderViewReady(rows: _rows)));

      expect(find.text('reports'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('May contain secrets'), findsOneWidget);
      await tester.tap(find.text('notes.txt'));
      expect(calls.taps, ['notes.txt']);
    });

    testWidgets('loading shows the label and eight still skeleton rows', (
      tester,
    ) async {
      await pumpFiles(tester, _Calls().view(const FolderViewLoading()));

      expect(find.text('Loading folder…'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading folder…'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Nothing pulses: only the spinner animates.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('loading holds the spinner still under reduced motion', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _Calls().view(const FolderViewLoading()),
        reduceMotion: true,
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.value, isNotNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('an empty folder says so and offers Refresh', (tester) async {
      final calls = _Calls();
      await pumpFiles(tester, calls.view(const FolderViewReady()));

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
        find.text('Files the agent writes in this folder appear here.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Refresh'));
      expect(calls.refresh, 1);
      expect(calls.showHidden, 0);
    });

    testWidgets('an empty folder with hidden files offers to show them', (
      tester,
    ) async {
      final calls = _Calls();
      await pumpFiles(
        tester,
        calls.view(const FolderViewReady(hasHiddenFiles: true)),
      );

      expect(
        find.text(
          'Files the agent writes in this folder appear here. Hidden files are not shown.',
        ),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsNothing);
      await tester.tap(find.text('Show hidden files'));
      expect(calls.showHidden, 1);
    });

    testWidgets('a capped list says how many of how many are shown', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _Calls().view(FolderViewReady(rows: _rows, totalCount: 5310)),
      );

      expect(find.text('Showing the first 3 of 5,310.'), findsOneWidget);
    });

    testWidgets('the footer follows the locale', (tester) async {
      await pumpFiles(
        tester,
        _Calls().view(FolderViewReady(rows: _rows, totalCount: 5310)),
        locale: const Locale('de'),
      );

      expect(
        find.text('Die ersten 3 von 5.310 werden angezeigt.'),
        findsOneWidget,
      );
    });

    testWidgets('a complete list has no footer', (tester) async {
      await pumpFiles(
        tester,
        _Calls().view(FolderViewReady(rows: _rows, totalCount: 3)),
      );

      expect(find.textContaining('Showing the first'), findsNothing);
    });

    testWidgets("the server's folder gets the neutral note", (tester) async {
      await pumpFiles(
        tester,
        _Calls().view(FolderViewReady(rows: _rows, showServerFolderNote: true)),
      );

      expect(find.text('Working folder of the server'), findsOneWidget);
      expect(
        find.textContaining("so Hermes shows the server's own folder"),
        findsOneWidget,
      );
      expect(find.byType(FilesServerFolderNote), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the list under a warning', (
      tester,
    ) async {
      final calls = _Calls();
      await pumpFiles(
        tester,
        calls.view(FolderViewReady(rows: _rows, stale: true)),
      );

      expect(find.text("Can't reach your Hermes server."), findsOneWidget);
      expect(find.text('This list may be out of date.'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(calls.tryAgain, 1);
    });

    testWidgets('the selected row is announced as selected', (tester) async {
      await pumpFiles(
        tester,
        _Calls().view(
          FolderViewReady(rows: _rows),
          selected: serverPath('/srv/demo/field-notes/notes.txt'),
        ),
      );

      expect(
        tester.getSemantics(find.widgetWithText(FileRow, 'notes.txt')),
        isA<SemanticsNode>().having(
          (n) => n.flagsCollection.isSelected,
          'selected',
          Tristate.isTrue,
        ),
      );
      expect(
        tester.getSemantics(find.widgetWithText(FileRow, 'reports')),
        isA<SemanticsNode>().having(
          (n) => n.flagsCollection.isSelected,
          'selected',
          Tristate.isFalse,
        ),
      );
    });

    group('folder problems', () {
      Future<_Calls> show(
        WidgetTester tester,
        FolderProblem problem, {
        bool atHighest = false,
        Locale locale = const Locale('en'),
      }) async {
        final calls = _Calls();
        await pumpFiles(
          tester,
          calls.view(FolderViewProblem(problem, atHighest: atHighest)),
          locale: locale,
        );
        return calls;
      }

      testWidgets('unreachable offers Try again', (tester) async {
        final calls = await show(tester, FolderProblem.unreachable);

        expect(find.text("Can't reach your Hermes server."), findsOneWidget);
        await tester.tap(find.text('Try again'));
        expect(calls.tryAgain, 1);
      });

      testWidgets('a gone folder offers Up', (tester) async {
        final calls = await show(tester, FolderProblem.gone);

        expect(find.text('This folder no longer exists.'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        await tester.tap(find.text('Up'));
        expect(calls.up, 1);
      });

      testWidgets('a gone folder at the highest folder offers Try again', (
        tester,
      ) async {
        final calls = await show(tester, FolderProblem.gone, atHighest: true);

        expect(find.text('Up'), findsNothing);
        await tester.tap(find.text('Try again'));
        expect(calls.tryAgain, 1);
      });

      testWidgets('no permission offers Up, and nothing at the top', (
        tester,
      ) async {
        await show(tester, FolderProblem.noPermission);
        expect(find.text("Hermes can't read this folder."), findsOneWidget);
        expect(find.text('Up'), findsOneWidget);

        await show(tester, FolderProblem.noPermission, atHighest: true);
        expect(find.text('Up'), findsNothing);
      });

      testWidgets('a fixed-folder server has no action', (tester) async {
        await show(tester, FolderProblem.fixedFolder);

        expect(
          find.text(
            'Hermes only shares files from a fixed folder on this server.',
          ),
          findsOneWidget,
        );
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('a down workspace offers Try again', (tester) async {
        final calls = await show(tester, FolderProblem.workspaceDown);

        expect(
          find.text("Can't reach this profile's workspace."),
          findsOneWidget,
        );
        await tester.tap(find.text('Try again'));
        expect(calls.tryAgain, 1);
      });

      testWidgets('a link outside the folder offers Go back', (tester) async {
        final calls = await show(tester, FolderProblem.outside);

        expect(
          find.text("This folder is outside this chat's folder."),
          findsOneWidget,
        );
        await tester.tap(find.text('Go back'));
        expect(calls.goBack, 1);
      });

      testWidgets('a rejected folder says what happened and has no action', (
        tester,
      ) async {
        await show(tester, FolderProblem.notAccepted);

        expect(find.text("Hermes can't open this folder."), findsOneWidget);
        expect(
          find.text(
            "The server didn't accept this folder or this chat's profile.",
          ),
          findsOneWidget,
        );
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('every problem has an icon as well as words', (tester) async {
        for (final problem in FolderProblem.values) {
          await show(tester, problem);
          expect(find.byType(Icon), findsWidgets, reason: problem.name);
        }
      });

      testWidgets('the words are German in German', (tester) async {
        await show(tester, FolderProblem.gone, locale: const Locale('de'));

        expect(
          find.text('Dieser Ordner existiert nicht mehr.'),
          findsOneWidget,
        );
        expect(find.text('Nach oben'), findsOneWidget);
      });

      testWidgets('a failure is a live region', (tester) async {
        await show(tester, FolderProblem.unreachable);

        expect(
          tester.getSemantics(find.text("Can't reach your Hermes server.")),
          isNotNull,
        );
        expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsWidgets);
      });

      testWidgets(
        'at the largest text a failure scrolls instead of overflowing',
        (tester) async {
          await pumpFiles(
            tester,
            _Calls().view(const FolderViewProblem(FolderProblem.notAccepted)),
            textScale: 3,
          );

          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets('the empty preview pane says what to do', (tester) async {
      await pumpFiles(tester, const FilesNoSelection());

      expect(find.text('Select a file to preview it.'), findsOneWidget);
    });
  });

  group('problem mapping', () {
    test('a folder failure maps to its problem', () {
      expect(folderProblemFor(FilesFailure.missing), FolderProblem.gone);
      expect(
        folderProblemFor(FilesFailure.notAllowed),
        FolderProblem.noPermission,
      );
      expect(
        folderProblemFor(FilesFailure.notAllowed, lockedDeployment: true),
        FolderProblem.fixedFolder,
      );
      expect(
        folderProblemFor(FilesFailure.workspaceDown),
        FolderProblem.workspaceDown,
      );
      expect(folderProblemFor(FilesFailure.outside), FolderProblem.outside);
      expect(
        folderProblemFor(FilesFailure.badRequest),
        FolderProblem.notAccepted,
      );
      expect(
        folderProblemFor(FilesFailure.unreachable),
        FolderProblem.unreachable,
      );
      expect(
        folderProblemFor(FilesFailure.unreadable),
        FolderProblem.unreachable,
      );
    });

    test('a file failure maps to its problem', () {
      expect(fileProblemFor(FilesFailure.notAllowed), FileProblem.notShared);
      expect(fileProblemFor(FilesFailure.missing), FileProblem.gone);
      expect(fileProblemFor(FilesFailure.busy), FileProblem.busy);
      expect(fileProblemFor(FilesFailure.notAFile), FileProblem.notAFile);
      expect(fileProblemFor(FilesFailure.unreadable), FileProblem.couldntOpen);
      expect(fileProblemFor(FilesFailure.badRequest), FileProblem.couldntOpen);
    });
  });

  group('page menu', () {
    testWidgets('lists the full path, then the actions in the fixed order', (
      tester,
    ) async {
      final chosen = <FilesMenuChoice>[];
      await pumpFiles(
        tester,
        Align(
          alignment: Alignment.topRight,
          child: FilesPageMenuButton(
            path: serverPath('/srv/demo/field-notes'),
            showHidden: true,
            onSelected: chosen.add,
          ),
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.byType(PopupMenuButton<FilesMenuChoice>));
      await tester.pumpAndSettle();

      final texts = [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is PopupMenuItem<FilesMenuChoice>,
            ),
            matching: find.byType(Text),
          ),
        ))
          text.data,
      ];
      expect(texts, [
        '/srv/demo/field-notes',
        'Copy path',
        'Show hidden files',
        'Refresh',
        'About this list',
      ]);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      expect(
        find.bySemanticsLabel('Full path: /srv/demo/field-notes'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.done), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(chosen, [FilesMenuChoice.refresh]);
    });

    testWidgets('the path row is information, not a button', (tester) async {
      await pumpFiles(
        tester,
        Align(
          alignment: Alignment.topRight,
          child: FilesPageMenuButton(
            path: serverPath('/srv/demo/field-notes'),
            showHidden: false,
            onSelected: (_) {},
          ),
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.byType(PopupMenuButton<FilesMenuChoice>));
      await tester.pumpAndSettle();

      final first = tester.widget<PopupMenuItem<FilesMenuChoice>>(
        find.byType(PopupMenuItem<FilesMenuChoice>).first,
      );
      expect(first.enabled, isFalse);
      expect(find.byIcon(Icons.done), findsNothing);
    });

    testWidgets('About this list is an alert with OK', (tester) async {
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFilesAboutList(context),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('About this list'), findsOneWidget);
      expect(find.textContaining('config.yaml'), findsOneWidget);
      expect(
        find.textContaining('Show hidden files shows names'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('About this list'), findsNothing);
    });
  });
}
