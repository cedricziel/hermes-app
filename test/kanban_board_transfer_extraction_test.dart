import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';
import 'support/test_localizations.dart';

/// What a user sees and can do in the Kanban board Export and Import dialogs
/// the Boards screen opens: their texts, the actions' semantics, each option
/// control's value and whether it is enabled, and what each dialog answers.
/// Each case drives the real screen (or the opener the screen calls) and
/// asserts the app's own output only.

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  theme: buildHermesLightTheme(),
  builder: (_, child) => AppThemeScopes(child: child!),
  home: home,
);

List<String> _texts(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(GroupedDialog),
      matching: find.byType(Text),
    ),
  ))
    w.data ?? w.textSpan?.toPlainText() ?? '',
];

/// The label, button flag, tap action and kind of the dialog button [label].
String _action(WidgetTester tester, Type kind, String label) {
  final finder = find.descendant(
    of: find.byType(GroupedDialog),
    matching: find.widgetWithText(
      kind == FilledButton ? FilledButton : TextButton,
      label,
    ),
  );
  final node = tester.getSemantics(finder);
  final data = node.getSemanticsData();
  return '${node.label}|$kind|button=${data.flagsCollection.isButton}'
      '|tap=${data.hasAction(SemanticsAction.tap)}';
}

/// The switch rows of the open dialog as `title=value/enabled`.
List<String> _switches(WidgetTester tester) => [
  for (final row in tester.widgetList<GroupedSwitchRow>(
    find.byType(GroupedSwitchRow),
  ))
    '${row.title}=${row.value}/${row.onChanged != null}',
];

