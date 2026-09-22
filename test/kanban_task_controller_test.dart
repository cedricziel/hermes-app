import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_task_controller.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

const _task = '/api/plugins/kanban/tasks/t1';

Map<String, dynamic> _detail(String title, {String status = 'todo'}) =>
    kanbanTaskDetailBody(kanbanTaskRow(id: 't1', title: title, status: status));

void main() {
  late FakeHermesServer server;
  late int changes;

  KanbanTaskController controller() => KanbanTaskController(
    repository: KanbanRepository(server.client()),
    taskId: 't1',
    board: 'ops',
    onChanged: () => changes++,
  );

  setUp(() {
    changes = 0;
    server = FakeHermesServer()
      ..on('GET', _task, _detail('Migrate webhooks'))
      ..on('GET', '/api/plugins/kanban/home-channels', {
        'home_channels': [
          {'platform': 'telegram', 'name': 'Ops chat', 'subscribed': false},
        ],
      });
  });

  test('loads the task and its home channels', () async {
    final task = controller();
    addTearDown(task.dispose);
    await task.start();

    expect(task.detail?.task.title, 'Migrate webhooks');
    expect(task.failed, isFalse);
    expect(task.channels.single.name, 'Ops chat');
  });

  test('a first load that fails is reported, and retry recovers', () async {
    server.on('GET', _task, {'detail': 'boom'}, status: 500);
    final task = controller();
    addTearDown(task.dispose);
    await task.load();
    expect(task.failed, isTrue);

    server.on('GET', _task, _detail('Migrate webhooks'));
    await task.retry();
    expect(task.failed, isFalse);
    expect(task.detail, isNotNull);
  });

  test(
    'a move is sent, reported and reloaded; the estimate is dropped',
    () async {
      server
        ..on('PATCH', _task, {'ok': true})
        ..on('POST', '$_task/estimate', {
          'ok': true,
          'est_tokens': 12000,
          'complexity': 'M',
        });
      final task = controller();
      addTearDown(task.dispose);
      await task.load();
      await task.estimateTask();
      expect(task.estimate, isNotNull);

      server.on('GET', _task, _detail('Migrate webhooks', status: 'done'));
      await task.moveTo('done', result: 'Shipped');

      final request = server.requestsTo('PATCH', _task).single;
      final patch = request.data is String
          ? jsonDecode(request.data as String)
          : request.data;
      expect(patch, containsPair('status', 'done'));
      expect(patch, containsPair('result', 'Shipped'));
      expect(changes, 1);
      expect(task.estimate, isNull);
      expect(task.detail?.task.status, 'done');
    },
  );

  test('a refused write throws and changes nothing', () async {
    server.on('PATCH', _task, {'detail': 'no'}, status: 409);
    final task = controller();
    addTearDown(task.dispose);
    await task.load();

    await expectLater(task.update(priority: 3), throwsA(anything));
    expect(changes, 0);
  });

  test('a load that answers after a newer one is dropped', () async {
    final first = Completer<FakeResponse>();
    var calls = 0;
    server.onRequest('GET', _task, (_) {
      calls++;
      return calls == 1
          ? first.future
          : (status: 200, body: _detail('Newer title'));
    });
    final task = controller();
    addTearDown(task.dispose);

    final stale = task.load();
    await task.load();
    expect(task.detail?.task.title, 'Newer title');

    first.complete((status: 200, body: _detail('Stale title')));
    await stale;
    expect(task.detail?.task.title, 'Newer title');
  });
}
