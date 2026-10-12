import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  void boardTest(String name, void Function(FakeAsync, _Board) body) {
    test(name, () {
      fakeAsync((async) {
        final board = _Board();
        try {
          body(async, board);
        } finally {
          board.dispose();
          async.elapse(Duration.zero);
        }
      });
    });
  }

  boardTest('inactive board reads and mutations send no requests', (async, h) {
    h.activity.value = false;
    h.controller
      ..startSelecting('t1')
      ..start()
      ..refresh()
      ..loadBoards();
    expectLater(h.controller.dispatch(), throwsStateError);
    expectLater(h.controller.bulkUpdate(status: 'done'), throwsStateError);
    expectLater(h.controller.moveTask(h.task, 'done'), throwsStateError);
    async.elapse(Duration.zero);

    expect(h.server.requests, isEmpty);
    expect(h.sockets, isEmpty);
    expect(h.controller.selected, {'t1'});
    expect(h.controller.loading, isFalse);
  });

  boardTest('pause closes the stream and cancels a pending refetch', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    h.emit();
    async.elapse(Duration.zero);

    h.activity.value = false;
    expect(h.controller.live, isFalse);
    async.elapse(const Duration(seconds: 5));

    expect(h.closed, 1);
    expect(h.fetches, 1);
    expect(h.sockets, hasLength(1));
    expect(h.controller.board, isNotNull);
  });

  boardTest('pause cancels an event reconnect', (async, h) {
    h.controller.start();
    async.elapse(Duration.zero);
    h.sockets.single.local.sink.close();
    async.elapse(Duration.zero);
    h.activity.value = false;
    async.elapse(const Duration(seconds: 5));

    expect(h.sockets, hasLength(1));
    expect(h.controller.live, isFalse);
  });

  boardTest('resume rereads a hidden board and retains local selection', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    h.controller
      ..startSelecting('t1')
      ..setQuery('Task')
      ..setAssignee('coder')
      ..showStatus('todo')
      ..active = false;
    h.activity.value = false;
    h.serve(status: 'done', latest: 20);

    h.activity.value = true;
    async.elapse(Duration.zero);

    expect(h.fetches, 2);
    expect(
      h.server.requestsTo('GET', '/api/plugins/kanban/boards'),
      hasLength(2),
    );
    expect(h.controller.boardSlug, 'default');
    expect(h.controller.query, 'Task');
    expect(h.controller.assignee, 'coder');
    expect(h.controller.shownStatus, 'todo');
    expect(h.controller.selecting, isTrue);
    expect(h.controller.selected, {'t1'});
    expect(h.controller.board!.latestEventId, 20);
    expect(h.sockets, hasLength(1));
    h.controller.active = true;
    async.elapse(Duration.zero);
    expect(h.since.last, 20);
  });

  boardTest('old board reads cannot replace fresh state after resume', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    final held = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/plugins/kanban/board', (_) => held.future);
    h.controller.refresh();
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.serve(status: 'done', latest: 20);
    h.activity.value = true;
    async.elapse(Duration.zero);

    held.complete((status: 200, body: kanbanBoardBody([], latestEventId: 99)));
    async.elapse(Duration.zero);

    expect(h.controller.board!.latestEventId, 20);
    expect(h.controller.board!.taskCount, 1);
    expect(h.fetches, 3);
  });

  boardTest('a retired load cannot finish the resumed loading state', (
    async,
    h,
  ) {
    final old = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/plugins/kanban/board', (_) => old.future);
    h.controller.start();
    async.elapse(Duration.zero);
    h.activity.value = false;
    final fresh = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/plugins/kanban/board', (_) => fresh.future);
    h.activity.value = true;
    async.elapse(Duration.zero);

    old.complete((status: 404, body: {'detail': 'old plugin gone'}));
    async.elapse(Duration.zero);

    expect(h.controller.loading, isTrue);
    expect(h.controller.error, isNull);
    expect(h.controller.board, isNull);
    fresh.complete((
      status: 200,
      body: kanbanBoardBody([kanbanTaskRow(id: 't1')]),
    ));
    async.elapse(Duration.zero);
    expect(h.controller.loading, isFalse);
    expect(h.controller.board!.taskCount, 1);
  });

  boardTest('old board list cannot select a removed board after resume', (
    async,
    h,
  ) {
    final held = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/plugins/kanban/boards', (_) => held.future);
    h.controller.start();
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.serveBoards();
    h.activity.value = true;
    async.elapse(Duration.zero);

    held.complete((
      status: 200,
      body: kanbanBoardsBody([
        (slug: 'old', name: 'Old', total: 1, current: true),
      ]),
    ));
    async.elapse(Duration.zero);

    expect(h.controller.boardSlug, 'default');
    expect(h.controller.boards.single.slug, 'default');
    expect(h.fetches, 1);
  });

  boardTest('old connection closes when it completes after resume', (async, h) {
    final held = h.connection = Completer<StreamChannel<String>>();
    h.controller.start();
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);
    final old = h.socket();
    held.complete(old.foreign);
    async.elapse(Duration.zero);

    expect(h.closed, 1);
    expect(h.controller.live, isTrue);
    old.local.sink.add(
      jsonEncode({
        'cursor': 99,
        'events': [{}],
      }),
    );
    async.elapse(const Duration(seconds: 5));
    expect(h.fetches, 2);
  });

  boardTest('late bulk success retains selection and sends no follow-up read', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    h.controller.startSelecting('t1');
    final held = Completer<FakeResponse>();
    h.server.onRequest(
      'POST',
      '/api/plugins/kanban/tasks/bulk',
      (_) => held.future,
    );
    expectLater(h.controller.bulkUpdate(status: 'done'), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);

    held.complete((status: 200, body: {'results': []}));
    async.elapse(Duration.zero);

    expect(h.controller.selected, {'t1'});
    expect(h.controller.selecting, isTrue);
    expect(h.fetches, 2);
  });

  boardTest('late move success reports suspension and keeps the fresh board', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    final held = Completer<FakeResponse>();
    h.server.onRequest(
      'PATCH',
      '/api/plugins/kanban/tasks/t1',
      (_) => held.future,
    );
    expectLater(h.controller.moveTask(h.task, 'done'), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);

    held.complete((status: 200, body: {}));
    async.elapse(Duration.zero);

    expect(h.task.status, 'todo');
    expect(h.fetches, 2);
  });

  boardTest('late dispatcher success reports suspension instead of success', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    final held = Completer<FakeResponse>();
    h.server.onRequest(
      'POST',
      '/api/plugins/kanban/dispatch',
      (_) => held.future,
    );
    expectLater(h.controller.dispatch(), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);

    held.complete((status: 200, body: {}));
    async.elapse(Duration.zero);

    expect(
      h.server.requestsTo('POST', '/api/plugins/kanban/dispatch'),
      hasLength(1),
    );
    expect(h.fetches, 2);
  });

  boardTest('pause during live notification cannot attach the old stream', (
    async,
    h,
  ) {
    h.controller.addListener(() {
      if (h.controller.live) h.activity.value = false;
    });
    h.controller.start();
    async.elapse(Duration.zero);

    expect(h.closed, 1);
    expect(h.controller.live, isFalse);
    h.emit();
    async.elapse(const Duration(seconds: 5));
    expect(h.fetches, 1);
  });

  boardTest('refresh rechecks activity after its loading notification', (
    async,
    h,
  ) {
    h.controller.addListener(() => h.activity.value = false);
    h.controller.refresh();
    async.elapse(Duration.zero);

    expect(h.fetches, 0);
    expect(h.controller.loading, isFalse);
  });

  boardTest('nested pause while attaching a stream permits a fresh stream', (
    async,
    h,
  ) {
    h.onListen = () {
      h.activity.value = false;
      h.activity.value = true;
    };
    h.controller.start();
    async.elapse(Duration.zero);

    expect(h.sockets, hasLength(2));
    expect(h.closed, 1);
    expect(h.controller.live, isTrue);
    h.emit();
    async.elapse(const Duration(seconds: 1));
    expect(h.fetches, 3);
  });

  boardTest(
    'visibility changes while attaching a stream keep the fresh stream',
    (async, h) {
      h.onListen = () {
        h.controller.active = false;
        h.controller.active = true;
      };
      h.controller.start();
      async.elapse(Duration.zero);

      expect(h.sockets, hasLength(2));
      expect(h.closed, 1);
      expect(h.controller.live, isTrue);
      h.emit();
      async.elapse(const Duration(seconds: 1));
      expect(h.fetches, 2);
      expect(h.sockets, hasLength(2));
    },
  );

  boardTest('move rechecks activity after its optimistic notification', (
    async,
    h,
  ) {
    h.controller.start();
    async.elapse(Duration.zero);
    h.controller.addListener(() => h.activity.value = false);
    expectLater(h.controller.moveTask(h.task, 'done'), throwsStateError);
    async.elapse(Duration.zero);

    expect(
      h.server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1'),
      isEmpty,
    );
  });

  test('earlier activity listeners cannot issue paused board work', () {
    fakeAsync((async) {
      final activity = ValueNotifier(true);
      late _Board h;
      activity.addListener(() {
        if (!activity.value) {
          h.controller.refresh();
          expectLater(h.controller.dispatch(), throwsStateError);
          expectLater(h.controller.moveTask(h.task, 'done'), throwsStateError);
          expectLater(
            h.controller.bulkUpdate(status: 'done'),
            throwsStateError,
          );
        }
      });
      h = _Board(activity: activity);
      h.controller.start();
      async.elapse(Duration.zero);
      h.controller.startSelecting('t1');

      activity.value = false;
      async.elapse(Duration.zero);

      expect(h.fetches, 1);
      expect(h.server.requests.where((r) => r.method == 'POST'), isEmpty);
      h.dispose();
      async.elapse(Duration.zero);
    });
  });

  test(
    'nested activity delivery invalidates old reads even with final true',
    () {
      fakeAsync((async) {
        final activity = ValueNotifier(true);
        activity.addListener(() {
          if (!activity.value) activity.value = true;
        });
        final h = _Board(activity: activity);
        h.controller.start();
        async.elapse(Duration.zero);
        final held = Completer<FakeResponse>();
        h.server.onRequest(
          'GET',
          '/api/plugins/kanban/board',
          (_) => held.future,
        );
        h.controller.refresh();
        async.elapse(Duration.zero);
        h.serve(latest: 20);

        activity.value = false;
        held.complete((
          status: 200,
          body: kanbanBoardBody([], latestEventId: 99),
        ));
        async.elapse(Duration.zero);

        expect(h.controller.board!.taskCount, 1);
        expect(h.controller.board!.latestEventId, 20);
        h.dispose();
        async.elapse(Duration.zero);
      });
    },
  );

  boardTest(
    'nested pause in a loading notification prevents the old dispatch',
    (async, h) {
      var suspend = true;
      h.controller.addListener(() {
        if (!suspend) return;
        suspend = false;
        h.activity.value = false;
        h.activity.value = true;
      });

      h.controller.refresh();
      async.elapse(Duration.zero);

      expect(h.fetches, 1);
      expect(h.controller.board, isNotNull);
      expect(
        h.server.requestsTo('GET', '/api/plugins/kanban/boards'),
        hasLength(1),
      );
    },
  );
}

