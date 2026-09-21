import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

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
      repository: KanbanRepository(server.client()),
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

  /// Waits for [done] by yielding to the event loop, not by sleeping: how long
  /// the fake server and the controller take depends on machine load.
  Future<void> until(bool Function() done) async {
    while (!done()) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Lets frames that were already added reach the controller, for tests that
  /// assert something did not happen. Delivery takes microtasks and the
  /// controller's zero-length timers take one turn each; 10 turns is ample.
  Future<void> pump() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  int boardFetches() =>
      server.requestsTo('GET', '/api/plugins/kanban/board').length;

  test(
    'loads the board and the board list, and starts the stream after it',
    () async {
      serveBoard([
        kanbanTaskRow(id: 't1', status: 'running', assignee: 'coder'),
        kanbanTaskRow(id: 't2', status: 'done'),
      ], latest: 7);

      await controller.start();
      await until(() => controller.live);

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
      expect(boardFetches(), 1);

      serveBoard([kanbanTaskRow(id: 't1', status: 'running')], latest: 3);
      sockets.single.local.sink
        ..add(jsonEncode(frame(2)))
        ..add(jsonEncode(frame(3)));
      List<KanbanTask> running() => controller.board!.columns
          .firstWhere((c) => c.name == 'running')
          .tasks;
      await until(() => running().isNotEmpty);
      await pump();

      expect(boardFetches(), 2);
      expect(running(), hasLength(1));
    },
  );

  test(
    'marks the tasks a refetch moved to another column as arrived',
    () async {
      serveBoard([
        kanbanTaskRow(id: 't1', status: 'todo'),
        kanbanTaskRow(id: 't2', status: 'todo'),
      ], latest: 1);
      await controller.start();
      expect(controller.arrived('t1'), isFalse);

      serveBoard([
        kanbanTaskRow(id: 't1', status: 'running'),
        kanbanTaskRow(id: 't2', status: 'todo'),
        kanbanTaskRow(id: 't3', status: 'todo'),
      ], latest: 2);
      await controller.refresh();

      expect(controller.arrived('t1'), isTrue);
      expect(controller.arrived('t2'), isFalse);
      expect(controller.arrived('t3'), isTrue);
    },
  );

  test('previewMove shows a task in its new column at once', () async {
    serveBoard([kanbanTaskRow(id: 't1', status: 'todo')]);
    await controller.start();
    var notified = 0;
    controller.addListener(() => notified++);

    controller.previewMove('t1', 'blocked');

    List<KanbanTask> tasks(String column) =>
        controller.board!.columns.firstWhere((c) => c.name == column).tasks;
    expect(tasks('todo'), isEmpty);
    expect(tasks('blocked').single.status, 'blocked');
    expect(notified, 1);
    expect(controller.arrived('t1'), isFalse);
  });

  test('a refetch undoes a preview the server did not accept', () async {
    serveBoard([kanbanTaskRow(id: 't1', status: 'todo')]);
    await controller.start();

    controller.previewMove('t1', 'blocked');
    await controller.refresh();

    expect(
      controller.board!.columns.firstWhere((c) => c.name == 'todo').tasks,
      hasLength(1),
    );
  });

  test('previewMove ignores unknown tasks and columns', () async {
    serveBoard([kanbanTaskRow(id: 't1', status: 'todo')]);
    await controller.start();

    controller.previewMove('nope', 'blocked');
    controller.previewMove('t1', 'nowhere');

    expect(
      controller.board!.columns.firstWhere((c) => c.name == 'todo').tasks,
      hasLength(1),
    );
  });

  test('does not refetch for a frame without events', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();

    sockets.single.local.sink.add(jsonEncode(frame(5, events: false)));
    await pump();

    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), hasLength(1));
  });

  test('reconnects after the stream drops, from the last cursor', () async {
    serveBoard([kanbanTaskRow(id: 't1')], latest: 1);
    await controller.start();
    sockets.single.local.sink.add(jsonEncode(frame(9, events: false)));
    await pump();

    await sockets.single.local.sink.close();
    await until(() => connects.length == 2 && controller.live);

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

  test('a 404 on refresh drops the board and stops the event stream', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();
    await until(() => controller.live);

    server.on('GET', '/api/plugins/kanban/board', {
      'detail': 'nope',
    }, status: 404);
    await controller.refresh();
    await pump();

    expect(controller.board, isNull);
    expect(controller.unavailable, isTrue);
    expect(controller.refreshFailed, isFalse);
    expect(controller.live, isFalse);
    expect(connects, hasLength(1));
  });

  test('a failed refresh keeps the board that was showing', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    await controller.start();

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await controller.refresh();

    expect(controller.board, isNotNull);
    expect(controller.error, isNotNull);
  });

  test(
    'refreshFailed tells a stale board apart until a refresh succeeds',
    () async {
      server.on('GET', '/api/plugins/kanban/board', {
        'detail': 'x',
      }, status: 500);
      await controller.start();
      // Nothing to keep showing: the full-page error covers this case.
      expect(controller.refreshFailed, isFalse);

      serveBoard([kanbanTaskRow(id: 't1')]);
      await controller.refresh();
      expect(controller.refreshFailed, isFalse);

      server.on('GET', '/api/plugins/kanban/board', {
        'detail': 'x',
      }, status: 500);
      await controller.refresh();
      expect(controller.refreshFailed, isTrue);

      serveBoard([kanbanTaskRow(id: 't1')]);
      await controller.refresh();
      expect(controller.refreshFailed, isFalse);
    },
  );

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
      repository: KanbanRepository(server.client()),
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
      repository: KanbanRepository(server.client()),
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
        repository: KanbanRepository(server.client()),
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
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
    );

    final started = leaving.start();
    leaving.dispose();
    await started;

    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), isEmpty);
  });
  test('a board picked while the saved one loads is not overwritten', () async {
    SharedPreferencesAsyncPlatform.instance = _SlowPrefs('default');
    serveBoard([kanbanTaskRow(id: 't1')]);
    final c = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
      prefs: SharedPreferencesAsync(),
    );
    addTearDown(c.dispose);

    final loading = c.loadBoards();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await c.selectBoard('ops');
    await loading;

    expect(c.boardSlug, 'ops');
  });

  test(
    'a preference that cannot be written does not stop the board opening',
    () async {
      SharedPreferencesAsyncPlatform.instance = _FailingWritePrefs();
      serveBoard([kanbanTaskRow(id: 't1')]);
      final c = KanbanBoardController(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
        prefs: SharedPreferencesAsync(),
      );
      addTearDown(c.dispose);
      await c.start();

      await c.selectBoard('ops');

      expect(c.boardSlug, 'ops');
      expect(c.board, isNotNull);
    },
  );

  test(
    'follows the remembered board when the first list read had failed',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'hermes.kanban.board': 'ops',
          });
      serveBoard([kanbanTaskRow(id: 't1')]);
      var listCalls = 0;
      server.onRequest('GET', '/api/plugins/kanban/boards', (_) {
        listCalls++;
        return listCalls == 1
            ? (status: 500, body: {'detail': 'blip'})
            : (
                status: 200,
                body: kanbanBoardsBody([
                  (slug: 'default', name: 'Default', total: 1, current: true),
                  (slug: 'ops', name: 'Ops', total: 0, current: false),
                ]),
              );
      });
      final c = KanbanBoardController(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
        prefs: SharedPreferencesAsync(),
      );
      addTearDown(c.dispose);
      await c.start();
      expect(c.boardSlug, isNull);

      await c.loadBoards();

      expect(c.boardSlug, 'ops');
      expect(
        server
            .requestsTo('GET', '/api/plugins/kanban/board')
            .last
            .queryParameters['board'],
        'ops',
      );
    },
  );

  test('two quick changes leave one event stream, not two', () async {
    serveBoard([kanbanTaskRow(id: 't1')]);
    var opened = 0;
    var open = 0;
    final c = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async {
        opened++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final socket = StreamChannelController<String>();
        open++;
        socket.local.stream.listen(null, onDone: () => open--);
        return socket.foreign;
      },
      debounce: Duration.zero,
    );
    addTearDown(c.dispose);
    await c.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final before = opened;

    final first = c.selectBoard('ops');
    final second = c.setTenant('acme');
    await Future.wait([first, second]);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(opened - before, 1);
    expect(open, 1);
  });

  test('switching board clears the tenant and assignee filters', () async {
    serveBoard([kanbanTaskRow(id: 't1', assignee: 'coder')]);
    await controller.start();
    await controller.setTenant('acme');
    controller.setAssignee('coder');

    await controller.selectBoard('ops');

    expect(controller.tenant, isNull);
    expect(controller.assignee, isNull);
  });

  test('remembers the board under the key it is given', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    serveBoard([kanbanTaskRow(id: 't1')]);
    final c = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
      prefs: prefs,
      prefsKey: 'hermes.kanban.board.http://a',
    );
    addTearDown(c.dispose);
    await c.start();

    await c.selectBoard('ops');

    expect(await prefs.getString('hermes.kanban.board.http://a'), 'ops');
    expect(await prefs.getString('hermes.kanban.board'), isNull);
  });
}

/// Answers the saved board late, like a slow disk.
base class _SlowPrefs extends InMemorySharedPreferencesAsync {
  _SlowPrefs(String saved) : super.withData({'hermes.kanban.board': saved});

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return super.getString(key, options);
  }
}

base class _FailingWritePrefs extends InMemorySharedPreferencesAsync {
  _FailingWritePrefs() : super.empty();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('disk full');
}
