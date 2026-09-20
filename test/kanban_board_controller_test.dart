import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late KanbanBoardController controller;
  late List<({int since, String? board})> connects;
  late List<StreamChannelController<String>> sockets;

  Map<String, Object?> frame(int cursor, {bool events = true}) => {
    'cursor': cursor,
    'events': [
      if (events) {'id': cursor, 'task_id': 't1', 'kind': 'status'},
    ],
  };

  void serveBoard(List<Map<String, Object?>> tasks, {int latest = 0}) =>
      server.on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody(tasks, latestEventId: latest),
      );

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 2, current: true),
          (slug: 'ops', name: 'Ops', total: 0, current: false),
        ]),
      );
    connects = [];
    sockets = [];
    controller = KanbanBoardController(
      repository: KanbanRepository(server.client().raw),
      connect: ({required since, board}) async {
        connects.add((since: since, board: board));
        final socket = StreamChannelController<String>();
        sockets.add(socket);
        return socket.foreign;
      },
      debounce: Duration.zero,
      reconnectDelay: (_) => Duration.zero,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test(
    'loads the board and the board list, and starts the stream after it',
    () async {
      serveBoard([
        kanbanTaskRow(id: 't1', status: 'running', assignee: 'coder'),
        kanbanTaskRow(id: 't2', status: 'done'),
      ], latest: 7);

      await controller.start();
      await settle();

      expect(controller.board!.taskCount, 2);
      expect(controller.boards.map((b) => b.slug), ['default', 'ops']);
      expect(controller.boardSlug, 'default');
      expect(connects.single.since, 7);
      expect(controller.live, isTrue);
    },
  );

  test(
    'refetches once per burst of events and resumes from the cursor',
    () async {
      serveBoard([kanbanTaskRow(id: 't1', status: 'todo')], latest: 1);
      await controller.start();
      expect(
        server.requestsTo('GET', '/api/plugins/kanban/board'),
        hasLength(1),
      );

      serveBoard([kanbanTaskRow(id: 't1', status: 'running')], latest: 3);
      sockets.single.local.sink
        ..add(jsonEncode(frame(2)))
        ..add(jsonEncode(frame(3)));
      await settle();

      expect(
        server.requestsTo('GET', '/api/plugins/kanban/board'),
        hasLength(2),
      );
      expect(
        controller.board!.columns.firstWhere((c) => c.name == 'running').tasks,
        hasLength(1),
      );
    },
  );

  test('does not refetch for a frame without events', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();

    sockets.single.local.sink.add(jsonEncode(frame(5, events: false)));
    await settle();

    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), hasLength(1));
  });

  test('reconnects after the stream drops, from the last cursor', () async {
    serveBoard([kanbanTaskRow(id: 't1')], latest: 1);
    await controller.start();
    sockets.single.local.sink.add(jsonEncode(frame(9, events: false)));
    await settle();

    await sockets.single.local.sink.close();
    await settle();

    expect(connects, hasLength(2));
    expect(connects.last.since, 9);
    expect(controller.live, isTrue);
  });

  test('filters by search text and assignee without refetching', () async {
    serveBoard([
      kanbanTaskRow(id: 't1', title: 'Fix login', assignee: 'coder'),
      kanbanTaskRow(id: 't2', title: 'Write docs', assignee: 'writer'),
    ]);
    await controller.start();

    int count() => controller.columns.fold(0, (n, c) => n + c.tasks.length);
    controller.setQuery('login');
    expect(count(), 1);
    controller.setQuery('');
    controller.setAssignee('writer');
    expect(count(), 1);
    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), hasLength(1));
  });

  test('switching board reloads it and reopens the stream for it', () async {
    serveBoard([kanbanTaskRow(id: 't1')], latest: 4);
    await controller.start();

    await controller.selectBoard('ops');

    final last = server.requestsTo('GET', '/api/plugins/kanban/board').last;
    expect(last.queryParameters['board'], 'ops');
    expect(connects.last.board, 'ops');
  });

  test('archived and tenant filters go to the server', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();

    await controller.setIncludeArchived(true);
    await controller.setTenant('acme');

    final query = server
        .requestsTo('GET', '/api/plugins/kanban/board')
        .last
        .queryParameters;
    expect(query['include_archived'], true);
    expect(query['tenant'], 'acme');
  });

  test('a 404 means the plugin was turned off', () async {
    server.on('GET', '/api/plugins/kanban/board', {
      'detail': 'nope',
    }, status: 404);

    await controller.start();

    expect(controller.board, isNull);
    expect(controller.unavailable, isTrue);
    expect(connects, isEmpty);
  });

  test('a failed refresh keeps the board that was showing', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await controller.refresh();

    expect(controller.board, isNotNull);
    expect(controller.error, isNotNull);
  });

  test('drops selected tasks that left the board', () async {
    serveBoard([kanbanTaskRow(id: 't1'), kanbanTaskRow(id: 't2')]);
    await controller.start();
    controller
      ..startSelecting('t1')
      ..toggleSelected('t2');
    expect(controller.selected, {'t1', 't2'});

    serveBoard([kanbanTaskRow(id: 't2')]);
    await controller.refresh();

    expect(controller.selected, {'t2'});
    controller.stopSelecting();
    expect(controller.selecting, isFalse);
    expect(controller.selected, isEmpty);
  });

  group('remembering the board', () {
    late SharedPreferencesAsync prefs;

    KanbanBoardController withPrefs() => KanbanBoardController(
      repository: KanbanRepository(server.client().raw),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
      prefs: prefs,
    );

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = SharedPreferencesAsync();
      serveBoard([kanbanTaskRow(id: 't1')]);
    });

    test('opens the board chosen last time', () async {
      final first = withPrefs();
      await first.start();
      await first.selectBoard('ops');
      first.dispose();

      final second = withPrefs();
      await second.start();

      expect(second.boardSlug, 'ops');
      expect(
        server
            .requestsTo('GET', '/api/plugins/kanban/board')
            .last
            .queryParameters['board'],
        'ops',
      );
      second.dispose();
    });

    test(
      'falls back to the current board when the saved one is gone',
      () async {
        await prefs.setString('hermes.kanban.board', 'archived-long-ago');
        final c = withPrefs();

        await c.start();

        expect(c.boardSlug, 'default');
        c.dispose();
      },
    );

    test('moves off a board that was removed', () async {
      final c = withPrefs();
      await c.start();
      await c.selectBoard('ops');
      server.on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 2, current: true),
        ]),
      );

      await c.loadBoards();

      expect(c.boardSlug, 'default');
      c.dispose();
    });
  });

  test('remembers the chosen board and reopens it next time', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    KanbanBoardController build() => KanbanBoardController(
      repository: KanbanRepository(server.client().raw),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
      prefs: prefs,
    );
    serveBoard([kanbanTaskRow(id: 't1')]);

    final first = build();
    await first.start();
    await first.selectBoard('ops');
    first.dispose();

    final second = build();
    addTearDown(second.dispose);
    await second.start();

    expect(second.boardSlug, 'ops');
  });

  test(
    'falls back to the current board when the remembered one is gone',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'hermes.kanban.board': 'gone',
          });
      serveBoard([kanbanTaskRow(id: 't1')]);
      final c = KanbanBoardController(
        repository: KanbanRepository(server.client().raw),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
        prefs: SharedPreferencesAsync(),
      );
      addTearDown(c.dispose);

      await c.start();

      expect(c.boardSlug, 'default');
    },
  );

  test('leaving during the board list load does not fetch the board', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    final leaving = KanbanBoardController(
      repository: KanbanRepository(server.client().raw),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
    );

    final started = leaving.start();
    leaving.dispose();
    await started;

    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), isEmpty);
  });
}
