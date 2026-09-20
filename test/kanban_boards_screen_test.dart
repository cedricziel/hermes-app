import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late KanbanBoardController controller;

  setUp(() async {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 3, current: true),
          (slug: 'ops', name: 'Ops', total: 1, current: false),
        ]),
      )
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]));
    controller = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
    );
    await controller.start();
  });

  tearDown(() => controller.dispose());

  /// The boards list opened from another page, as in the app, so leaving it
  /// has somewhere to go.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Builder(
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
      ),
    );
    await tester.tap(find.text('open boards'));
    await tester.pumpAndSettle();
  }

  test('derives a slug the plugin accepts from a name', () {
    expect(KanbanBoardsScreen.slugFor('  Ops team! '), 'ops-team');
    expect(KanbanBoardsScreen.slugFor('Q3 / Launch'), 'q3-launch');
  });

  testWidgets('lists the boards with their task counts', (tester) async {
    await pump(tester);

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('default · 3 tasks'), findsOneWidget);
    expect(find.text('ops · 1 tasks'), findsOneWidget);
  });

  testWidgets('creates a board from its name', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards', {'board': {}});
    await pump(tester);

    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Q3 Launch');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('POST', '/api/plugins/kanban/boards').single,
    ) as Map;
    expect(body['slug'], 'q3-launch');
    expect(body['name'], 'Q3 Launch');
  });

  testWidgets('will not send a name that leaves no slug', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '日本語');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '/api/plugins/kanban/boards'), isEmpty);
    expect(
      find.text('Use letters or numbers in the board name.'),
      findsOneWidget,
    );
  });

  testWidgets('says why the plugin refused a board', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards', {
      'detail': 'invalid board slug',
    }, status: 400);
    await pump(tester);

    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ops');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('invalid board slug'), findsOneWidget);
  });

  testWidgets('archives a board after confirming', (tester) async {
    server.on('DELETE', '/api/plugins/kanban/boards/ops', {'result': {}});
    await pump(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    final delete = server
        .requestsTo('DELETE', '/api/plugins/kanban/boards/ops')
        .single;
    expect(delete.queryParameters['delete'], false);
  });

  testWidgets('picking a board opens it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ops'));
    await tester.pumpAndSettle();

    expect(controller.boardSlug, 'ops');
  });

  testWidgets('exports a board and says where the archive is', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards/ops/export', {
      'board': 'ops',
      'archive': '/srv/hermes/exports/ops.tar.gz',
      'size': 3072,
    });
    await pump(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include worker logs'));
    await tester.tap(find.widgetWithText(FilledButton, 'Export'));
    await tester.pumpAndSettle();

    expect(find.text('/srv/hermes/exports/ops.tar.gz'), findsOneWidget);
    expect(find.text('3.0 KB'), findsOneWidget);
    expect(
      jsonBody(
        server
            .requestsTo('POST', '/api/plugins/kanban/boards/ops/export')
            .single,
      ),
      {'output': '', 'attachments': true, 'logs': true},
    );
  });

  testWidgets('imports an archive and opens the new board', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards/import', {
      'board': 'restored',
      'renamed': false,
    });
    await pump(tester);

    await tester.tap(find.byTooltip('Import a board'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Archive path on the server'),
      '/srv/hermes/exports/ops.tar.gz',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server.requestsTo('POST', '/api/plugins/kanban/boards/import').single,
      ),
      {'archive': '/srv/hermes/exports/ops.tar.gz', 'switch': false},
    );
    expect(controller.boardSlug, 'restored');
    // The board opens, so the list gives way to it.
    expect(find.text('Boards'), findsNothing);
  });

  testWidgets('says when the imported board was renamed', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards/import', {
      'board': 'ops-2',
      'renamed': true,
    });
    await pump(tester);

    await tester.tap(find.byTooltip('Import a board'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Archive path on the server'),
      '/a.tar.gz',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.textContaining('the board is ops-2'), findsOneWidget);
  });

  testWidgets('says why an import was refused', (tester) async {
    server.on('POST', '/api/plugins/kanban/boards/import', {
      'detail': 'archive not found: /a.tar.gz',
    }, status: 404);
    await pump(tester);

    await tester.tap(find.byTooltip('Import a board'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Archive path on the server'),
      '/a.tar.gz',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('archive not found: /a.tar.gz'), findsOneWidget);
  });
}
