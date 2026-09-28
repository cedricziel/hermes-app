import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/starter_context_loader.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late StarterContextLoader loader;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/cron/jobs', [])
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/skills', []);
    loader = StarterContextLoader(
      HermesRepositories(server.client()),
      timeout: const Duration(milliseconds: 200),
    );
  });

  test('picks the failed job that ran last, for the profile', () async {
    server.on('GET', '/api/cron/jobs', [
      cronJobRow(
        id: 'a',
        name: 'Old failure',
        lastRunAt: '2026-09-01T03:00:00Z',
        lastStatus: 'error',
      ),
      cronJobRow(
        id: 'b',
        name: 'Nightly backup',
        lastRunAt: '2026-09-27T03:00:00Z',
        lastStatus: 'error',
      ),
      cronJobRow(
        id: 'c',
        name: 'Fine',
        lastRunAt: '2026-09-28T03:00:00Z',
        lastStatus: 'ok',
      ),
    ]);

    final context = await loader.load('work');

    expect(context.failedJob, 'Nightly backup');
    expect(
      server
          .requestsTo('GET', '/api/cron/jobs')
          .single
          .queryParameters['profile'],
      'work',
    );
  });

  test('does not read the board while the Kanban plugin is off', () async {
    final context = await loader.load('work');

    expect(context.kanbanTask, isNull);
    expect(server.requestsTo('GET', '/api/plugins/kanban/board'), isEmpty);
  });

  test('picks a blocked task over one waiting for review', () async {
    server
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          kanbanTaskRow(id: '1', title: 'Write docs', status: 'review'),
          kanbanTaskRow(id: '2', title: 'Migrate auth', status: 'blocked'),
        ]),
      );

    final task = (await loader.load('work')).kanbanTask!;

    expect((task.title, task.blocked), ('Migrate auth', true));
  });

  test('falls back to a task waiting for review', () async {
    server
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          kanbanTaskRow(id: '1', title: 'Write docs', status: 'review'),
        ]),
      );

    final task = (await loader.load('work')).kanbanTask!;

    expect((task.title, task.blocked), ('Write docs', false));
  });

  test('picks the enabled skill used most', () async {
    server.on('GET', '/api/skills', [
      skillRow(name: 'unused'),
      skillRow(name: 'switched-off', enabled: false, usage: 50),
      skillRow(name: 'notes', usage: 3),
      skillRow(name: 'nextcloud-notes', usage: 12),
    ]);

    expect((await loader.load('work')).skill, 'nextcloud-notes');
  });

  test('a skill nobody used is not suggested', () async {
    server.on('GET', '/api/skills', [skillRow(name: 'unused')]);

    expect((await loader.load('work')).skill, isNull);
  });

  test('a failing or slow source is left out and the others kept', () async {
    server
      ..on('GET', '/api/cron/jobs', {'detail': 'boom'}, status: 500)
      ..onRequest('GET', '/api/skills', (_) => Completer<FakeResponse>().future)
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          kanbanTaskRow(id: '2', title: 'Migrate auth', status: 'blocked'),
        ]),
      );

    final context = await loader.load('work');

    expect(context.failedJob, isNull);
    expect(context.skill, isNull);
    expect(context.kanbanTask?.title, 'Migrate auth');
  });
}
