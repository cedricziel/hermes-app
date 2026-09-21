import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_kanban_files.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The Kanban screens `kanban_workflow_test.dart` does not walk: workers,
/// orchestration, boards management, the task panel and its dialogs, the
/// bulk-action bar, a crowded board and its filters.
void main() {
  late FakeHermesServer server;
  late FakeKanbanFiles files;

  const urlTitle =
      'https://example.internal/docs/webhooks/v2/signing-migration/rollout-'
      'plan-for-every-environment-we-run';

  // A board with many tasks, long titles and many assignees.
  List<Map<String, Object?>> crowdedTasks() {
    const assignees = [
      'coder',
      'writer',
      'ops-assistant-with-a-long-name',
      'reviewer',
      'designer',
      'researcher',
      'planner',
      'tester',
    ];
    return [
      for (var i = 1; i <= 3; i++)
        kanbanTaskRow(id: 't_tri$i', title: 'Triage item $i', status: 'triage'),
      for (var i = 1; i <= 8; i++)
        kanbanTaskRow(
          id: 't_todo$i',
          title: i.isEven
              ? 'Write the rollout plan for the webhook signing migration '
                    'and get every team to sign it off before Friday $i'
              : 'Todo $i',
          status: 'todo',
          assignee: assignees[i % assignees.length],
          priority: i % 4,
          commentCount: i,
        ),
      kanbanTaskRow(
        id: 't_rich',
        title:
            'Migrate every outgoing webhook to v2 signing and roll it out '
            'across all environments',
        status: 'running',
        assignee: 'coder',
        priority: 2,
        tenant: 'acme',
        commentCount: 12,
        progress: {'done': 2, 'total': 5},
        warnings: {'count': 2, 'kinds': <String>[]},
      ),
      kanbanTaskRow(
        id: 't_url',
        title: urlTitle,
        status: 'running',
        assignee: 'ops-assistant-with-a-long-name',
        tenant: 'a-tenant-with-a-rather-long-name',
        priority: 3,
        commentCount: 120,
        progress: {'done': 10, 'total': 25},
      ),
      for (var i = 1; i <= 12; i++)
        kanbanTaskRow(
          id: 't_run$i',
          title: 'Rotate staging certificates for cluster $i',
          status: 'running',
          assignee: assignees[i % assignees.length],
          tenant: i.isEven ? 'acme' : null,
          progress: {'done': i % 5, 'total': 5},
        ),
      kanbanTaskRow(
        id: 't_blocked1',
        title: 'Upgrade the database',
        status: 'blocked',
        assignee: 'coder',
      ),
      kanbanTaskRow(id: 't_review1', title: 'Review the PR', status: 'review'),
      kanbanTaskRow(
        id: 't_broken',
        title: 'A task whose details fail to load',
        status: 'review',
      ),
      for (var i = 1; i <= 6; i++)
        kanbanTaskRow(id: 't_done$i', title: 'Shipped $i', status: 'done'),
      kanbanTaskRow(
        id: 't_done_result',
        title: 'Ship v0.14 with the new signing',
        status: 'done',
        assignee: 'writer',
      ),
    ];
  }

  Map<String, Object?> boardBody({
    bool archived = false,
    String? tenant,
    List<String> tenants = const ['acme', 'a-tenant-with-a-rather-long-name'],
  }) {
    var tasks = crowdedTasks();
    if (tenant != null) {
      tasks = tasks.where((t) => t['tenant'] == tenant).toList();
    }
    final body = kanbanBoardBody(tasks, tenants: tenants);
    if (archived) {
      (body['columns']! as List).add({
        'name': 'archived',
        'tasks': [
          kanbanTaskRow(
            id: 't_old1',
            title: 'Retire the v1 webhook endpoints',
            status: 'archived',
            assignee: 'coder',
          ),
          kanbanTaskRow(id: 't_old2', title: 'Old spike', status: 'archived'),
        ],
      });
    }
    return body;
  }

  Map<String, Object?> richDetail() => kanbanTaskDetailBody(
    crowdedTasks().firstWhere((t) => t['id'] == 't_rich')
      ..['body'] =
          'Move every outgoing webhook to **v2 signing**.\n\n'
          'Start with the endpoints that carry payments, then the ones that '
          'carry user data. Each endpoint needs a retry queue that survives a '
          'restart, and the receiving side has to accept both signatures for '
          'two weeks before we drop the old one.\n\n'
          '- endpoints\n- retries\n- docs\n- ${'a-very-long-line-' * 8}'
      ..['diagnostics'] = [
        {
          'title': 'Worker stalled',
          'severity': 'error',
          'detail': 'No heartbeat for 10m. The process may be hung on a lock.',
        },
        {
          'title': 'Two parents are still open',
          'severity': 'warning',
          'detail': '',
        },
      ],
    comments: [
      for (var i = 1; i <= 12; i++)
        {
          'author': i.isEven ? 'writer' : 'coder',
          'body': i == 3
              ? 'Docs are drafted: https://example.internal/docs/webhooks/v2/'
                    'signing-migration/rollout-plan-for-every-environment-we-run'
              : 'Comment number $i. ${'It goes on for a while. ' * (i % 4)}',
          'created_at': 1780000000 + i * 3600,
        },
    ],
    parents: [for (var i = 1; i <= 8; i++) 't_parent_$i'],
    attachments: [
      {'id': 1, 'filename': 'spec.pdf', 'size': 2048},
      {
        'id': 2,
        'filename':
            'a-really-long-attachment-name-from-the-design-review-final-v3-'
            'FINAL-copy.pdf',
        'size': 5 * 1024 * 1024,
      },
      {'id': 3, 'filename': 'notes.txt', 'size': 12},
      {'id': 4, 'filename': 'screenshot.png', 'size': 350000},
    ],
    runs: [
      {
        'id': 5,
        'status': 'done',
        'profile': 'coder',
        'outcome': 'completed',
        'started_at': 1780000000,
        'ended_at': 1780000600,
        'summary': 'Finished endpoint 1',
      },
      {
        'id': 6,
        'status': 'crashed',
        'profile': 'ops-assistant-with-a-long-name',
        'started_at': 1780001000,
        'ended_at': 1780001100,
        'error': 'Worker exited with code 137 (out of memory) after 12 seconds',
      },
      {
        'id': 7,
        'status': 'running',
        'profile': 'coder',
        'started_at': 1780002000,
      },
    ],
    events: [
      for (final kind in [
        'created',
        'claimed',
        'heartbeat_missed',
        'reclaimed',
        'claimed',
        'commented',
      ])
        {'kind': kind, 'created_at': 1780000000},
    ],
  );

  Map<String, Object?> finishedDetail() =>
      kanbanTaskDetailBody(
          kanbanTaskRow(
              id: 't_done_result',
              title: 'Ship v0.14 with the new signing',
              status: 'done',
              assignee: 'writer',
            )
            ..['result'] =
                'Shipped on Tuesday. Two follow-ups were filed, one for the '
                'retry queue and one for the docs.',
        )
        ..['child_results'] = [
          {
            'id': 't_c1',
            'title': 'Cut the release branch',
            'status': 'done',
            'latest_summary': 'Branch cut from main at 4f2a91c',
          },
          {'id': 't_c2', 'title': 'Publish the notes', 'status': 'done'},
        ];

  setUp(() {
    files = FakeKanbanFiles();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 40, current: true),
          (slug: 'ops', name: 'Operations', total: 2, current: false),
        ]),
      )
      ..on('GET', '/api/plugins/kanban/board', boardBody())
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        boardBody(archived: true),
        query: {'include_archived': 'true'},
      )
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        boardBody(tenant: 'acme'),
        query: {'tenant': 'acme'},
      )
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': [
          'coder',
          'writer',
          'ops-assistant-with-a-long-name',
          'reviewer',
        ],
      })
      ..on('GET', '/api/plugins/kanban/tasks/t_rich', richDetail())
      ..on('GET', '/api/plugins/kanban/home-channels', {
        'home_channels': [
          {'platform': 'telegram', 'name': 'Ops chat', 'subscribed': true},
          {'platform': 'discord', 'name': 'Team', 'subscribed': false},
        ],
      })
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t_tri1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't_tri1', title: 'Triage item 1', status: 'triage'),
        ),
      )
      ..on('GET', '/api/plugins/kanban/tasks/t_done_result', finishedDetail())
      ..on('GET', '/api/plugins/kanban/tasks/t_broken', {
        'detail': 'boom',
      }, status: 500)
      ..on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'exists': false,
        'content': '',
      })
      ..on('GET', '/api/plugins/kanban/tasks/t_tri1/log', {
        'exists': false,
        'content': '',
      })
      ..on('PATCH', '/api/plugins/kanban/tasks/t_rich', {'ok': true})
      ..on('POST', '/api/plugins/kanban/tasks/t_rich/estimate', {
        'ok': true,
        'est_tokens': 240000,
        'complexity': 'XL',
        'rationale':
            'Touches every outgoing integration and needs a migration '
            'window, so it is broad and ambiguous.',
      });
  });

  Future<void> pumpBoard(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    shots,
    KanbanScreen(
      repository: KanbanRepository(server.client()),
      files: files,
      connect: ({required since, board}) async => StreamChannel<String>(
        StreamController<String>().stream,
        StreamController<String>().sink,
      ),
    ),
    size: size,
    brightness: brightness,
  );

  bool wide(Size size) => size.width > 720;

  Finder appBarMenu() => find
      .descendant(
        of: find.byType(AppBar),
        matching: find.byType(PopupMenuButton<String>),
      )
      .last;

  Finder panelScrollable() => find
      .descendant(
        of: find.byType(KanbanTaskPanel),
        matching: find.byType(Scrollable),
      )
      .first;

  Finder columnsScrollable() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal)
      .last;

  /// Taps [target], first bringing it into view: a task panel is a lazy list,
  /// so what is far down is not built until it is scrolled to.
  Future<void> tapText(WidgetTester tester, Object target) async {
    final finder = target is Finder ? target : find.text(target as String);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: panelScrollable(),
      );
    }
    // Centred, so a chip half under the top edge of a list is not tapped.
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Changing the tenant or the archive filter restarts the board, which the
  /// fake clock alone does not finish: the restart waits on real time.
  Future<void> settleRestart(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> openMoreMenu(WidgetTester tester, String item) async {
    await tester.tap(appBarMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  // The status chip on a phone; a wide screen has every column, but the
  // horizontal list only builds the ones it has scrolled to.
  Future<void> showColumn(WidgetTester tester, Size size, String name) async {
    if (wide(size)) {
      final header = find.textContaining(RegExp('^$name  \\d+\$'));
      await tester.drag(columnsScrollable(), const Offset(5000, 0));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        header,
        300,
        scrollable: columnsScrollable(),
      );
      await tester.pumpAndSettle();
      return;
    }
    final chip = find.textContaining(
      RegExp('^$name \\d+\$'),
      skipOffstage: false,
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------- board
  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: a crowded board and its filters', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-board-$name');
      await pumpBoard(tester, shots, size: size);
      await shots.capture(tester, 'crowded');

      // The end of the running list, where the FAB sits over the last card.
      final list = wide(size)
          ? find.byType(ListView).first
          : find.byType(ListView).last;
      if (!wide(size)) {
        await tester.drag(list, const Offset(0, -3000));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'running-bottom');
      } else {
        // Scroll the columns sideways to the last one.
        await tester.drag(list, const Offset(-3000, 0));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'columns-scrolled-right');
        await tester.drag(list, const Offset(3000, 0));
        await tester.pumpAndSettle();
      }

      await showColumn(tester, size, 'Todo');
      await shots.capture(tester, 'todo-long-titles');

      await tapText(tester, find.widgetWithText(FilterChip, 'Archived'));
      await settleRestart(tester);
      await showColumn(tester, size, 'Archived');
      await shots.capture(tester, 'archived');
      await tapText(tester, find.widgetWithText(FilterChip, 'Archived'));
      await settleRestart(tester);
      await showColumn(tester, size, 'Todo');

      await tester.tap(find.text('All assignees'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assignee-menu');
      await tester.tap(find.text('ops-assistant-with-a-long-name').last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assignee-long-name');

      await tester.tap(find.text('All tenants'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'tenant-menu');
      await tester.tap(find.text('acme').last);
      await settleRestart(tester);
      await shots.capture(tester, 'tenant-acme');

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search-no-match');
      await tester.enterText(find.byType(TextField), 'signing');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search-match');
    });
  }

  for (final (flow, size) in [
    ('kanban-extras-board-phone-dark', phoneSize),
    ('kanban-extras-board-desktop-dark', desktopSize),
  ]) {
    testWidgets('$flow: crowded board', (tester) async {
      final shots = ScreenshotRecorder(flow);
      await pumpBoard(tester, shots, size: size, brightness: Brightness.dark);
      await shots.capture(tester, 'crowded');
      await showColumn(tester, size, 'Todo');
      await shots.capture(tester, 'todo');
    });
  }

  // ------------------------------------------------------------- bulk bar
  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ]) {
    testWidgets('$name: bulk actions', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-bulk-$name');
      server.on('POST', '/api/plugins/kanban/tasks/bulk', {
        'results': [
          {'id': 't_rich', 'ok': true},
          {
            'id': 't_url',
            'ok': false,
            'error': 'illegal move: running -> ready',
          },
        ],
      });
      await pumpBoard(tester, shots, size: size, brightness: brightness);
      await tester.pumpAndSettle();

      if (wide(size)) {
        await openMoreMenu(tester, 'Select tasks');
      } else {
        await tester.longPress(
          find.text('Rotate staging certificates for cluster 1'),
        );
        await tester.pumpAndSettle();
        // Picking the only task again leaves nothing selected.
        await tester.tap(
          find.text('Rotate staging certificates for cluster 1'),
        );
        await tester.pumpAndSettle();
      }
      await shots.capture(tester, 'none-selected');

      for (final title in [
        find.textContaining('Migrate every outgoing'),
        find.textContaining('https://example.internal'),
        find.text('Rotate staging certificates for cluster 1'),
      ]) {
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await tester.tap(title);
        await tester.pumpAndSettle();
      }
      await shots.capture(tester, 'three-selected');

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assign-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'priority-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'archive-confirm');
      await popRoute(tester);

      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'partial-failure');
    });
  }

  // -------------------------------------------------------------- workers
  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ]) {
    testWidgets('$name: active workers', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-workers-$name');
      server
        ..on('GET', '/api/plugins/kanban/workers/active', {
          'workers': [
            {
              'run_id': 7,
              'task_id': 't_rich',
              'task_title': 'Migrate webhooks',
              'profile': 'coder',
              'worker_pid': 4242,
              'started_at': 1780000000,
              'last_heartbeat_at': 1780000100,
            },
            {
              'run_id': 8,
              'task_id': 't_url',
              'task_title': urlTitle,
              'profile': 'ops-assistant-with-a-long-name',
              'worker_pid': 4243,
              'started_at': 1780000000,
            },
            {
              'run_id': 9,
              'task_id': 't_run1',
              'task_title': 'Rotate staging certificates for cluster 1',
              'task_assignee': 'reviewer',
              'started_at': 1780000000,
              'last_heartbeat_at': 1780000100,
            },
          ],
        })
        ..on('GET', '/api/plugins/kanban/runs/7/inspect', {
          'alive': true,
          'pid': 4242,
          'status': 'sleeping',
          'cpu_percent': 12.5,
          'memory_rss_bytes': 104857600,
          'num_threads': 9,
        })
        ..on('GET', '/api/plugins/kanban/runs/8/inspect', {
          'alive': false,
          'reason': 'process not found',
        })
        ..on('POST', '/api/plugins/kanban/runs/7/terminate', {'ok': true});
      await pumpBoard(tester, shots, size: size, brightness: brightness);
      await openMoreMenu(tester, 'Active workers…');
      await shots.capture(tester, 'running');

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'row-menu');
      await tester.tap(find.text('Inspect process'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'inspect-figures');
      await popRoute(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect process'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'inspect-gone');
      await popRoute(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminate'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'terminate-confirm');
      await popRoute(tester);

      server.on('GET', '/api/plugins/kanban/workers/active', {
        'detail': 'gateway timeout',
      }, status: 504);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'refresh-failed');
    });
  }

  testWidgets('phone: workers, empty and failing', (tester) async {
    final shots = ScreenshotRecorder('kanban-extras-workers-phone-states');
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pumpBoard(tester, shots, size: phoneSize);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'empty');

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'x',
    }, status: 500);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    await popRoute(tester);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'load-failed');

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'board \'ops\' does not exist',
    }, status: 404);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'refused');
  });

  testWidgets('desktop: workers, empty and failing', (tester) async {
    final shots = ScreenshotRecorder('kanban-extras-workers-desktop-states');
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pumpBoard(tester, shots, size: desktopSize);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'empty');
    await popRoute(tester);

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'x',
    }, status: 500);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'load-failed');
  });

  // -------------------------------------------------------- orchestration
  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ]) {
    testWidgets('$name: orchestration dialog', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-orchestration-$name');
      server
        ..on('GET', '/api/plugins/kanban/orchestration', {
          'orchestrator_profile': 'ops-assistant-with-a-long-name',
          'default_assignee': '',
          'auto_decompose': true,
          'auto_promote_children': false,
          'active_profile': 'default',
        })
        ..on('PUT', '/api/plugins/kanban/orchestration', {
          'detail': 'unknown profile',
        }, status: 400);
      await pumpBoard(tester, shots, size: size, brightness: brightness);
      await openMoreMenu(tester, 'Orchestration…');
      await shots.capture(tester, 'loaded');

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profile-menu');
      await tester.tap(find.text('reviewer').last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profile-picked');

      await tester.tap(find.text('Promote children when ready'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-refused');
    });
  }

  testWidgets('phone: orchestration cannot load', (tester) async {
    final shots = ScreenshotRecorder('kanban-extras-orchestration-phone-fail');
    server.on('GET', '/api/plugins/kanban/orchestration', {
      'detail': 'x',
    }, status: 500);
    await pumpBoard(tester, shots, size: phoneSize);
    await openMoreMenu(tester, 'Orchestration…');
    await shots.capture(tester, 'load-failed');
  });

  // --------------------------------------------------------------- boards
  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ]) {
    testWidgets('$name: managing boards', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-boards-$name');
      server
        ..on(
          'GET',
          '/api/plugins/kanban/boards',
          kanbanBoardsBody([
            (slug: 'default', name: 'Default', total: 40, current: true),
            (
              slug: 'ops',
              name:
                  'Operations and infrastructure for the whole platform '
                  'engineering organisation',
              total: 2,
              current: false,
            ),
            for (var i = 1; i <= 12; i++)
              (slug: 'team-$i', name: 'Team $i', total: i, current: false),
          ]),
        )
        ..on('POST', '/api/plugins/kanban/boards', {'board': {}})
        ..on('PATCH', '/api/plugins/kanban/boards/default', {'board': {}})
        ..on('DELETE', '/api/plugins/kanban/boards/default', {'result': {}})
        ..on('POST', '/api/plugins/kanban/boards/default/export', {
          'board': 'default',
          'archive':
              '/srv/hermes/exports/default-2026-09-20-final-export.tar.gz',
          'size': 3072,
        })
        ..on('POST', '/api/plugins/kanban/boards/import', {
          'detail': 'archive not found: /srv/hermes/exports/missing.tar.gz',
        }, status: 404);
      await pumpBoard(tester, shots, size: size, brightness: brightness);
      await tester.tap(find.byTooltip('Switch board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switch-menu');
      await tester.ensureVisible(find.text('Manage boards…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage boards…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list');

      final screen = find.byType(KanbanBoardsScreen);
      final list = find.descendant(of: screen, matching: find.byType(ListView));
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list-bottom');
      await tester.drag(list, const Offset(0, 3000));
      await tester.pumpAndSettle();

      Future<void> rowMenu(String item) async {
        await tester.tap(
          find
              .descendant(
                of: screen,
                matching: find.byType(PopupMenuButton<String>),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      await tester.tap(
        find
            .descendant(
              of: screen,
              matching: find.byType(PopupMenuButton<String>),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'row-menu');
      await popRoute(tester);

      await tester.tap(find.text('New board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board');
      await tester.enterText(
        find.byType(TextField),
        'Quarterly launch planning for the whole company',
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board-long-name');
      await tester.enterText(find.byType(TextField), '日本語');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board-invalid');

      await rowMenu('Rename');
      await shots.capture(tester, 'rename');
      await popRoute(tester);

      await rowMenu('Archive');
      await shots.capture(tester, 'archive-confirm');
      await popRoute(tester);

      await rowMenu('Delete');
      await shots.capture(tester, 'delete-confirm');
      await popRoute(tester);

      await rowMenu('Export…');
      await shots.capture(tester, 'export');
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'exported');
      await popRoute(tester);

      await tester.tap(find.byTooltip('Import a board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'import');
      await tester.enterText(
        find.widgetWithText(TextField, 'Archive path on the server'),
        '/srv/hermes/exports/missing.tar.gz',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'import-refused');
    });
  }

  // ----------------------------------------------------------- task panel
  Future<void> pageThrough(
    WidgetTester tester,
    ScreenshotRecorder shots,
    String prefix,
  ) async {
    final position = tester.state<ScrollableState>(panelScrollable()).position;
    var n = 1;
    while (position.pixels < position.maxScrollExtent - 1 && n <= 8) {
      await tester.drag(
        panelScrollable(),
        Offset(0, -(position.viewportDimension - 100)),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, '$prefix-$n');
      n++;
    }
  }

  Future<void> panelToTop(WidgetTester tester) async {
    await tester.drag(panelScrollable(), const Offset(0, 8000));
    await tester.pumpAndSettle();
  }

  for (final (name, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
  ]) {
    testWidgets('$name: a busy task panel', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-panel-$name');
      await pumpBoard(tester, shots, size: size, brightness: brightness);
      await tester.tap(find.textContaining('Migrate every outgoing'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'top');
      await pageThrough(tester, shots, 'scroll');

      await tapText(tester, find.textContaining('Runs ('));
      await shots.capture(tester, 'runs-open');
      await tapText(tester, find.text('History'));
      await pageThrough(tester, shots, 'history');

      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'log-none');
      await popRoute(tester);

      await panelToTop(tester);
      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'estimate');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'edit-dialog');
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'A much longer replacement title that keeps going for two lines',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        List.generate(
          10,
          (i) => 'Line ${i + 1} of the description, which is fairly long.',
        ).join('\n'),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'edit-dialog-filled');
      await popRoute(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'coder'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assign-dialog');
      await popRoute(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'P2'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'priority-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-menu');
      await popRoute(tester);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'result-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'block-dialog');
      await popRoute(tester);

      await tester.tap(find.text('Reclaim'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'reclaim-confirm');
      await popRoute(tester);

      await tapText(tester, find.widgetWithText(ActionChip, 'Add'));
      await shots.capture(tester, 'depends-on-dialog');
      await popRoute(tester);

      server.on('PATCH', '/api/plugins/kanban/tasks/t_rich', {
        'detail': 'Cannot move to ready: 2 parents are still open',
      }, status: 409);
      await panelToTop(tester);
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-refused');
    });
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: task attachments and destructive actions', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('kanban-extras-attachments-$name');
      server
        ..on('DELETE', '/api/plugins/kanban/attachments/2', {'ok': true})
        ..on('GET', '/api/plugins/kanban/attachments/2', {
          'detail': 'attachment file missing on disk',
        }, status: 404);
      files.pickError = const KanbanException(
        'notes.txt is over the 25 MB limit for attachments.',
      );
      await pumpBoard(tester, shots, size: size);
      await tester.tap(find.textContaining('Migrate every outgoing'));
      await tester.pumpAndSettle();

      await tapText(tester, find.text('Attachments'.toUpperCase()));
      await shots.capture(tester, 'attachments');

      await tapText(tester, find.byTooltip('Save attachment').at(1));
      await shots.capture(tester, 'download-failed');
      await tapText(tester, find.text('Attach file'));
      await shots.capture(tester, 'attach-failed');
      await tapText(tester, find.byTooltip('Remove attachment').at(1));
      await shots.capture(tester, 'remove-confirm');
      await popRoute(tester);

      await tapText(tester, find.text('Archive').last);
      await shots.capture(tester, 'archive-confirm');
      await popRoute(tester);
      await tapText(tester, find.text('Delete').last);
      await shots.capture(tester, 'delete-confirm');
    });

    testWidgets('$name: task worker log', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-log-$name');
      await pumpBoard(tester, shots, size: size);
      await tester.tap(find.textContaining('Migrate every outgoing'));
      await tester.pumpAndSettle();
      await tapText(tester, find.textContaining('Runs ('));

      server.on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'exists': true,
        'truncated': true,
        'content': [
          for (var i = 1; i <= 60; i++)
            i == 20
                ? '[worker] ${'a-very-long-log-line-without-any-spaces-' * 4}'
                : '[worker] step $i of 60: talking to the endpoint',
        ].join('\n'),
      });
      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'long-log');
      await popRoute(tester);

      server.on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'exists': true,
        'content': '',
      });
      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'empty-log');
      await popRoute(tester);

      server.on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'detail': 'x',
      }, status: 500);
      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'log-failed');
    });

    testWidgets('$name: triage, finished and broken tasks', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-states-$name');
      server
        ..on('POST', '/api/plugins/kanban/tasks/t_tri1/decompose', {
          'ok': true,
          'child_ids': ['t7', 't8'],
        })
        ..on('POST', '/api/plugins/kanban/tasks/t_tri1/specify', {
          'ok': false,
          'reason': 'No auxiliary model configured',
        });
      await pumpBoard(tester, shots, size: size);

      await showColumn(tester, size, 'Triage');
      await tester.tap(find.text('Triage item 1'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'triage');
      await tester.tap(find.text('Specify'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'specify-declined');
      await tester.tap(find.text('Decompose'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'decomposed');
      await popRoute(tester);

      await showColumn(tester, size, 'Done');
      await tester.tap(find.text('Ship v0.14 with the new signing'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'done-with-result');
      await popRoute(tester);

      await showColumn(tester, size, 'Review');
      await tester.tap(find.text('A task whose details fail to load'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'load-failed');
    });
  }

  testWidgets('phone: board that failed to refresh keeps its notice', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('kanban-extras-board-phone-stale');
    await pumpBoard(tester, shots, size: phoneSize);
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await tester.drag(find.byType(ListView).last, const Offset(0, 400));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'refresh-failed');
  });
}
