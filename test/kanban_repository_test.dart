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

  test(
    'reads a triage helper that declined as an answer, not an error',
    () async {
      server
        ..on('POST', '/api/plugins/kanban/tasks/t1/decompose', {
          'ok': true,
          'fanout': true,
          'child_ids': ['t2', 't3'],
        })
        ..on('POST', '/api/plugins/kanban/tasks/t1/specify', {
          'ok': false,
          'reason': 'No auxiliary model configured',
        });

      final decomposed = await repository.decomposeTask('t1');
      final specified = await repository.specifyTask('t1');

      expect(decomposed.ok, isTrue);
      expect(decomposed.childIds, ['t2', 't3']);
      expect(specified.ok, isFalse);
      expect(specified.reason, 'No auxiliary model configured');
    },
  );

  test('reclaims a running task and says why it cannot', () async {
    server.on('POST', '/api/plugins/kanban/tasks/t1/reclaim', {'ok': true});
    await repository.reclaimTask('t1', reason: 'stuck');
    expect(
      jsonBody(
        server
            .requestsTo('POST', '/api/plugins/kanban/tasks/t1/reclaim')
            .single,
      ),
      {'reason': 'stuck'},
    );

    server.on('POST', '/api/plugins/kanban/tasks/t1/reclaim', {
      'detail': 'cannot reclaim t1: not running',
    }, status: 409);
    expect(repository.reclaimTask('t1'), throwsA(isA<KanbanException>()));
  });

  test('a bulk change reports only the tasks it could not change', () async {
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'id': 't1', 'ok': true},
        {'id': 't2', 'ok': false, 'error': 'archive refused'},
      ],
    });

    final failures = await repository.bulkUpdate(['t1', 't2'], archive: true);

    expect(failures.single.id, 't2');
    expect(failures.single.error, 'archive refused');
    final body = jsonBody(
      server.requestsTo('POST', '/api/plugins/kanban/tasks/bulk').single,
    ) as Map;
    expect(body['ids'], ['t1', 't2']);
    expect(body['archive'], true);
  });

  test('nudges the dispatcher', () async {
    server.on('POST', '/api/plugins/kanban/dispatch', {'spawned': []});

    await repository.dispatch(board: 'ops');

    expect(
      server
          .requestsTo('POST', '/api/plugins/kanban/dispatch')
          .single
          .queryParameters['board'],
      'ops',
    );
  });

  test('reads and saves the orchestration settings', () async {
    server
      ..on('GET', '/api/plugins/kanban/orchestration', {
        'orchestrator_profile': 'lead',
        'default_assignee': '',
        'auto_decompose': false,
        'auto_promote_children': true,
        'active_profile': 'default',
      })
      ..on('PUT', '/api/plugins/kanban/orchestration', {
        'orchestrator_profile': '',
        'auto_decompose': true,
        'auto_promote_children': true,
        'active_profile': 'default',
      });

    final loaded = await repository.loadOrchestration();
    final saved = await repository.saveOrchestration(
      orchestratorProfile: '',
      autoDecompose: true,
    );

    expect(loaded.orchestratorProfile, 'lead');
    expect(loaded.autoDecompose, isFalse);
    expect(saved.autoDecompose, isTrue);
    expect(
      jsonBody(
        server.requestsTo('PUT', '/api/plugins/kanban/orchestration').single,
      ),
      {'orchestrator_profile': '', 'auto_decompose': true},
    );
  });

  test('creates, renames and removes boards', () async {
    server
      ..on('POST', '/api/plugins/kanban/boards', {'board': {}})
      ..on('PATCH', '/api/plugins/kanban/boards/ops', {'board': {}})
      ..on('DELETE', '/api/plugins/kanban/boards/ops', {'result': {}});

    await repository.createBoard(slug: 'ops', name: 'Ops team');
    await repository.renameBoard('ops', name: 'Operations');
    await repository.removeBoard('ops');
    await repository.removeBoard('ops', hardDelete: true);

    expect(
      jsonBody(server.requestsTo('POST', '/api/plugins/kanban/boards').single),
      containsPair('slug', 'ops'),
    );
    expect(
      jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/boards/ops').single,
      ),
      containsPair('name', 'Operations'),
    );
    final deletes = server.requestsTo(
      'DELETE',
      '/api/plugins/kanban/boards/ops',
    );
    expect(deletes.map((r) => r.queryParameters['delete']), [false, true]);
  });

  test('creates, renames and removes boards', () async {
    server
      ..on('POST', '/api/plugins/kanban/boards', {'board': {}})
      ..on('PATCH', '/api/plugins/kanban/boards/ops', {'board': {}})
      ..on('DELETE', '/api/plugins/kanban/boards/ops', {'result': {}});

    await repository.createBoard(slug: 'ops', name: 'Ops');
    await repository.renameBoard('ops', name: 'Operations');
    await repository.removeBoard('ops');
    await repository.removeBoard('ops', hardDelete: true);

    expect(
      jsonBody(server.requestsTo('POST', '/api/plugins/kanban/boards').single),
      containsPair('slug', 'ops'),
    );
    expect(
      jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/boards/ops').single,
      ),
      containsPair('name', 'Operations'),
    );
    final deletes = server.requestsTo(
      'DELETE',
      '/api/plugins/kanban/boards/ops',
    );
    expect(deletes.map((r) => r.queryParameters['delete']), [false, true]);
  });

  test('reads runs, attachments and diagnostics with the task', () async {
    server.on(
      'GET',
      '/api/plugins/kanban/tasks/t1',
      kanbanTaskDetailBody(
        kanbanTaskRow(id: 't1')
          ..['diagnostics'] = [
            {
              'kind': 'stale',
              'severity': 'error',
              'title': 'Worker stalled',
              'detail': 'No heartbeat',
            },
          ],
        runs: [
          {
            'id': 7,
            'status': 'running',
            'profile': 'coder',
            'started_at': 1780000000,
          },
          {
            'id': 6,
            'status': 'done',
            'outcome': 'completed',
            'started_at': 1779990000,
            'ended_at': 1779999000,
          },
        ],
        attachments: [
          {'id': 3, 'filename': 'spec.pdf', 'size': 2048},
        ],
      ),
    );

    final detail = await repository.loadTask('t1');

    expect(detail.runs.first.active, isTrue);
    expect(detail.runs.last.active, isFalse);
    expect(detail.attachments.single.filename, 'spec.pdf');
    expect(detail.diagnostics.single.title, 'Worker stalled');
  });

  test(
    'reads the worker log, terminates a run and removes an attachment',
    () async {
      server
        ..on('GET', '/api/plugins/kanban/tasks/t1/log', {
          'exists': true,
          'content': 'hello',
          'truncated': true,
        })
        ..on('POST', '/api/plugins/kanban/runs/7/terminate', {'ok': true})
        ..on('DELETE', '/api/plugins/kanban/attachments/3', {'ok': true});

      final log = await repository.loadTaskLog('t1', tail: 500);
      await repository.terminateRun(7, reason: 'stuck');
      await repository.removeAttachment(3);

      expect(log.content, 'hello');
      expect(log.truncated, isTrue);
      expect(
        server
            .requestsTo('GET', '/api/plugins/kanban/tasks/t1/log')
            .single
            .queryParameters['tail'],
        500,
      );
      expect(
        jsonBody(
          server
              .requestsTo('POST', '/api/plugins/kanban/runs/7/terminate')
              .single,
        ),
        {'reason': 'stuck'},
      );
    },
  );

  test('says why a run cannot be terminated', () async {
    server.on('POST', '/api/plugins/kanban/runs/7/terminate', {
      'detail': 'run 7 already ended',
    }, status: 409);

    expect(repository.terminateRun(7), throwsA(isA<KanbanException>()));
  });

  test(
    'reads the reason from a validation error that lists what is wrong',
    () async {
      server.on('POST', '/api/plugins/kanban/boards', {
        'detail': [
          {
            'loc': ['body', 'slug'],
            'msg': 'String should have at least 1 character',
          },
        ],
      }, status: 422);

      expect(
        repository.createBoard(slug: ''),
        throwsA(
          isA<KanbanException>().having(
            (e) => e.message,
            'message',
            contains('at least 1 character'),
          ),
        ),
      );
    },
  );

  test('a refused archive is an error, not a success', () async {
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'id': 't1', 'ok': false, 'error': 'archive refused'},
      ],
    });

    expect(
      repository.archiveTask('t1'),
      throwsA(
        isA<KanbanException>().having(
          (e) => e.message,
          'message',
          'archive refused',
        ),
      ),
    );
  });
}
