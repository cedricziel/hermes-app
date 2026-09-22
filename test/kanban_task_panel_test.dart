import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/kanban_files.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_kanban_files.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late int changes;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(
            id: 't1',
            title: 'Migrate webhooks',
            status: 'running',
            assignee: 'coder',
            priority: 2,
          )..['body'] = 'Move to v2 signing',
          comments: [
            {
              'author': 'coder',
              'body': 'Endpoint 1 done',
              'created_at': 1780000000,
            },
          ],
          parents: ['t0'],
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder', 'writer'],
      })
      ..on('PATCH', '/api/plugins/kanban/tasks/t1', {'ok': true})
      ..on('POST', '/api/plugins/kanban/tasks/t1/comments', {'ok': true});
    changes = 0;
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: KanbanTaskPanel(
            repository: KanbanRepository(server.client()),
            taskId: 't1',
            board: 'ops',
            onChanged: () => changes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the task, its description, links and comments', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.text('Move to v2 signing'), findsOneWidget);
    expect(find.text('coder'), findsWidgets);
    expect(find.text('t0'), findsOneWidget);
    expect(find.textContaining('Endpoint 1 done'), findsOneWidget);
    expect(
      server
          .requestsTo('GET', '/api/plugins/kanban/tasks/t1')
          .single
          .queryParameters['board'],
      'ops',
    );
  });

  testWidgets('blocking asks why and tells the board', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Waiting on design');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
    );
    expect(body, containsPair('status', 'blocked'));
    expect(body, containsPair('block_reason', 'Waiting on design'));
    expect(changes, 1);
  });

  testWidgets('says why when the plugin refuses a move', (tester) async {
    server.on('PATCH', '/api/plugins/kanban/tasks/t1', {
      'detail': 'Cannot move to ready: parent open',
    }, status: 409);
    await pumpPanel(tester);

    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot move to ready: parent open'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('a slow reload does not replace a newer one', (tester) async {
    await pumpPanel(tester);
    final gate = Completer<FakeResponse>();
    var loads = 0;
    server.onRequest('GET', '/api/plugins/kanban/tasks/t1', (_) {
      loads++;
      FakeResponse detail(String title) => (
        status: 200,
        body: kanbanTaskDetailBody(kanbanTaskRow(id: 't1', title: title)),
      );
      return loads == 1 ? gate.future : detail('Newest title');
    });

    for (final text in ['one', 'two']) {
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a comment…').first,
        text,
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
    }
    gate.complete((
      status: 200,
      body: kanbanTaskDetailBody(kanbanTaskRow(id: 't1', title: 'Old title')),
    ));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('Newest title'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
  });

  testWidgets('posts a comment and clears the box', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a comment…').first,
      'Ship it',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server
            .requestsTo('POST', '/api/plugins/kanban/tasks/t1/comments')
            .single,
      ),
      containsPair('body', 'Ship it'),
    );
    expect(find.text('Ship it'), findsNothing);
  });

  testWidgets('reassigns from the picker', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'coder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('writer'));
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
      ),
      containsPair('assignee', 'writer'),
    );
  });

  testWidgets('unlinks a dependency', (tester) async {
    server.on('DELETE', '/api/plugins/kanban/links', {'ok': true});
    await pumpPanel(tester);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(
      server
          .requestsTo('DELETE', '/api/plugins/kanban/links')
          .single
          .queryParameters,
      {'parent_id': 't0', 'child_id': 't1', 'board': 'ops'},
    );
  });

  void serveStatus(String status) => server.on(
    'GET',
    '/api/plugins/kanban/tasks/t1',
    kanbanTaskDetailBody(
      kanbanTaskRow(id: 't1', title: 'Rough idea', status: status),
    ),
  );

  testWidgets('triage tasks offer Decompose and say how many tasks came out', (
    tester,
  ) async {
    serveStatus('triage');
    server.on('POST', '/api/plugins/kanban/tasks/t1/decompose', {
      'ok': true,
      'child_ids': ['t2', 't3'],
    });
    await pumpPanel(tester);

    await tester.tap(find.text('Decompose'));
    await tester.pumpAndSettle();

    expect(find.text('Decomposed into 2 tasks'), findsOneWidget);
    expect(changes, 1);
  });

  testWidgets('shows why a triage helper declined and changes nothing', (
    tester,
  ) async {
    serveStatus('triage');
    server.on('POST', '/api/plugins/kanban/tasks/t1/specify', {
      'ok': false,
      'reason': 'No auxiliary model configured',
    });
    await pumpPanel(tester);

    await tester.tap(find.text('Specify'));
    await tester.pumpAndSettle();

    expect(find.text('No auxiliary model configured'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('only triage tasks offer the triage helpers', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Decompose'), findsNothing);
    expect(find.text('Specify'), findsNothing);
  });

  testWidgets('a running task can be reclaimed after confirming', (
    tester,
  ) async {
    server.on('POST', '/api/plugins/kanban/tasks/t1/reclaim', {'ok': true});
    await pumpPanel(tester);

    await tester.tap(find.text('Reclaim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reclaim'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/tasks/t1/reclaim'),
      hasLength(1),
    );
    expect(changes, 1);
  });

  void serveRich() => server
    ..on(
      'GET',
      '/api/plugins/kanban/tasks/t1',
      kanbanTaskDetailBody(
        kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running')
          ..['diagnostics'] = [
            {
              'title': 'Worker stalled',
              'severity': 'error',
              'detail': 'No heartbeat for 10m',
            },
          ],
        runs: [
          {
            'id': 7,
            'status': 'running',
            'profile': 'coder',
            'started_at': 1780000000,
          },
        ],
        attachments: [
          {'id': 3, 'filename': 'spec.pdf', 'size': 2048},
        ],
      ),
    )
    ..on('POST', '/api/plugins/kanban/runs/7/terminate', {'ok': true})
    ..on('DELETE', '/api/plugins/kanban/attachments/3', {'ok': true})
    ..on('GET', '/api/plugins/kanban/tasks/t1/log', {
      'exists': true,
      'content': 'starting worker',
    });

  testWidgets('shows what needs attention and the attachments', (tester) async {
    serveRich();
    await pumpPanel(tester);

    expect(find.text('Worker stalled'), findsOneWidget);
    expect(find.text('No heartbeat for 10m'), findsOneWidget);
    expect(find.text('spec.pdf'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('terminates the active run after confirming', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.textContaining('Runs ('));
    await tester.tap(find.textContaining('Runs ('));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Terminate'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Terminate'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/runs/7/terminate'),
      hasLength(1),
    );
    expect(changes, 1);
  });

  testWidgets('opens the worker log', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.textContaining('Runs ('));
    await tester.tap(find.textContaining('Runs ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker log'));
    await tester.pumpAndSettle();

    expect(find.text('starting worker'), findsOneWidget);
  });

  testWidgets('removes an attachment after confirming', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.byTooltip('Remove attachment'));
    await tester.tap(find.byTooltip('Remove attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('DELETE', '/api/plugins/kanban/attachments/3'),
      hasLength(1),
    );
  });

  testWidgets('deleting a task does not fetch it again', (tester) async {
    server.on('DELETE', '/api/plugins/kanban/tasks/t1', {'ok': true});
    await pumpPanel(tester);
    final loads = server
        .requestsTo('GET', '/api/plugins/kanban/tasks/t1')
        .length;

    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('DELETE', '/api/plugins/kanban/tasks/t1'),
      hasLength(1),
    );
    expect(
      server.requestsTo('GET', '/api/plugins/kanban/tasks/t1'),
      hasLength(loads),
    );
  });

  testWidgets(
    'offers no Terminate for a run left open on a task that is not running',
    (tester) async {
      server.on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Stalled', status: 'blocked'),
          runs: [
            {
              'id': 7,
              'status': 'crashed',
              'profile': 'coder',
              'started_at': 1780000000,
            },
          ],
        ),
      );
      await pumpPanel(tester);

      await tester.ensureVisible(find.textContaining('Runs ('));
      await tester.tap(find.textContaining('Runs ('));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Terminate'), findsNothing);
    },
  );

  group('attachments', () {
    late FakeKanbanFiles files;

    Future<void> pumpWithFiles(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: KanbanTaskPanel(
              repository: KanbanRepository(server.client()),
              files: files,
              taskId: 't1',
              board: 'ops',
              onChanged: () => changes++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      files = FakeKanbanFiles();
      server.on('POST', '/api/plugins/kanban/tasks/t1/attachments', {
        'attachment': {'id': 4},
      });
    });

    testWidgets('offers to attach a file even when there are none', (
      tester,
    ) async {
      await pumpWithFiles(tester);

      expect(find.text('Attach file'), findsOneWidget);
    });

    testWidgets('uploads the chosen file and tells the board', (tester) async {
      files.next = KanbanPickedFile(
        name: 'notes.txt',
        bytes: Uint8List.fromList([104, 105]),
      );
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.text('Attach file'));
      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();

      final request = server
          .requestsTo('POST', '/api/plugins/kanban/tasks/t1/attachments')
          .single;
      expect(
        (request.data as FormData).files.single.value.filename,
        'notes.txt',
      );
      expect(changes, 1);
    });

    testWidgets('says so when the picker fails', (tester) async {
      files.pickError = const KanbanException(
        'notes.txt is over the 25 MB limit for attachments.',
      );
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.text('Attach file'));
      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();

      expect(find.textContaining('over the 25 MB limit'), findsOneWidget);
      expect(
        server.requestsTo('POST', '/api/plugins/kanban/tasks/t1/attachments'),
        isEmpty,
      );
    });

    testWidgets(
      'a second tap while the dialog is open opens no second dialog',
      (tester) async {
        files.pickGate = Completer<void>();
        await pumpWithFiles(tester);

        await tester.ensureVisible(find.text('Attach file'));
        await tester.tap(find.text('Attach file'));
        await tester.pump();
        await tester.tap(find.text('Attach file'), warnIfMissed: false);
        await tester.pump();

        expect(files.pickCalls, 1);
        files.pickGate!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('sends nothing when the user cancels the picker', (
      tester,
    ) async {
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.text('Attach file'));
      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('POST', '/api/plugins/kanban/tasks/t1/attachments'),
        isEmpty,
      );
      expect(changes, 0);
    });

    testWidgets('says why the plugin refused a file', (tester) async {
      server.on('POST', '/api/plugins/kanban/tasks/t1/attachments', {
        'detail': 'attachment exceeds 25 MB limit',
      }, status: 413);
      files.next = KanbanPickedFile(name: 'big.bin', bytes: Uint8List(1));
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.text('Attach file'));
      await tester.tap(find.text('Attach file'));
      await tester.pumpAndSettle();

      expect(find.text('attachment exceeds 25 MB limit'), findsOneWidget);
      expect(changes, 0);
    });

    testWidgets('saves a downloaded attachment under its name', (tester) async {
      serveRich();
      final bytes = Uint8List.fromList([0, 255, 128, 7]);
      server.on('GET', '/api/plugins/kanban/attachments/3', bytes);
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.byTooltip('Save attachment'));
      await tester.tap(find.byTooltip('Save attachment'));
      await tester.pumpAndSettle();

      expect(files.saved.single.name, 'spec.pdf');
      expect(files.saved.single.bytes, bytes);
      expect(find.text('Saved spec.pdf'), findsOneWidget);
    });

    testWidgets('says nothing when the user cancels the save', (tester) async {
      serveRich();
      server.on('GET', '/api/plugins/kanban/attachments/3', Uint8List(2));
      files.saves = false;
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.byTooltip('Save attachment'));
      await tester.tap(find.byTooltip('Save attachment'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Saved'), findsNothing);
    });

    testWidgets('says why a download failed', (tester) async {
      serveRich();
      server.on('GET', '/api/plugins/kanban/attachments/3', {
        'detail': 'attachment file missing on disk',
      }, status: 404);
      await pumpWithFiles(tester);

      await tester.ensureVisible(find.byTooltip('Save attachment'));
      await tester.tap(find.byTooltip('Save attachment'));
      await tester.pumpAndSettle();

      expect(find.text('attachment file missing on disk'), findsOneWidget);
      expect(files.saved, isEmpty);
    });
  });

  group('estimates and notifications', () {
    testWidgets('sizes up the task on request', (tester) async {
      server.on('POST', '/api/plugins/kanban/tasks/t1/estimate', {
        'ok': true,
        'est_tokens': 80000,
        'complexity': 'L',
        'rationale': 'Broad and ambiguous.',
      });
      await pumpPanel(tester);

      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();

      expect(find.text('about 80k tokens · large'), findsOneWidget);
      expect(find.text('Broad and ambiguous.'), findsOneWidget);
    });

    testWidgets('shows why the helper could not estimate', (tester) async {
      server.on('POST', '/api/plugins/kanban/tasks/t1/estimate', {
        'ok': false,
        'reason': 'auxiliary client unavailable',
      });
      await pumpPanel(tester);

      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();

      expect(find.text('auxiliary client unavailable'), findsOneWidget);
    });

    testWidgets('shows no Notify section when the server has no home channel', (
      tester,
    ) async {
      server.on('GET', '/api/plugins/kanban/home-channels', {
        'home_channels': [],
      });
      await pumpPanel(tester);

      expect(find.text('Notify'.toUpperCase()), findsNothing);
    });

    testWidgets('switches a home channel on and back off', (tester) async {
      server
        ..on('GET', '/api/plugins/kanban/home-channels', {
          'home_channels': [
            {'platform': 'telegram', 'name': 'Ops chat', 'subscribed': false},
          ],
        })
        ..on('POST', '/api/plugins/kanban/tasks/t1/home-subscribe/telegram', {
          'ok': true,
        })
        ..on('DELETE', '/api/plugins/kanban/tasks/t1/home-subscribe/telegram', {
          'ok': true,
        });
      await pumpPanel(tester);

      await tester.ensureVisible(find.text('Post updates to Ops chat'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        server.requestsTo(
          'POST',
          '/api/plugins/kanban/tasks/t1/home-subscribe/telegram',
        ),
        hasLength(1),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        server.requestsTo(
          'DELETE',
          '/api/plugins/kanban/tasks/t1/home-subscribe/telegram',
        ),
        hasLength(1),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('a refused subscription leaves the switch where it was', (
      tester,
    ) async {
      server
        ..on('GET', '/api/plugins/kanban/home-channels', {
          'home_channels': [
            {'platform': 'telegram', 'name': 'Ops chat', 'subscribed': false},
          ],
        })
        ..on('POST', '/api/plugins/kanban/tasks/t1/home-subscribe/telegram', {
          'detail': 'No home channel configured',
        }, status: 404);
      await pumpPanel(tester);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('No home channel configured'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('estimate and notify follow-ups', () {
    testWidgets('an estimate is dropped once the task is changed', (
      tester,
    ) async {
      server
        ..on('POST', '/api/plugins/kanban/tasks/t1/estimate', {
          'ok': true,
          'est_tokens': 5000,
          'complexity': 'S',
        })
        ..on('POST', '/api/plugins/kanban/tasks/t1/comments', {'ok': true});
      await pumpPanel(tester);
      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();
      expect(find.text('about 5k tokens · small'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Add a comment…').first,
        'hi',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      // A comment is not an edit of the task, but any change made here
      // clears the estimate rather than guessing which ones matter.
      expect(find.text('about 5k tokens · small'), findsNothing);
    });

    testWidgets('a switch cannot be flipped again while its request is out', (
      tester,
    ) async {
      final release = Completer<void>();
      server
        ..on('GET', '/api/plugins/kanban/home-channels', {
          'home_channels': [
            {'platform': 'telegram', 'name': 'Ops chat', 'subscribed': false},
          ],
        })
        ..onRequest(
          'POST',
          '/api/plugins/kanban/tasks/t1/home-subscribe/telegram',
          (_) async {
            await release.future;
            return (status: 200, body: {'ok': true});
          },
        );
      await pumpPanel(tester);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      release.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    });
  });
}
