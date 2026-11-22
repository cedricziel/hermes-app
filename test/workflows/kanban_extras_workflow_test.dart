import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_list_rows.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_kanban_files.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The rows of the open bulk picker, whatever the value type behind them.
final _choiceRows = find.byWidgetPredicate(
  (widget) => widget is GroupedChoiceRow,
);

Finder _choiceRow(String label) =>
    find.descendant(of: _choiceRows, matching: find.text(label));

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

  // ------------------------------------------------------------- assertions
  // A card on the board. A task's title also appears as a status chip count
  // or in a panel, so the card is found by its own type.
  Finder card(String title) => find.widgetWithText(KanbanCard, title);

  bool cardSelected(WidgetTester tester, String title) =>
      tester.widget<KanbanCard>(card(title)).selected;

  // The cards marked as picked, among those on screen.
  List<KanbanCard> pickedCards(WidgetTester tester) => tester
      .widgetList<KanbanCard>(find.byType(KanbanCard))
      .where((c) => c.selected)
      .toList();

  Finder inCard(String title, String text) =>
      find.descendant(of: card(title), matching: find.text(text));

  // What a column is called to the user: a chip on a phone, a header on a
  // wide screen.
  Finder columnLabel(Size size, String name, int count) => wide(size)
      ? find.text('$name  $count')
      : find.widgetWithText(ChoiceChip, '$name $count', skipOffstage: false);

  bool chipSelected(WidgetTester tester, String name, int count) =>
      tester.widget<ChoiceChip>(columnLabel(phoneSize, name, count)).selected;

  Iterable<RequestOptions> boardLoads() =>
      server.requestsTo('GET', '/api/plugins/kanban/board');

  Iterable<RequestOptions> sent(String method, String path) =>
      server.requestsTo(method, path);

  Map<Object?, Object?> bodyOf(RequestOptions request) =>
      jsonBody(request) as Map<Object?, Object?>;

  // The text of the snack bar on screen, if any.
  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  // A snack bar waits for the one before it to go. Lets it go, as a person
  // would by waiting, so the next message is the one on screen.
  Future<void> letSnackBarsGo(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  }

  // The panel of the task on screen, whatever it is shown in.
  Finder inPanel(String text) => find.descendant(
    of: find.byType(KanbanTaskPanel),
    matching: find.text(text),
  );

  // The value a row of the task panel shows, such as who has the task.
  String valueRowText(WidgetTester tester, String row) => tester
      .widget<GroupedValueRow>(find.widgetWithText(GroupedValueRow, row))
      .value;

  bool switchOn(WidgetTester tester, String title) => tester
      .widget<GroupedSwitchRow>(find.widgetWithText(GroupedSwitchRow, title))
      .value;

  bool isDark(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(KanbanScreen))).brightness ==
      Brightness.dark;

  // ---------------------------------------------------------------- board
  const richTitle =
      'Migrate every outgoing webhook to v2 signing and roll it out '
      'across all environments';
  const longTodoTitle =
      'Write the rollout plan for the webhook signing migration '
      'and get every team to sign it off before Friday 2';
  const opsAssignee = 'ops-assistant-with-a-long-name';

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: a crowded board and its filters', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-board-$name');
      await pumpBoard(tester, shots, size: size);
      await shots.capture(tester, 'crowded');
      expect(find.text('Kanban'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('All assignees'), findsOneWidget);
      expect(find.text('All tenants'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Archived'))
            .selected,
        isFalse,
      );
      expect(find.text('No tasks here'), findsNothing);
      // Nothing is archived yet, and the board was asked for without it.
      expect(columnLabel(size, 'Archived', 2), findsNothing);
      expect(boardLoads(), hasLength(1));
      if (wide(size)) {
        // Real columns, each headed with its task count.
        expect(columnLabel(size, 'Triage', 3), findsOneWidget);
        expect(columnLabel(size, 'Todo', 8), findsOneWidget);
        expect(columnLabel(size, 'Scheduled', 0), findsOneWidget);
        expect(columnLabel(size, 'Ready', 0), findsOneWidget);
        expect(card('Triage item 1'), findsOneWidget);
        expect(find.byTooltip('Refresh'), findsOneWidget);
      } else {
        // Running is listed, with a chip for every column and its count.
        expect(chipSelected(tester, 'Running', 14), isTrue);
        expect(chipSelected(tester, 'Todo', 8), isFalse);
        expect(columnLabel(size, 'Triage', 3), findsOneWidget);
        expect(columnLabel(size, 'Done', 7), findsOneWidget);
        expect(card(richTitle), findsOneWidget);
        expect(card('Todo 1'), findsNothing);
        // Everything worth scanning for is on the card.
        expect(inCard(richTitle, 't_rich'), findsOneWidget);
        expect(inCard(richTitle, 'coder'), findsOneWidget);
        expect(inCard(richTitle, 'P2'), findsOneWidget);
        expect(inCard(richTitle, 'acme'), findsOneWidget);
        expect(inCard(richTitle, '12'), findsOneWidget);
        expect(inCard(richTitle, '2/5'), findsOneWidget);
        expect(inCard(richTitle, '2'), findsOneWidget);
        expect(find.byTooltip('Refresh'), findsNothing);
      }

      // The end of the running list, where the FAB sits over the last card.
      final list = wide(size)
          ? find.byType(ListView).first
          : find.byType(ListView).last;
      if (!wide(size)) {
        await tester.drag(list, const Offset(0, -3000));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'running-bottom');
        expect(
          card('Rotate staging certificates for cluster 12'),
          findsOneWidget,
        );
        expect(card(richTitle), findsNothing);
        expect(find.text('New task'), findsOneWidget);
      } else {
        // Scroll the columns sideways to the last one.
        await tester.drag(list, const Offset(-3000, 0));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'columns-scrolled-right');
        expect(columnLabel(size, 'Done', 7), findsOneWidget);
        expect(card('Shipped 1'), findsOneWidget);
        expect(columnLabel(size, 'Triage', 3), findsNothing);
        await tester.drag(list, const Offset(3000, 0));
        await tester.pumpAndSettle();
        expect(columnLabel(size, 'Triage', 3), findsOneWidget);
      }

      await showColumn(tester, size, 'Todo');
      await shots.capture(tester, 'todo-long-titles');
      expect(card('Todo 3'), findsOneWidget);
      expect(card('Todo 5'), findsOneWidget);
      expect(
        card(
          'Write the rollout plan for the webhook signing migration '
          'and get every team to sign it off before Friday 4',
        ),
        findsOneWidget,
      );
      expect(columnLabel(size, 'Todo', 8), findsOneWidget);
      if (!wide(size)) {
        expect(chipSelected(tester, 'Todo', 8), isTrue);
        expect(card(richTitle), findsNothing);
      }

      await tapText(tester, find.widgetWithText(FilterChip, 'Archived'));
      await settleRestart(tester);
      // Switching it on asks the server for the archive too.
      expect(
        boardLoads().where(
          (r) => r.queryParameters['include_archived'] == true,
        ),
        hasLength(1),
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Archived'))
            .selected,
        isTrue,
      );
      await showColumn(tester, size, 'Archived');
      await shots.capture(tester, 'archived');
      expect(columnLabel(size, 'Archived', 2), findsOneWidget);
      expect(card('Retire the v1 webhook endpoints'), findsOneWidget);
      expect(card('Old spike'), findsOneWidget);
      expect(card('Todo 3'), findsNothing);
      await tapText(tester, find.widgetWithText(FilterChip, 'Archived'));
      await settleRestart(tester);
      // And off again: the archive is gone from the board.
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Archived'))
            .selected,
        isFalse,
      );
      expect(columnLabel(size, 'Archived', 2), findsNothing);
      expect(card('Retire the v1 webhook endpoints'), findsNothing);
      await showColumn(tester, size, 'Todo');
      expect(card('Todo 3'), findsOneWidget);

      await tester.tap(find.text('All assignees'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assignee-menu');
      // Everyone the board knows, after "All assignees".
      expect(find.text('All assignees'), findsNWidgets(2));
      for (final who in [
        'coder',
        'writer',
        'reviewer',
        'designer',
        'researcher',
        'planner',
        'tester',
      ]) {
        expect(find.text(who).hitTestable(), findsOneWidget, reason: who);
      }
      await tester.tap(find.text(opsAssignee).last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assignee-long-name');
      // The chip names who is picked, and only their tasks are left.
      expect(find.text('All assignees'), findsNothing);
      expect(find.widgetWithText(Chip, opsAssignee), findsOneWidget);
      expect(card(longTodoTitle), findsOneWidget);
      expect(card('Todo 3'), findsNothing);
      expect(columnLabel(size, 'Todo', 1), findsOneWidget);
      // Filtering by who is local: the board was not fetched again.
      expect(boardLoads(), hasLength(3));

      await tester.tap(find.text('All tenants'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'tenant-menu');
      expect(find.text('All tenants').hitTestable(), findsOneWidget);
      expect(find.text('acme').hitTestable(), findsOneWidget);
      expect(
        find.text('a-tenant-with-a-rather-long-name').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('acme').last);
      await settleRestart(tester);
      await shots.capture(tester, 'tenant-acme');
      // The server was asked for acme's board, and the chip says so.
      expect(
        boardLoads().where((r) => r.queryParameters['tenant'] == 'acme'),
        hasLength(1),
      );
      expect(find.widgetWithText(Chip, 'acme'), findsOneWidget);
      expect(find.text('All tenants'), findsNothing);
      // Only acme's tasks are left: none of them is a todo, and one running
      // task is also the picked assignee's.
      expect(columnLabel(size, 'Todo', 0), findsOneWidget);
      expect(card(longTodoTitle), findsNothing);

      // The search steps below look at running tasks: the todo column holds
      // none of acme's, so searching it would show an empty list whatever
      // the search finds.
      await tester.tap(find.widgetWithText(Chip, opsAssignee));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All assignees').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'All assignees'), findsOneWidget);
      await showColumn(tester, size, 'Running');
      expect(columnLabel(size, 'Running', 7), findsOneWidget);
      expect(card(richTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search-no-match');
      expect(find.byType(KanbanCard), findsNothing);
      expect(columnLabel(size, 'Running', 0), findsOneWidget);
      if (!wide(size)) expect(find.text('No tasks here'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'signing');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search-match');
      // Only the task with "signing" in its title is left.
      expect(find.byType(KanbanCard), findsOneWidget);
      expect(card(richTitle), findsOneWidget);
      expect(columnLabel(size, 'Running', 1), findsOneWidget);
      expect(find.text('No tasks here'), findsNothing);
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
      expect(isDark(tester), isTrue);
      expect(find.text('Kanban'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
      if (wide(size)) {
        expect(columnLabel(size, 'Triage', 3), findsOneWidget);
        expect(columnLabel(size, 'Todo', 8), findsOneWidget);
        expect(card('Triage item 1'), findsOneWidget);
      } else {
        expect(chipSelected(tester, 'Running', 14), isTrue);
        expect(card(richTitle), findsOneWidget);
        expect(inCard(richTitle, 'P2'), findsOneWidget);
      }
      await showColumn(tester, size, 'Todo');
      await shots.capture(tester, 'todo');
      expect(columnLabel(size, 'Todo', 8), findsOneWidget);
      expect(card('Todo 3'), findsOneWidget);
      expect(card('Todo 5'), findsOneWidget);
      if (!wide(size)) expect(chipSelected(tester, 'Todo', 8), isTrue);
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
      expect(isDark(tester), brightness == Brightness.dark);
      // Not selecting yet: the title and the new task button are there.
      expect(find.text('Kanban'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
      expect(find.byType(KanbanBulkBar), findsNothing);

      const cluster1 = 'Rotate staging certificates for cluster 1';
      if (wide(size)) {
        await openMoreMenu(tester, 'Select tasks');
      } else {
        await tester.longPress(find.text(cluster1));
        await tester.pumpAndSettle();
        // A long press picks the task and starts selecting.
        expect(find.text('1 selected'), findsOneWidget);
        expect(cardSelected(tester, cluster1), isTrue);
        // Picking the only task again leaves nothing selected.
        await tester.tap(find.text(cluster1));
        await tester.pumpAndSettle();
      }
      await shots.capture(tester, 'none-selected');
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Kanban'), findsNothing);
      expect(find.text('New task'), findsNothing);
      expect(find.byTooltip('Cancel selection'), findsOneWidget);
      expect(find.byType(KanbanBulkBar), findsOneWidget);
      // Nothing is picked, so no action can be started.
      for (final action in [
        'Move',
        'Assign',
        'Priority',
        'Effort',
        'Archive',
      ]) {
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, action))
              .onPressed,
          isNull,
          reason: action,
        );
      }
      expect(cardSelected(tester, cluster1), isFalse);

      for (final title in [
        find.textContaining('Migrate every outgoing'),
        find.textContaining('https://example.internal'),
        find.text(cluster1),
      ]) {
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await tester.tap(title);
        await tester.pumpAndSettle();
      }
      await shots.capture(tester, 'three-selected');
      expect(find.text('3 selected'), findsOneWidget);
      // The list builds only the cards near the last one tapped.
      expect(cardSelected(tester, cluster1), isTrue);
      expect(
        pickedCards(tester).map((c) => c.task.id),
        everyElement(isIn(['t_rich', 't_url', 't_run1'])),
      );
      for (final action in [
        'Move',
        'Assign',
        'Priority',
        'Effort',
        'Archive',
      ]) {
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, action))
              .onPressed,
          isNotNull,
          reason: action,
        );
      }
      // Nothing was sent yet: each action asks for its value first.
      expect(sent('POST', '/api/plugins/kanban/tasks/bulk'), isEmpty);

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-dialog');
      expect(find.text('Move to'), findsOneWidget);
      // The statuses a person may set, and not Running or Archived.
      expect(_choiceRows, findsNWidgets(7));
      for (final status in [
        'Triage',
        'Todo',
        'Scheduled',
        'Ready',
        'Blocked',
        'Review',
        'Done',
      ]) {
        expect(_choiceRow(status), findsOneWidget, reason: status);
      }
      await popRoute(tester);
      expect(find.text('Move to'), findsNothing);
      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assign-dialog');
      expect(find.text('Assign to'), findsOneWidget);
      // Nobody, then everyone the board knows.
      expect(_choiceRows, findsNWidgets(9));
      expect(_choiceRow('Nobody'), findsOneWidget);
      expect(_choiceRow('designer'), findsOneWidget);
      expect(_choiceRow(opsAssignee), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Assign to'), findsNothing);

      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'priority-dialog');
      expect(_choiceRows, findsNWidgets(4));
      for (final priority in ['Normal', 'P1', 'P2', 'P3']) {
        expect(_choiceRow(priority), findsOneWidget, reason: priority);
      }
      await popRoute(tester);
      expect(_choiceRows, findsNothing);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'archive-confirm');
      // It names how many tasks go, and asks before it does anything.
      expect(find.text('Archive 3 tasks?'), findsOneWidget);
      expect(find.byType(AppAlertDialog), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Archive 3 tasks?'), findsNothing);
      expect(sent('POST', '/api/plugins/kanban/tasks/bulk'), isEmpty);
      expect(find.text('3 selected'), findsOneWidget);

      final loadsBefore = boardLoads().length;
      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'partial-failure');
      // One request, for the three tasks, with the priority picked.
      final request = sent('POST', '/api/plugins/kanban/tasks/bulk').single;
      expect(bodyOf(request)['ids'], ['t_rich', 't_url', 't_run1']);
      expect(bodyOf(request)['priority'], 1);
      // The refusal is told, and only the refused task stays picked, so the
      // change can be tried again on it.
      expect(
        snack('1 of 3 could not be changed: illegal move: running -> ready'),
        findsOneWidget,
      );
      expect(find.text('1 selected'), findsOneWidget);
      expect(cardSelected(tester, cluster1), isFalse);
      expect(pickedCards(tester).map((c) => c.task.id), everyElement('t_url'));
      // The board is read again to show what went through.
      expect(boardLoads().length, greaterThan(loadsBefore));
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
      expect(find.text('Active workers'), findsOneWidget);
      expect(find.text('3 running'), findsOneWidget);
      expect(find.byType(KanbanWorkerRow), findsNWidgets(3));
      // Each worker names its task, the task id, the run and who runs it.
      expect(find.text('Migrate webhooks'), findsOneWidget);
      expect(find.text('t_rich · run #7 · coder'), findsOneWidget);
      expect(find.text(urlTitle), findsOneWidget);
      expect(
        find.text('t_url · run #8 · ops-assistant-with-a-long-name'),
        findsOneWidget,
      );
      // A worker the server names no profile for shows its assignee.
      expect(
        find.text('Rotate staging certificates for cluster 1'),
        findsOneWidget,
      );
      expect(find.text('t_run1 · run #9 · reviewer'), findsOneWidget);
      expect(find.text('No workers are running'), findsNothing);
      expect(sent('GET', '/api/plugins/kanban/workers/active'), hasLength(1));

      await tester.tap(find.byType(PopupMenuButton<RowAction>).first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'row-menu');
      expect(find.text('Inspect process'), findsOneWidget);
      expect(find.text('Terminate'), findsOneWidget);
      await tester.tap(find.text('Inspect process'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'inspect-figures');
      expect(sent('GET', '/api/plugins/kanban/runs/7/inspect'), hasLength(1));
      expect(find.text('Run #7'), findsOneWidget);
      expect(
        find.text('Process 4242\nStatus: sleeping\nMemory: 100 MB\nThreads: 9'),
        findsOneWidget,
      );
      await popRoute(tester);
      expect(find.text('Run #7'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<RowAction>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect process'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'inspect-gone');
      expect(sent('GET', '/api/plugins/kanban/runs/8/inspect'), hasLength(1));
      expect(find.text('Run #8'), findsOneWidget);
      expect(
        find.text('The process is not running: process not found.'),
        findsOneWidget,
      );
      await popRoute(tester);
      expect(find.text('Run #8'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<RowAction>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminate'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'terminate-confirm');
      // It asks first, naming the run.
      expect(find.text('Terminate run #7?'), findsOneWidget);
      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(sent('POST', '/api/plugins/kanban/runs/7/terminate'), isEmpty);
      await popRoute(tester);
      expect(find.text('Terminate run #7?'), findsNothing);
      // Cancelling stops nothing, and the worker stays listed.
      expect(sent('POST', '/api/plugins/kanban/runs/7/terminate'), isEmpty);
      expect(find.text('3 running'), findsOneWidget);

      server.on('GET', '/api/plugins/kanban/workers/active', {
        'detail': 'gateway timeout',
      }, status: 504);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'refresh-failed');
      // The refresh is said to have failed, and the list stays as it was.
      expect(snack('Could not refresh: gateway timeout'), findsOneWidget);
      expect(sent('GET', '/api/plugins/kanban/workers/active'), hasLength(2));
      expect(find.byType(KanbanWorkerRow), findsNWidgets(3));
      expect(find.text('3 running'), findsOneWidget);
      expect(find.text('Migrate webhooks'), findsOneWidget);
    });
  }

  testWidgets('phone: workers, empty and failing', (tester) async {
    final shots = ScreenshotRecorder('kanban-extras-workers-phone-states');
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pumpBoard(tester, shots, size: phoneSize);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'empty');
    expect(find.text('Active workers'), findsOneWidget);
    expect(find.text('No workers are running'), findsOneWidget);
    expect(find.text('0 running'), findsOneWidget);
    expect(find.byType(KanbanWorkerRow), findsNothing);

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'x',
    }, status: 500);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    // With nothing on screen to keep, a failed refresh is only told.
    expect(snack('Could not refresh: x'), findsOneWidget);
    expect(find.text('No workers are running'), findsOneWidget);
    await popRoute(tester);
    await letSnackBarsGo(tester);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'load-failed');
    // Opened afresh, the failure takes the page, with a way to try again.
    expect(find.text('x'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.text('No workers are running'), findsNothing);
    expect(find.text('0 running'), findsNothing);
    expect(sent('GET', '/api/plugins/kanban/workers/active'), hasLength(3));

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'board \'ops\' does not exist',
    }, status: 404);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'refused');
    // The server's own reason is shown, in place of the earlier one.
    expect(find.text('board \'ops\' does not exist'), findsOneWidget);
    expect(find.text('x'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(sent('GET', '/api/plugins/kanban/workers/active'), hasLength(4));
  });

  testWidgets('desktop: workers, empty and failing', (tester) async {
    final shots = ScreenshotRecorder('kanban-extras-workers-desktop-states');
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pumpBoard(tester, shots, size: desktopSize);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'empty');
    expect(find.text('Active workers'), findsOneWidget);
    expect(find.text('No workers are running'), findsOneWidget);
    expect(find.text('0 running'), findsOneWidget);
    expect(find.byType(KanbanWorkerRow), findsNothing);
    await popRoute(tester);
    expect(find.text('Active workers'), findsNothing);

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'x',
    }, status: 500);
    await openMoreMenu(tester, 'Active workers…');
    await shots.capture(tester, 'load-failed');
    expect(find.text('x'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.text('No workers are running'), findsNothing);
    expect(sent('GET', '/api/plugins/kanban/workers/active'), hasLength(2));
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
      Finder rowValue(String row, String value) => find.descendant(
        of: find.widgetWithText(GroupedMenuRow<String>, row),
        matching: find.text(value),
      );
      expect(find.text('Orchestration'), findsOneWidget);
      expect(sent('GET', '/api/plugins/kanban/orchestration'), hasLength(1));
      // The server's settings, as they are.
      expect(switchOn(tester, 'Auto-decompose triage tasks'), isTrue);
      expect(find.text('Off: decompose by hand'), findsOneWidget);
      expect(switchOn(tester, 'Promote children when ready'), isFalse);
      expect(rowValue('Orchestrator profile', opsAssignee), findsOneWidget);
      expect(
        rowValue('Default assignee', 'Active profile (default)'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.text('Could not load the settings'), findsNothing);
      expect(sent('PUT', '/api/plugins/kanban/orchestration'), isEmpty);

      await tester.tap(find.text('Default assignee'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profile-menu');
      // The active profile, then every profile the board knows.
      expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(5));
      for (final name in [
        'Active profile (default)',
        'coder',
        'writer',
        opsAssignee,
        'reviewer',
      ]) {
        expect(
          find.widgetWithText(CheckedPopupMenuItem<String>, name),
          findsOneWidget,
          reason: name,
        );
      }
      expect(
        tester
            .widget<CheckedPopupMenuItem<String>>(
              find.widgetWithText(
                CheckedPopupMenuItem<String>,
                'Active profile (default)',
              ),
            )
            .checked,
        isTrue,
      );
      expect(
        tester
            .widget<CheckedPopupMenuItem<String>>(
              find.widgetWithText(CheckedPopupMenuItem<String>, 'reviewer'),
            )
            .checked,
        isFalse,
      );
      final option = find.text('reviewer').last;
      final entry = find.ancestor(
        of: option,
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem,
        ),
      );
      await tester.tap(entry.evaluate().isEmpty ? option : entry.first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profile-picked');
      // The menu closed and the row shows the pick; nothing was saved yet.
      expect(find.byType(CheckedPopupMenuItem<String>), findsNothing);
      expect(rowValue('Default assignee', 'reviewer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(GroupedMenuRow<String>, 'Default assignee'),
          matching: find.text('Active profile (default)'),
        ),
        findsNothing,
      );
      expect(sent('PUT', '/api/plugins/kanban/orchestration'), isEmpty);

      await tester.tap(find.text('Promote children when ready'));
      await tester.pumpAndSettle();
      expect(switchOn(tester, 'Promote children when ready'), isTrue);
      expect(switchOn(tester, 'Auto-decompose triage tasks'), isTrue);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-refused');
      final put = sent('PUT', '/api/plugins/kanban/orchestration').single;
      expect(bodyOf(put)['default_assignee'], 'reviewer');
      // Only what changed is sent.
      expect(bodyOf(put)['auto_promote_children'], isTrue);
      expect(bodyOf(put).containsKey('orchestrator_profile'), isFalse);
      expect(bodyOf(put).containsKey('auto_decompose'), isFalse);
      // The server's reason is told, and the dialog stays open with the
      // choices so they can be fixed.
      expect(snack('unknown profile'), findsOneWidget);
      expect(find.text('Orchestration'), findsOneWidget);
      expect(rowValue('Default assignee', 'reviewer'), findsOneWidget);
      expect(switchOn(tester, 'Promote children when ready'), isTrue);
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
    expect(find.text('Orchestration'), findsOneWidget);
    expect(find.text('Could not load the settings'), findsOneWidget);
    expect(sent('GET', '/api/plugins/kanban/orchestration'), hasLength(1));
    // There is nothing to edit, and so nothing to save.
    expect(find.byType(GroupedSwitchRow), findsNothing);
    expect(find.byType(GroupedMenuRow<String>), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
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
      expect(isDark(tester), brightness == Brightness.dark);
      await tester.tap(find.byTooltip('Switch board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switch-menu');
      // Every board with its task count, the open one checked.
      expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(14));
      expect(
        tester
            .widget<CheckedPopupMenuItem<String>>(
              find.widgetWithText(CheckedPopupMenuItem<String>, 'Default (40)'),
            )
            .checked,
        isTrue,
      );
      expect(
        tester
            .widget<CheckedPopupMenuItem<String>>(
              find.widgetWithText(CheckedPopupMenuItem<String>, 'Team 1 (1)'),
            )
            .checked,
        isFalse,
      );
      expect(
        find.textContaining('Operations and infrastructure'),
        findsOneWidget,
      );
      expect(find.text('Manage boards…'), findsOneWidget);
      await tester.ensureVisible(find.text('Manage boards…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage boards…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list');
      expect(find.byType(CheckedPopupMenuItem<String>), findsNothing);
      expect(find.text('Boards'), findsOneWidget);
      expect(find.text('14 boards'), findsOneWidget);
      expect(find.byType(KanbanBoardsScreen), findsOneWidget);
      // The open board is marked, and only that one.
      expect(
        find.descendant(
          of: find.widgetWithText(KanbanBoardRow, 'Default'),
          matching: find.text('Current'),
        ),
        findsOneWidget,
      );
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('default · 40 tasks'), findsOneWidget);
      expect(find.text('ops · 2 tasks'), findsOneWidget);
      expect(
        find.text(
          'Operations and infrastructure for the whole platform '
          'engineering organisation',
        ),
        findsOneWidget,
      );
      expect(sent('GET', '/api/plugins/kanban/boards'), hasLength(1));

      final screen = find.byType(KanbanBoardsScreen);
      final list = find.descendant(of: screen, matching: find.byType(ListView));
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list-bottom');
      expect(find.text('Team 12'), findsOneWidget);
      expect(find.text('team-12 · 12 tasks'), findsOneWidget);
      await tester.drag(list, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);

      Future<void> rowMenu(String item) async {
        await tester.tap(
          find
              .descendant(
                of: screen,
                matching: find.byType(PopupMenuButton<RowAction>),
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
              matching: find.byType(PopupMenuButton<RowAction>),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'row-menu');
      // There is more than one board, so each can be archived or deleted.
      for (final action in ['Rename', 'Export…', 'Archive', 'Delete']) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
      await popRoute(tester);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Export…'), findsNothing);

      await tester.tap(find.byTooltip('New board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board');
      expect(find.text('New board'), findsOneWidget);
      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Create'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Cancel'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Quarterly launch planning for the whole company',
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board-long-name');
      expect(
        find.text('Quarterly launch planning for the whole company'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '日本語');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'new-board-invalid');
      // A name with no letters or numbers makes no slug: it is told, and
      // nothing is sent.
      expect(
        snack('Use letters or numbers in the board name.'),
        findsOneWidget,
      );
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(sent('POST', '/api/plugins/kanban/boards'), isEmpty);
      await letSnackBarsGo(tester);

      await rowMenu('Rename');
      await shots.capture(tester, 'rename');
      expect(find.text('Rename board'), findsOneWidget);
      // It starts from the board's own name.
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(AppAlertDialog),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'Default',
      );
      expect(find.widgetWithText(AppDialogAction, 'Rename'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Rename board'), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/boards/default'), isEmpty);

      await rowMenu('Archive');
      await shots.capture(tester, 'archive-confirm');
      expect(find.text('Archive “Default”?'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Archive “Default”?'), findsNothing);
      expect(sent('DELETE', '/api/plugins/kanban/boards/default'), isEmpty);

      await rowMenu('Delete');
      await shots.capture(tester, 'delete-confirm');
      expect(find.text('Delete “Default” for good?'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Delete “Default” for good?'), findsNothing);
      expect(sent('DELETE', '/api/plugins/kanban/boards/default'), isEmpty);

      await rowMenu('Export…');
      await shots.capture(tester, 'export');
      expect(find.text('Export Default'), findsOneWidget);
      expect(find.text('Server path'), findsOneWidget);
      expect(
        find.textContaining('The archive is written on the server'),
        findsOneWidget,
      );
      // Attachments go along, worker logs do not, unless asked.
      expect(switchOn(tester, 'Include attachments'), isTrue);
      expect(switchOn(tester, 'Include worker logs'), isFalse);
      expect(
        sent('POST', '/api/plugins/kanban/boards/default/export'),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'exported');
      final export = sent(
        'POST',
        '/api/plugins/kanban/boards/default/export',
      ).single;
      expect(bodyOf(export)['output'], '');
      expect(bodyOf(export)['attachments'], isTrue);
      expect(bodyOf(export)['logs'], isFalse);
      expect(find.text('Board exported'), findsOneWidget);
      expect(find.text('The archive is on the server, at:'), findsOneWidget);
      expect(
        find.text('/srv/hermes/exports/default-2026-09-20-final-export.tar.gz'),
        findsOneWidget,
      );
      expect(find.text('3.0 KB'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Board exported'), findsNothing);

      await tester.tap(find.byTooltip('Import a board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'import');
      expect(find.text('Import a board'), findsOneWidget);
      expect(
        find.text('The archive must already be on the server.'),
        findsOneWidget,
      );
      // Nothing to import until an archive is named; opening it after is on.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
            .onPressed,
        isNull,
      );
      expect(switchOn(tester, 'Open it afterwards'), isTrue);
      await tester.enterText(
        find.widgetWithText(TextField, 'Archive path'),
        '/srv/hermes/exports/missing.tar.gz',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'import-refused');
      final import = sent('POST', '/api/plugins/kanban/boards/import').single;
      expect(bodyOf(import)['archive'], '/srv/hermes/exports/missing.tar.gz');
      // The server's reason is told; the boards stay as they were.
      expect(
        snack('archive not found: /srv/hermes/exports/missing.tar.gz'),
        findsOneWidget,
      );
      expect(find.text('Import a board'), findsNothing);
      expect(find.text('Boards'), findsOneWidget);
      expect(find.text('14 boards'), findsOneWidget);
      expect(sent('GET', '/api/plugins/kanban/boards'), hasLength(1));
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
      expect(isDark(tester), brightness == Brightness.dark);
      await tester.tap(find.textContaining('Migrate every outgoing'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'top');
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich'), hasLength(1));
      // The task: its id and status, its title, who has it, how urgent.
      expect(inPanel('t_rich · Running'), findsOneWidget);
      expect(inPanel(richTitle), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      Finder valueRow(String row, String value) => find.descendant(
        of: find.widgetWithText(GroupedValueRow, row),
        matching: find.text(value),
      );
      expect(valueRow('Assignee', 'coder'), findsOneWidget);
      expect(valueRow('Priority', 'P2'), findsOneWidget);
      expect(valueRow('Tenant', 'acme'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(GroupedMenuRow<String>, 'Move to…'),
          matching: find.text('Running'),
        ),
        findsOneWidget,
      );
      // A running task can be reclaimed, completed or blocked, not decomposed.
      expect(inPanel('Reclaim'), findsOneWidget);
      expect(inPanel('Complete'), findsOneWidget);
      expect(inPanel('Block'), findsOneWidget);
      expect(inPanel('Estimate'), findsOneWidget);
      expect(inPanel('Decompose'), findsNothing);
      expect(inPanel('Specify'), findsNothing);
      // What needs attention comes first, with the detail where there is one.
      expect(inPanel('Worker stalled'), findsOneWidget);
      expect(
        inPanel('No heartbeat for 10m. The process may be hung on a lock.'),
        findsOneWidget,
      );
      expect(inPanel('Two parents are still open'), findsOneWidget);
      expect(
        find.textContaining('Move every outgoing webhook to'),
        findsOneWidget,
      );
      expect(inPanel('Could not load the task'), findsNothing);

      await pageThrough(tester, shots, 'scroll');
      // The foot of the panel: its runs and history, and archive and delete.
      await tester.scrollUntilVisible(
        find.text('Delete'),
        300,
        scrollable: panelScrollable(),
      );
      expect(inPanel('Archive'), findsOneWidget);
      expect(inPanel('Delete'), findsOneWidget);
      expect(inPanel('History'), findsOneWidget);
      expect(find.textContaining('Runs ('), findsOneWidget);
      expect(inPanel('Attach file'), findsOneWidget);
      // The runs and the log are folded away until asked for.
      expect(inPanel('Worker log'), findsNothing);
      expect(inPanel('created'), findsNothing);

      await tapText(tester, find.textContaining('Runs ('));
      await shots.capture(tester, 'runs-open');
      expect(inPanel('#7 · coder · running'), findsOneWidget);
      expect(
        inPanel('#6 · ops-assistant-with-a-long-name · crashed'),
        findsOneWidget,
      );
      expect(inPanel('#5 · coder · completed'), findsOneWidget);
      expect(
        inPanel('Worker exited with code 137 (out of memory) after 12 seconds'),
        findsOneWidget,
      );
      expect(inPanel('Finished endpoint 1'), findsOneWidget);
      // Newest first, and only the run in flight can be terminated.
      expect(
        tester.getTopLeft(find.text('#7 · coder · running')).dy,
        lessThan(tester.getTopLeft(find.text('#5 · coder · completed')).dy),
      );
      expect(inPanel('Terminate'), findsOneWidget);
      expect(inPanel('Worker log'), findsOneWidget);
      await tapText(tester, find.text('History'));
      await pageThrough(tester, shots, 'history');
      await tester.scrollUntilVisible(
        find.text('created'),
        300,
        scrollable: panelScrollable(),
      );
      expect(inPanel('created'), findsOneWidget);
      expect(inPanel('heartbeat missed'), findsOneWidget);
      expect(inPanel('reclaimed'), findsOneWidget);
      expect(inPanel('commented'), findsOneWidget);
      expect(inPanel('claimed'), findsNWidgets(2));
      // The last thing that happened is the first thing listed.
      expect(
        tester.getTopLeft(find.text('commented')).dy,
        lessThan(tester.getTopLeft(find.text('created')).dy),
      );

      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'log-none');
      expect(find.text('Log · t_rich'), findsOneWidget);
      expect(find.text('No worker has run this task yet.'), findsOneWidget);
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich/log'), hasLength(1));
      await popRoute(tester);
      expect(find.text('Log · t_rich'), findsNothing);

      await panelToTop(tester);
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_rich/estimate'),
        isEmpty,
      );
      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'estimate');
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_rich/estimate'),
        hasLength(1),
      );
      // The size, and the reasoning behind it.
      expect(find.text('about 240k tokens · XL'), findsOneWidget);
      expect(
        find.text(
          'Touches every outgoing integration and needs a migration '
          'window, so it is broad and ambiguous.',
        ),
        findsOneWidget,
      );

      Finder field(String label) => find.descendant(
        of: find.widgetWithText(GroupedTextFieldRow, label),
        matching: find.byType(EditableText),
      );
      String fieldText(WidgetTester tester, String label) =>
          tester.widget<EditableText>(field(label)).controller.text;
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'edit-dialog');
      expect(find.text('Edit task'), findsOneWidget);
      // The dialog starts from the task as it is.
      expect(fieldText(tester, 'Title'), richTitle);
      expect(
        fieldText(tester, 'Description'),
        startsWith('Move every outgoing webhook to **v2 signing**.'),
      );
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      await tester.enterText(
        field('Title'),
        'A much longer replacement title that keeps going for two lines',
      );
      await tester.enterText(
        field('Description'),
        List.generate(
          10,
          (i) => 'Line ${i + 1} of the description, which is fairly long.',
        ).join('\n'),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'edit-dialog-filled');
      expect(
        fieldText(tester, 'Title'),
        'A much longer replacement title that keeps going for two lines',
      );
      expect(
        fieldText(tester, 'Description'),
        startsWith('Line 1 of the description, which is fairly long.\nLine 2'),
      );
      expect(fieldText(tester, 'Description'), contains('Line 10 of the'));
      await popRoute(tester);
      // Cancelled: nothing was sent, and the task keeps its title.
      expect(find.text('Edit task'), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);
      expect(inPanel(richTitle), findsOneWidget);

      await tester.tap(find.widgetWithText(GroupedValueRow, 'Assignee'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'assign-dialog');
      expect(find.text('Assign to'), findsOneWidget);
      // Nobody, then everyone the board knows, with the task's own marked.
      expect(find.byType(GroupedChoiceRow<String>), findsNWidgets(5));
      for (final who in [
        'Nobody',
        'coder',
        'writer',
        opsAssignee,
        'reviewer',
      ]) {
        expect(
          find.widgetWithText(GroupedChoiceRow<String>, who),
          findsOneWidget,
          reason: who,
        );
      }
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'coder',
      );
      await popRoute(tester);
      expect(find.text('Assign to'), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);

      await tester.tap(find.widgetWithText(GroupedValueRow, 'Priority'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'priority-dialog');
      expect(find.byType(GroupedChoiceRow<int>), findsNWidgets(4));
      for (final priority in ['Normal', 'P1', 'P2', 'P3']) {
        expect(
          find.widgetWithText(GroupedChoiceRow<int>, priority),
          findsOneWidget,
          reason: priority,
        );
      }
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        2,
      );
      await popRoute(tester);
      expect(find.byType(GroupedChoiceRow<int>), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);

      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-menu');
      // Every status a person may set, and not the one it is in.
      for (final status in [
        'Triage',
        'Todo',
        'Scheduled',
        'Ready',
        'Blocked',
        'Review',
        'Done',
      ]) {
        expect(find.text(status), findsOneWidget, reason: status);
      }
      expect(inPanel('Running'), findsOneWidget);
      if (workflowPlatform == TargetPlatform.iOS) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      } else {
        await popRoute(tester);
      }
      expect(find.text('Triage'), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'result-dialog');
      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('Optional — what came out of it'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Complete'), findsOneWidget);
      await popRoute(tester);
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'block-dialog');
      expect(find.text('Why is it blocked?'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Block'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Why is it blocked?'), findsNothing);
      expect(sent('PATCH', '/api/plugins/kanban/tasks/t_rich'), isEmpty);

      await tester.tap(find.text('Reclaim'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'reclaim-confirm');
      expect(
        find.text('Release the worker’s claim on this task?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppDialogAction, 'Reclaim'), findsOneWidget);
      await popRoute(tester);
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(sent('POST', '/api/plugins/kanban/tasks/t_rich/reclaim'), isEmpty);

      await tapText(tester, find.widgetWithText(GroupedRow, 'Add'));
      await shots.capture(tester, 'depends-on-dialog');
      expect(
        find.descendant(
          of: find.byType(AppAlertDialog),
          matching: find.text('Depends on'),
        ),
        findsOneWidget,
      );
      expect(find.text('Task id, e.g. t_1a2b'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Add'), findsOneWidget);
      await popRoute(tester);
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(sent('POST', '/api/plugins/kanban/links'), isEmpty);

      server.on('PATCH', '/api/plugins/kanban/tasks/t_rich', {
        'detail': 'Cannot move to ready: 2 parents are still open',
      }, status: 409);
      await panelToTop(tester);
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      await tester.tap(
        workflowPlatform == TargetPlatform.iOS
            ? find.text('Ready').last
            : find.widgetWithText(CheckedPopupMenuItem<String>, 'Ready'),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'move-refused');
      // The one change that was sent, and why the server refused it.
      final move = sent('PATCH', '/api/plugins/kanban/tasks/t_rich').single;
      expect(bodyOf(move)['status'], 'ready');
      expect(
        snack('Cannot move to ready: 2 parents are still open'),
        findsOneWidget,
      );
      // The task is still where it was.
      expect(inPanel('t_rich · Running'), findsOneWidget);
      expect(inPanel('Ready'), findsNothing);
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

      const longAttachment =
          'a-really-long-attachment-name-from-the-design-review-final-v3-'
          'FINAL-copy.pdf';
      await tapText(
        tester,
        find.textContaining(RegExp(r'^attachments$', caseSensitive: false)),
      );
      await shots.capture(tester, 'attachments');
      // Every attachment with its size, each to save or remove, and a way to
      // add another.
      for (final (file, size) in [
        ('spec.pdf', '2.0 KB'),
        (longAttachment, '5.0 MB'),
        ('notes.txt', '12 B'),
        ('screenshot.png', '341.8 KB'),
      ]) {
        expect(inPanel(file), findsOneWidget, reason: file);
        expect(
          find.descendant(
            of: find.widgetWithText(KanbanAttachmentRow, file),
            matching: find.text(size),
          ),
          findsOneWidget,
          reason: '$file is $size',
        );
      }
      expect(find.byTooltip('Save attachment'), findsNWidgets(4));
      expect(find.byTooltip('Remove attachment'), findsNWidgets(4));
      expect(inPanel('Attach file'), findsOneWidget);

      await tapText(tester, find.byTooltip('Save attachment').at(1));
      await shots.capture(tester, 'download-failed');
      // The file of the second attachment was asked for, was not there, and
      // the server's reason is told. Nothing was saved.
      expect(sent('GET', '/api/plugins/kanban/attachments/2'), hasLength(1));
      expect(snack('attachment file missing on disk'), findsOneWidget);
      expect(files.saved, isEmpty);
      expect(find.textContaining('Saved '), findsNothing);
      await letSnackBarsGo(tester);

      expect(files.pickCalls, 0);
      await tapText(tester, find.text('Attach file'));
      await shots.capture(tester, 'attach-failed');
      // A file the picker refused is not uploaded, and why is told.
      expect(files.pickCalls, 1);
      expect(
        snack('notes.txt is over the 25 MB limit for attachments.'),
        findsOneWidget,
      );
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_rich/attachments'),
        isEmpty,
      );
      expect(inPanel('Attach file'), findsOneWidget);
      await letSnackBarsGo(tester);

      await tapText(tester, find.byTooltip('Remove attachment').at(1));
      await shots.capture(tester, 'remove-confirm');
      // It names the file, and asks before removing it.
      expect(find.text('Remove $longAttachment?'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Remove'), findsOneWidget);
      expect(sent('DELETE', '/api/plugins/kanban/attachments/2'), isEmpty);
      await popRoute(tester);
      expect(find.text('Remove $longAttachment?'), findsNothing);
      expect(sent('DELETE', '/api/plugins/kanban/attachments/2'), isEmpty);
      expect(inPanel(longAttachment), findsOneWidget);

      await tapText(tester, find.text('Archive'));
      await shots.capture(tester, 'archive-confirm');
      expect(find.text('Archive this task?'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Archive'), findsOneWidget);
      await popRoute(tester);
      expect(find.text('Archive this task?'), findsNothing);
      expect(sent('POST', '/api/plugins/kanban/tasks/bulk'), isEmpty);
      expect(find.byType(KanbanTaskPanel), findsOneWidget);
      await tapText(tester, find.text('Delete'));
      await shots.capture(tester, 'delete-confirm');
      expect(find.text('Delete this task for good?'), findsOneWidget);
      expect(find.widgetWithText(AppDialogAction, 'Delete'), findsOneWidget);
      // Asked, not done: nothing was deleted.
      expect(sent('DELETE', '/api/plugins/kanban/tasks/t_rich'), isEmpty);
      expect(find.byType(KanbanTaskPanel), findsOneWidget);
    });

    testWidgets('$name: task worker log', (tester) async {
      final shots = ScreenshotRecorder('kanban-extras-log-$name');
      await pumpBoard(tester, shots, size: size);
      await tester.tap(find.textContaining('Migrate every outgoing'));
      await tester.pumpAndSettle();
      await tapText(tester, find.textContaining('Runs ('));
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich/log'), isEmpty);

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
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich/log'), hasLength(1));
      expect(find.text('Log · t_rich'), findsOneWidget);
      // The log is cut at its start, which it says, and ends where the
      // worker is.
      expect(find.textContaining('… (earlier output cut)\n'), findsOneWidget);
      expect(find.textContaining('step 1 of 60'), findsOneWidget);
      expect(
        find.textContaining('step 60 of 60: talking to the endpoint'),
        findsOneWidget,
      );
      expect(
        find.textContaining('a-very-long-log-line-without-any-spaces-'),
        findsOneWidget,
      );
      expect(find.text('No worker has run this task yet.'), findsNothing);
      expect(find.text('(empty)'), findsNothing);
      await popRoute(tester);
      expect(find.text('Log · t_rich'), findsNothing);

      server.on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'exists': true,
        'content': '',
      });
      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'empty-log');
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich/log'), hasLength(2));
      expect(find.text('Log · t_rich'), findsOneWidget);
      expect(find.text('(empty)'), findsOneWidget);
      expect(find.textContaining('earlier output cut'), findsNothing);
      expect(find.textContaining('step 60 of 60'), findsNothing);
      await popRoute(tester);
      expect(find.text('Log · t_rich'), findsNothing);

      server.on('GET', '/api/plugins/kanban/tasks/t_rich/log', {
        'detail': 'x',
      }, status: 500);
      await tapText(tester, find.text('Worker log'));
      await shots.capture(tester, 'log-failed');
      expect(sent('GET', '/api/plugins/kanban/tasks/t_rich/log'), hasLength(3));
      expect(find.text('Log · t_rich'), findsOneWidget);
      expect(find.text('Could not load the log.'), findsOneWidget);
      expect(find.text('(empty)'), findsNothing);
      expect(find.text('Loading…'), findsNothing);
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
      expect(inPanel('t_tri1 · Triage'), findsOneWidget);
      expect(inPanel('Triage item 1'), findsOneWidget);
      // A triage task can be decomposed or specified, and has no worker to
      // reclaim.
      expect(inPanel('Decompose'), findsOneWidget);
      expect(inPanel('Specify'), findsOneWidget);
      expect(inPanel('Complete'), findsOneWidget);
      expect(inPanel('Block'), findsOneWidget);
      expect(inPanel('Reclaim'), findsNothing);
      expect(valueRowText(tester, 'Assignee'), 'Unassigned');
      expect(valueRowText(tester, 'Priority'), 'Normal');
      expect(find.widgetWithText(GroupedValueRow, 'Tenant'), findsNothing);

      await tester.tap(find.text('Specify'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'specify-declined');
      // The server answered "not done", with a reason, which is told.
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_tri1/specify'),
        hasLength(1),
      );
      expect(snack('No auxiliary model configured'), findsOneWidget);
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_tri1/decompose'),
        isEmpty,
      );
      expect(inPanel('t_tri1 · Triage'), findsOneWidget);
      // The next message waits behind this one; let it go first.
      await letSnackBarsGo(tester);
      final loadsBefore = boardLoads().length;
      await tester.tap(find.text('Decompose'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'decomposed');
      expect(
        sent('POST', '/api/plugins/kanban/tasks/t_tri1/decompose'),
        hasLength(1),
      );
      expect(snack('Decomposed into 2 tasks'), findsOneWidget);
      expect(snack('No auxiliary model configured'), findsNothing);
      // The board is read again to show the new tasks.
      expect(boardLoads().length, greaterThan(loadsBefore));
      await popRoute(tester);
      expect(find.byType(KanbanTaskPanel), findsNothing);
      await letSnackBarsGo(tester);

      await showColumn(tester, size, 'Done');
      await tester.tap(find.text('Ship v0.14 with the new signing'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'done-with-result');
      expect(inPanel('t_done_result · Done'), findsOneWidget);
      expect(inPanel('Ship v0.14 with the new signing'), findsOneWidget);
      expect(
        inPanel(
          'Shipped on Tuesday. Two follow-ups were filed, one for the '
          'retry queue and one for the docs.',
        ),
        findsOneWidget,
      );
      // Done: nothing is left to start, so there are no actions.
      expect(inPanel('Complete'), findsNothing);
      expect(inPanel('Block'), findsNothing);
      expect(inPanel('Decompose'), findsNothing);
      expect(valueRowText(tester, 'Assignee'), 'writer');
      await tester.scrollUntilVisible(
        find.text('Cut the release branch'),
        300,
        scrollable: panelScrollable(),
      );
      // The tasks it was split into, with how each ended.
      expect(
        inPanel('t_c1 · Done\nBranch cut from main at 4f2a91c'),
        findsOneWidget,
      );
      expect(inPanel('Publish the notes'), findsOneWidget);
      expect(inPanel('t_c2 · Done'), findsOneWidget);
      await popRoute(tester);
      expect(find.byType(KanbanTaskPanel), findsNothing);

      await showColumn(tester, size, 'Review');
      await tester.tap(find.text('A task whose details fail to load'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'load-failed');
      expect(sent('GET', '/api/plugins/kanban/tasks/t_broken'), hasLength(1));
      // No half-drawn task: the failure, and a way to try again.
      expect(find.text('Could not load the task'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(inPanel('Actions'), findsNothing);
      expect(inPanel('Complete'), findsNothing);
      expect(inPanel('Archive'), findsNothing);
    });
  }

  testWidgets('phone: board that failed to refresh keeps its notice', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('kanban-extras-board-phone-stale');
    await pumpBoard(tester, shots, size: phoneSize);
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    expect(boardLoads(), hasLength(1));
    expect(
      find.text('Could not refresh. Showing the last board.'),
      findsNothing,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, 400));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'refresh-failed');
    // Pulling down read the board again; it failed, which is said above the
    // board, and the board shown stays as it was.
    expect(boardLoads(), hasLength(2));
    expect(
      find.text('Could not refresh. Showing the last board.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(chipSelected(tester, 'Running', 14), isTrue);
    expect(card(richTitle), findsOneWidget);
    expect(find.text('Could not load the board'), findsNothing);
  });
}
