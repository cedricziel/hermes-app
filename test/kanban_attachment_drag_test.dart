import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_task_controller.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/fake_drag_out_source.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_kanban_files.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late FakeDragOutSource source;
  late FakeKanbanFiles files;

  setUp(() {
    source = FakeDragOutSource();
    files = FakeKanbanFiles();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'ready'),
          attachments: [
            {'id': 3, 'filename': 'spec.pdf', 'size': 2048},
          ],
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]})
      ..on('DELETE', '/api/plugins/kanban/attachments/3', {'ok': true});
  });

  // Dio's futures need real time, which fake async does not give.
  Future<T?> real<T>(WidgetTester tester, Future<T> Function() body) =>
      tester.runAsync(body);

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Provider<DragOutSource?>.value(
          value: source,
          child: Scaffold(
            body: KanbanTaskPanel(
              repository: KanbanRepository(server.client()),
              files: files,
              taskId: 't1',
              board: 'ops',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a row drags out as a file fetched with the board', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([0, 255, 128, 7]);
    server.on('GET', '/api/plugins/kanban/attachments/3', bytes);
    await pumpPanel(tester);

    expect(source.wraps.single.kind, DragOutKind.kanbanAttachment);
    expect(source.lastFile.name, 'spec.pdf');
    expect(
      server.requestsTo('GET', '/api/plugins/kanban/attachments/3'),
      isEmpty,
      reason: 'nothing is fetched when the drag starts',
    );

    expect(await real(tester, source.lastFile.read), bytes);
    final request = server
        .requestsTo('GET', '/api/plugins/kanban/attachments/3')
        .single;
    expect(request.queryParameters['board'], 'ops');
  });

  testWidgets('a missing attachment fails the read cleanly', (tester) async {
    server.on('GET', '/api/plugins/kanban/attachments/3', {
      'detail': 'attachment file missing on disk',
    }, status: 404);
    await pumpPanel(tester);

    final error = await real(tester, () async {
      try {
        await source.lastFile.read();
        return null;
      } on Object catch (e) {
        return e;
      }
    });

    expect(error, isA<KanbanException>());
    expect(find.text('spec.pdf'), findsOneWidget);
  });

  test('reading for a drag does not mark the task as transferring', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/plugins/kanban/attachments/3', (_) async {
      await gate.future;
      return (status: 200, body: Uint8List(2));
    });
    final controller = KanbanTaskController(
      repository: KanbanRepository(server.client()),
      taskId: 't1',
      board: 'ops',
    );
    var notified = 0;
    controller.addListener(() => notified++);

    final read = controller.readAttachment(
      const KanbanAttachment(id: 3, filename: 'spec.pdf'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.transferring, isFalse);
    gate.complete();
    expect(await read, hasLength(2));
    expect(controller.transferring, isFalse);
    expect(notified, 0);
  });

  testWidgets('Save keeps working with the row wrapped', (tester) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    server.on('GET', '/api/plugins/kanban/attachments/3', bytes);
    await pumpPanel(tester);

    await tester.ensureVisible(find.byTooltip('Save attachment'));
    await tester.tap(find.byTooltip('Save attachment'));
    await tester.pumpAndSettle();

    expect(files.saved.single.name, 'spec.pdf');
    expect(files.saved.single.bytes, bytes);
  });

  testWidgets('a transfer in progress does not stop the drag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<DragOutSource?>.value(
          value: source,
          child: Scaffold(
            body: KanbanTaskAttachments(
              attachments: const [
                KanbanAttachment(id: 1, filename: 'notes.txt'),
              ],
              transferring: true,
              onAttach: () {},
              onDownload: (_) {},
              onRemove: (_) {},
              onRead: (_) async => Uint8List.fromList([9]),
            ),
          ),
        ),
      ),
    );

    expect(await real(tester, source.lastFile.read), [9]);
  });

  testWidgets('without a reader no row is draggable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<DragOutSource?>.value(
          value: source,
          child: Scaffold(
            body: KanbanTaskAttachments(
              attachments: const [
                KanbanAttachment(id: 1, filename: 'notes.txt'),
              ],
              onAttach: () {},
              onDownload: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(source.wraps, isEmpty);
  });
}