void main() {
  group('on the Boards screen', () {
    late FakeHermesServer server;
    late KanbanBoardController controller;

    Future<void> openBoards(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      server = FakeHermesServer()
        ..on(
          'GET',
          '/api/plugins/kanban/boards',
          kanbanBoardsBody([
            (slug: 'ops', name: 'Ops', total: 1, current: true),
          ]),
        )
        ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]));
      controller = KanbanBoardController(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      );
      await tester.runAsync(controller.start);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => KanbanBoardsScreen(
                      controller: controller,
                      repository: KanbanRepository(server.client()),
                    ),
                  ),
                ),
                child: const Text('open boards'),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.text('open boards'));
      await tester.pumpAndSettle();
    }

    Future<void> openExport(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<RowAction>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();
    }

    Future<void> openImport(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Import a board'));
      await tester.pumpAndSettle();
    }

    testWidgets('Export names the board and lists its options', (tester) async {
      final handle = tester.ensureSemantics();
      await openBoards(tester);
      await openExport(tester);

      expect(_texts(tester), [
        'Export Ops',
        'Server path',
        'Use export folder',
        'The archive is written on the server, not on this device. '
            'Empty uses the server’s export folder.',
        'Include attachments',
        'Include worker logs',
        'Cancel',
        'Export',
      ]);
      expect(_switches(tester), [
        'Include attachments=true/true',
        'Include worker logs=false/true',
      ]);
      expect(
        _action(tester, TextButton, 'Cancel'),
        'Cancel|TextButton|button=true|tap=true',
      );
      expect(
        _action(tester, FilledButton, 'Export'),
        'Export|FilledButton|button=true|tap=true',
      );
      handle.dispose();
    });

    testWidgets('Export is German on a German device', (tester) async {
      await openBoards(tester, locale: const Locale('de'));
      await tester.tap(find.byType(PopupMenuButton<RowAction>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();

      expect(_texts(tester), [
        'Ops exportieren',
        'Server-Pfad',
        'Export-Ordner verwenden',
        'Das Archiv wird auf dem Server geschrieben, nicht auf diesem Gerät. '
            'Bleibt es leer, wird der Export-Ordner des Servers verwendet.',
        'Anhänge einbeziehen',
        'Worker-Logs einbeziehen',
        'Abbrechen',
        'Exportieren',
      ]);
    });

    testWidgets('Import lists its options and starts with Import off', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openBoards(tester);
      await openImport(tester);

      expect(_texts(tester), [
        'Import a board',
        'Archive path',
        'New board slug',
        'Optional',
        'The archive must already be on the server.',
        'Open it afterwards',
        'Cancel',
        'Import',
      ]);
      expect(_switches(tester), ['Open it afterwards=true/true']);
      expect(
        _action(tester, TextButton, 'Cancel'),
        'Cancel|TextButton|button=true|tap=true',
      );
      // An unset archive path leaves Import without a tap action.
      expect(
        _action(tester, FilledButton, 'Import'),
        'Import|FilledButton|button=true|tap=false',
      );

      // Blank spaces do not count as a path.
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(
        _action(tester, FilledButton, 'Import'),
        'Import|FilledButton|button=true|tap=false',
      );
      await tester.enterText(find.byType(TextField).first, '/a.tar.gz');
      await tester.pump();
      expect(
        _action(tester, FilledButton, 'Import'),
        'Import|FilledButton|button=true|tap=true',
      );
      handle.dispose();
    });

    testWidgets('Import is German on a German device', (tester) async {
      await openBoards(tester, locale: const Locale('de'));
      await tester.tap(find.byTooltip('Import a board'));
      await tester.pumpAndSettle();

      expect(_texts(tester), [
        'Board importieren',
        'Archivpfad',
        'Neuer Board-Slug',
        'Optional',
        'Das Archiv muss bereits auf dem Server liegen.',
        'Danach öffnen',
        'Abbrechen',
        'Importieren',
      ]);
    });

    testWidgets('a switch row flips its value and keeps the other', (
      tester,
    ) async {
      await openBoards(tester);
      await openExport(tester);

      await tester.tap(find.text('Include attachments'));
      await tester.pump();
      expect(_switches(tester), [
        'Include attachments=false/true',
        'Include worker logs=false/true',
      ]);
      await tester.tap(find.text('Include worker logs'));
      await tester.pump();
      expect(_switches(tester), [
        'Include attachments=false/true',
        'Include worker logs=true/true',
      ]);
    });
  });

  group('what the dialogs answer', () {
    late BuildContext context;

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    testWidgets('Export answers the default options', (tester) async {
      await pump(tester);
      KanbanExportOptions? answer;
      var done = false;
      unawaited(
        showKanbanExportDialog(context, name: 'Ops').then((o) {
          answer = o;
          done = true;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(answer, (output: '', attachments: true, logs: false));
    });

    testWidgets('Export answers a typed path and the chosen toggles', (
      tester,
    ) async {
      await pump(tester);
      KanbanExportOptions? answer;
      unawaited(
        showKanbanExportDialog(context, name: 'Ops').then((o) => answer = o),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  /srv/x.tar.gz ');
      await tester.tap(find.text('Include attachments'));
      await tester.tap(find.text('Include worker logs'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      expect(answer, (output: '/srv/x.tar.gz', attachments: false, logs: true));
    });

    testWidgets('Export answers null on Cancel, whatever was chosen', (
      tester,
    ) async {
      await pump(tester);
      KanbanExportOptions? answer = (
        output: 'x',
        attachments: true,
        logs: true,
      );
      var done = false;
      unawaited(
        showKanbanExportDialog(context, name: 'Ops').then((o) {
          answer = o;
          done = true;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include worker logs'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(answer, isNull);
    });

    testWidgets('Import answers the archive with the default switch', (
      tester,
    ) async {
      await pump(tester);
      KanbanImportOptions? answer;
      unawaited(showKanbanImportDialog(context).then((o) => answer = o));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, ' /a.tar.gz ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(answer, (archive: '/a.tar.gz', slug: '', open: true));
    });

    testWidgets('Import answers a slug and the open switch turned off', (
      tester,
    ) async {
      await pump(tester);
      KanbanImportOptions? answer;
      unawaited(showKanbanImportDialog(context).then((o) => answer = o));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '/a.tar.gz');
      await tester.enterText(find.byType(TextField).last, ' restored ');
      await tester.tap(find.text('Open it afterwards'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(answer, (archive: '/a.tar.gz', slug: 'restored', open: false));
    });

    testWidgets('Import answers null on Cancel', (tester) async {
      await pump(tester);
      KanbanImportOptions? answer = (archive: 'x', slug: '', open: true);
      var done = false;
      unawaited(
        showKanbanImportDialog(context).then((o) {
          answer = o;
          done = true;
        }),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '/a.tar.gz');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(answer, isNull);
    });
  });
}