class _Board {
  _Board({ValueNotifier<bool>? activity})
    : activity = activity ?? ValueNotifier(true) {
    serveBoards();
    serve();
    server
      ..on('PATCH', '/api/plugins/kanban/tasks/t1', {})
      ..on('POST', '/api/plugins/kanban/tasks/bulk', {'results': []})
      ..on('POST', '/api/plugins/kanban/dispatch', {});
    controller = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      activity: this.activity,
      debounce: const Duration(seconds: 1),
      reconnectDelay: (_) => const Duration(seconds: 1),
      connect: ({required since, board}) async {
        this.since.add(since);
        final held = connection;
        connection = null;
        if (held != null) return held.future;
        final channel = socket().foreign;
        final listen = onListen;
        onListen = null;
        if (listen == null) return channel;
        return channel.changeStream(
          (frames) => Stream.multi((events) {
            final subscription = frames.listen(
              events.add,
              onError: events.addError,
              onDone: events.close,
            );
            events.onCancel = subscription.cancel;
            listen();
          }),
        );
      },
    );
  }

  final ValueNotifier<bool> activity;
  final server = FakeHermesServer();
  late final KanbanBoardController controller;
  final sockets = <StreamChannelController<String>>[];
  final since = <int>[];
  Completer<StreamChannel<String>>? connection;
  void Function()? onListen;
  int closed = 0;

  int get fetches =>
      server.requestsTo('GET', '/api/plugins/kanban/board').length;
  KanbanTask get task =>
      controller.board?.columns.expand((c) => c.tasks).first ??
      KanbanTask.fromJson(kanbanTaskRow(id: 't1'));

  StreamChannelController<String> socket() {
    final socket = StreamChannelController<String>();
    socket.local.stream.listen(null, onDone: () => closed++);
    sockets.add(socket);
    return socket;
  }

  void serveBoards() => server.on(
    'GET',
    '/api/plugins/kanban/boards',
    kanbanBoardsBody([
      (slug: 'default', name: 'Default', total: 1, current: true),
    ]),
  );

  void serve({String status = 'todo', int latest = 1}) => server.on(
    'GET',
    '/api/plugins/kanban/board',
    kanbanBoardBody([
      kanbanTaskRow(id: 't1', status: status, assignee: 'coder'),
    ], latestEventId: latest),
  );

  void emit() => sockets.last.local.sink.add(
    jsonEncode({
      'cursor': 2,
      'events': [{}],
    }),
  );

  void dispose() {
    controller.dispose();
    activity.dispose();
  }
}
