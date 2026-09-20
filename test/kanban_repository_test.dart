import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/kanban_repository.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late KanbanRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = KanbanRepository(server.client().raw);
  });

  test('reads a task with its comments, links and history', () async {
    server.on(
      'GET',
      '/api/plugins/kanban/tasks/t1',
      kanbanTaskDetailBody(
        kanbanTaskRow(id: 't1', title: 'Ship it', status: 'blocked'),
        comments: [
          {'author': 'coder', 'body': 'On it', 'created_at': 1780000000},
        ],
        parents: ['t0'],
        events: [
          {'kind': 'created', 'created_at': 1780000000},
        ],
      ),
    );

    final detail = await repository.loadTask('t1');

    expect(detail.task.title, 'Ship it');
    expect(detail.comments.single.author, 'coder');
    expect(detail.parents, ['t0']);
    expect(detail.events.single.kind, 'created');
  });

  test('creates a task and hands back the dispatcher warning', () async {
    server.on('POST', '/api/plugins/kanban/tasks', {
      'task': {'id': 't9'},
      'warning': 'No dispatcher is running',
    });

    final warning = await repository.createTask(
      title: 'Add dark mode',
      assignee: 'coder',
      priority: 2,
      triage: true,
      board: 'ops',
    );

    expect(warning, 'No dispatcher is running');
    final request = server
        .requestsTo('POST', '/api/plugins/kanban/tasks')
        .single;
    expect(request.queryParameters['board'], 'ops');
    expect(jsonBody(request), containsPair('title', 'Add dark mode'));
    expect(jsonBody(request), containsPair('triage', true));
    expect(jsonBody(request), containsPair('priority', 2));
  });

  test('sends only the fields that change', () async {
    server.on('PATCH', '/api/plugins/kanban/tasks/t1', {'ok': true});

    await repository.updateTask(
      't1',
      status: 'blocked',
      blockReason: 'Waiting',
    );

    final body = jsonBody(
      server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
    );
    expect(body, containsPair('status', 'blocked'));
    expect(body, containsPair('block_reason', 'Waiting'));
    expect(body, isNot(contains('title')));
  });

  test('says why the plugin refused', () async {
    server.on('PATCH', '/api/plugins/kanban/tasks/t1', {
      'detail': "Cannot move to 'ready': blocked by parent(s) not done",
    }, status: 409);

    expect(
      repository.updateTask('t1', status: 'ready'),
      throwsA(
        isA<KanbanException>().having(
          (e) => e.message,
          'message',
          contains('blocked by parent'),
        ),
      ),
    );
  });

  test('comments, links, archives and deletes', () async {
    server
      ..on('POST', '/api/plugins/kanban/tasks/t1/comments', {'ok': true})
      ..on('POST', '/api/plugins/kanban/links', {'ok': true})
      ..on('DELETE', '/api/plugins/kanban/links', {'ok': true})
      ..on('POST', '/api/plugins/kanban/tasks/bulk', {'results': []})
      ..on('DELETE', '/api/plugins/kanban/tasks/t1', {'ok': true});

    await repository.addComment('t1', 'Please cover refunds');
    await repository.addLink('t0', 't1');
    await repository.removeLink('t0', 't1');
    await repository.archiveTask('t1');
    await repository.deleteTask('t1');

    expect(
      jsonBody(
        server
            .requestsTo('POST', '/api/plugins/kanban/tasks/t1/comments')
            .single,
      ),
      {'body': 'Please cover refunds'},
    );
    expect(
      jsonBody(server.requestsTo('POST', '/api/plugins/kanban/links').single),
      {'parent_id': 't0', 'child_id': 't1'},
    );
    final unlink = server
        .requestsTo('DELETE', '/api/plugins/kanban/links')
        .single;
    expect(unlink.queryParameters, {'parent_id': 't0', 'child_id': 't1'});
    expect(
      jsonBody(
        server.requestsTo('POST', '/api/plugins/kanban/tasks/bulk').single,
      ),
      containsPair('archive', true),
    );
  });
}
