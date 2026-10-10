import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/surfaces/chat_hints.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/kanban_fixtures.dart';

final now = DateTime.utc(2026, 10, 10, 12);

double epoch(DateTime time) => time.millisecondsSinceEpoch / 1000;

Map<String, Object?> session(String id, String title, DateTime at) =>
    sessionRow(id: id, title: title, lastActive: epoch(at));

void main() {
  late FakeHermesServer server;
  late SurfaceSnapshotBuilder builder;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [
          {'name': 'default'},
          {'name': 'work'},
        ],
      })
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          session('d1', 'Trip plan', DateTime.utc(2026, 10, 10, 9)),
          session('d2', 'Old idea', DateTime.utc(2026, 10, 1)),
        ]),
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          session('w1', 'Quarterly numbers', DateTime.utc(2026, 10, 10, 11)),
        ]),
        query: {'profile': 'work'},
      )
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
      ..on('GET', '/api/cron/jobs', []);
    builder = SurfaceSnapshotBuilder(
      HermesRepositories(server.client()),
      timeout: const Duration(milliseconds: 200),
      now: () => now,
    );
  });

  Future<SurfaceSnapshot> build({
    SurfaceSnapshot? previous,
    ChatHints? hints,
    bool refreshRemote = true,
    bool redact = false,
  }) async => (await builder.build(
    signedIn: true,
    previous: previous,
    hints: hints,
    refreshRemote: refreshRemote,
    redact: redact,
  )).snapshot;

  test('merges the recent chats of every profile, newest first', () async {
    final snapshot = await build();

    expect(snapshot.signedIn, isTrue);
    expect(snapshot.profiles, ['default', 'work']);
    expect(snapshot.recentChats.map((c) => (c.profile, c.id)), [
      ('work', 'w1'),
      ('default', 'd1'),
      ('default', 'd2'),
    ]);
    expect(snapshot.recentChats.first.url, 'hermes://chat?profile=work&id=w1');
    expect(snapshot.recentChats.first.title, 'Quarterly numbers');
  });

  test('a chat the server has not named shows a fixed title, not its '
      'preview', () async {
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(
          id: 'w2',
          preview: 'Email the board the secret numbers',
          lastActive: epoch(DateTime.utc(2026, 10, 10, 11, 30)),
        ),
      ]),
      query: {'profile': 'work'},
    );

    final snapshot = await build();

    expect(
      snapshot.recentChats.firstWhere((c) => c.id == 'w2').title,
      'New chat',
    );
    expect(
      snapshot.recentChats.firstWhere((c) => c.id == 'd1').title,
      'Trip plan',
    );
  });

  test('reads at most ten chats of a profile', () async {
    await build();

    expect(
      server
          .requestsTo('GET', '/api/sessions')
          .map((r) => r.queryParameters['limit']),
      everyElement(10),
    );
  });

  group('Kanban', () {
    test('counts the blocked and in-review tasks', () async {
      server
        ..on('GET', '/api/dashboard/plugins', [
          {'name': 'kanban'},
        ])
        ..on(
          'GET',
          '/api/plugins/kanban/board',
          kanbanBoardBody([
            kanbanTaskRow(id: '1', status: 'blocked'),
            kanbanTaskRow(id: '2', status: 'review'),
            kanbanTaskRow(id: '3', status: 'review'),
            kanbanTaskRow(id: '4', status: 'todo'),
          ]),
        );

      final kanban = (await build()).kanban!;

      expect((kanban.blocked, kanban.review), (1, 2));
    });

    test('is null while the plugin is off', () async {
      final previous = SurfaceSnapshot(
        updatedAt: now,
        kanban: const KanbanSummary(blocked: 4, review: 4),
      );

      expect((await build(previous: previous)).kanban, isNull);
      expect(server.requestsTo('GET', '/api/plugins/kanban/board'), isEmpty);
    });

    test('keeps the previous counts when the board fails', () async {
      server
        ..on('GET', '/api/dashboard/plugins', [
          {'name': 'kanban'},
        ])
        ..on('GET', '/api/plugins/kanban/board', {'detail': 'no'}, status: 500);
      final previous = SurfaceSnapshot(
        updatedAt: now,
        kanban: const KanbanSummary(blocked: 4, review: 3),
      );

      final result = await builder.build(
        signedIn: true,
        previous: previous,
        refreshRemote: true,
      );

      expect(
        result.snapshot.kanban,
        const KanbanSummary(blocked: 4, review: 3),
      );
      expect(result.sourcesFailed, 1);
    });

    test('keeps the previous counts when the board is too slow', () async {
      server
        ..on('GET', '/api/dashboard/plugins', [
          {'name': 'kanban'},
        ])
        ..onRequest(
          'GET',
          '/api/plugins/kanban/board',
          (_) => Completer<FakeResponse>().future,
        );
      final previous = SurfaceSnapshot(
        updatedAt: now,
        kanban: const KanbanSummary(blocked: 4, review: 3),
      );

      final snapshot = await build(previous: previous);

      expect(snapshot.kanban, const KanbanSummary(blocked: 4, review: 3));
      expect(snapshot.recentChats, isNotEmpty);
    });
  });

  group('schedules', () {
    test('a job without a name shows a fixed label, not its prompt', () async {
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(
          id: 'unnamed',
          name: '',
          prompt: 'Email the board the secret quarterly numbers',
          nextRunAt: '2026-10-11T08:00:00Z',
          lastRunAt: '2026-10-09T03:00:00Z',
          lastStatus: 'error',
        ),
      ]);

      final schedules = (await build()).schedules!;

      expect(schedules.nextJobName, 'Scheduled task');
      expect(schedules.lastFailed!.name, 'Scheduled task');
    });

    test('finds the next run and the last failed job', () async {
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(
          id: 'late',
          name: 'Weekly',
          nextRunAt: '2026-10-17T08:00:00Z',
        ),
        cronJobRow(
          id: 'soon',
          name: 'Daily digest',
          nextRunAt: '2026-10-11T08:00:00Z',
          profile: 'default',
        ),
        cronJobRow(
          id: 'past',
          name: 'Stale',
          nextRunAt: '2026-10-01T08:00:00Z',
        ),
        cronJobRow(
          id: 'paused',
          name: 'Paused',
          state: 'paused',
          nextRunAt: '2026-10-10T13:00:00Z',
        ),
        cronJobRow(
          id: 'f1',
          name: 'Old failure',
          lastRunAt: '2026-10-02T03:00:00Z',
          lastStatus: 'error',
        ),
        cronJobRow(
          id: 'f2',
          name: 'Backup',
          lastRunAt: '2026-10-09T03:00:00Z',
          lastStatus: 'error',
          profile: 'default',
        ),
        cronJobRow(
          id: 'ok',
          name: 'Fine',
          lastRunAt: '2026-10-10T03:00:00Z',
          lastStatus: 'ok',
        ),
      ]);

      final schedules = (await build()).schedules!;

      expect(schedules.nextRunAt, DateTime.utc(2026, 10, 11, 8));
      expect(schedules.nextJobName, 'Daily digest');
      final failed = schedules.lastFailed!;
      expect(
        (failed.profile, failed.jobId, failed.name),
        ('default', 'f2', 'Backup'),
      );
      expect(failed.at, DateTime.utc(2026, 10, 9, 3));
      expect(
        server
            .requestsTo('GET', '/api/cron/jobs')
            .single
            .queryParameters['profile'],
        'all',
      );
    });

    test('is empty but present without jobs', () async {
      final schedules = (await build()).schedules!;

      expect(schedules.nextRunAt, isNull);
      expect(schedules.lastFailed, isNull);
    });

    test('is null when the server has no cron routes', () async {
      server.on('GET', '/api/cron/delivery-targets', {
        'detail': 'Not Found',
      }, status: 404);

      expect((await build()).schedules, isNull);
    });

    test('keeps the previous section when the jobs fail', () async {
      server.on('GET', '/api/cron/jobs', {'detail': 'no'}, status: 500);
      final previous = SurfaceSnapshot(
        updatedAt: now,
        schedules: ScheduleSummary(
          nextRunAt: DateTime.utc(2026, 10, 12),
          nextJobName: 'Kept',
        ),
      );

      expect((await build(previous: previous)).schedules!.nextJobName, 'Kept');
    });
  });

  group('profiles', () {
    test('keeps the previous names and chats when the list fails', () async {
      server.on('GET', '/api/profiles', {'detail': 'no'}, status: 500);
      final previous = SurfaceSnapshot(
        updatedAt: now,
        profiles: const ['default', 'work', 'home'],
        recentChats: [
          RecentChat(
            profile: 'home',
            id: 'h1',
            title: 'Garden',
            updatedAt: DateTime.utc(2026, 10, 9),
          ),
        ],
      );

      final result = await builder.build(
        signedIn: true,
        previous: previous,
        refreshRemote: true,
      );

      expect(result.snapshot.profiles, ['default', 'work', 'home']);
      expect(result.snapshot.recentChats.map((c) => c.id), ['h1']);
      expect(result.sourcesFailed, 1);
    });

    test('keeps the rows of a profile whose chats fail', () async {
      server.on(
        'GET',
        '/api/sessions',
        {'detail': 'no'},
        status: 500,
        query: {'profile': 'work'},
      );
      final previous = SurfaceSnapshot(
        updatedAt: now,
        recentChats: [
          RecentChat(
            profile: 'work',
            id: 'w0',
            title: 'Before',
            updatedAt: DateTime.utc(2026, 10, 9),
          ),
          RecentChat(
            profile: 'gone',
            id: 'g0',
            title: 'Deleted profile',
            updatedAt: DateTime.utc(2026, 10, 9),
          ),
        ],
      );

      final snapshot = await build(previous: previous);

      expect(snapshot.recentChats.map((c) => c.id).toSet(), {'d1', 'd2', 'w0'});
    });
  });

  group('without a remote read', () {
    test('asks the server for nothing', () async {
      final previous = SurfaceSnapshot(
        updatedAt: now,
        profiles: const ['default'],
        kanban: const KanbanSummary(blocked: 1, review: 0),
      );

      final snapshot = await build(previous: previous, refreshRemote: false);

      expect(server.requests, isEmpty);
      expect(snapshot.profiles, ['default']);
      expect(snapshot.kanban, const KanbanSummary(blocked: 1, review: 0));
    });
  });

  group('chat hints', () {
    final hints = ChatHints(
      profile: 'default',
      threads: [
        ThreadHint(
          id: 'd2',
          title: 'Old idea',
          updatedAt: DateTime.utc(2026, 10, 10, 11, 59),
          snippet: 'It finished.',
        ),
      ],
      requests: [
        RequestHint(
          threadId: 'd2',
          threadTitle: 'Old idea',
          kind: PendingKind.approval,
          requestId: 'r-new',
          seenAt: DateTime.utc(2026, 10, 10, 11, 58),
        ),
      ],
    );

    test('replace the open profile without a request for it', () async {
      final snapshot = await build(hints: hints);

      expect(snapshot.profile, 'default');
      expect(snapshot.recentChats.map((c) => c.id), ['d2', 'w1']);
      expect(snapshot.recentChats.first.snippet, 'It finished.');
      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((r) => r.queryParameters['profile']),
        ['work'],
      );
    });

    test('apply without a remote read', () async {
      final previous = SurfaceSnapshot(
        updatedAt: now,
        recentChats: [
          RecentChat(
            profile: 'default',
            id: 'stale',
            title: 'Stale',
            updatedAt: DateTime.utc(2026, 10, 9),
          ),
          RecentChat(
            profile: 'work',
            id: 'w1',
            title: 'Quarterly numbers',
            updatedAt: DateTime.utc(2026, 10, 10, 11),
          ),
        ],
      );

      final snapshot = await build(
        previous: previous,
        hints: hints,
        refreshRemote: false,
      );

      expect(server.requests, isEmpty);
      expect(snapshot.recentChats.map((c) => c.id), ['d2', 'w1']);
    });

    test('replace the open profile\'s pending entries only', () async {
      final previous = SurfaceSnapshot(
        updatedAt: now,
        pending: [
          PendingRequest(
            profile: 'default',
            threadId: 'd1',
            threadTitle: 'Trip plan',
            kind: PendingKind.question,
            requestId: 'r-answered',
            createdAt: DateTime.utc(2026, 10, 10, 8),
          ),
          PendingRequest(
            profile: 'work',
            threadId: 'w1',
            threadTitle: 'Quarterly numbers',
            kind: PendingKind.input,
            requestId: 'r-work',
            createdAt: DateTime.utc(2026, 10, 10, 9),
          ),
        ],
      );

      final snapshot = await build(previous: previous, hints: hints);

      expect(snapshot.pending.map((p) => (p.profile, p.requestId)), [
        ('work', 'r-work'),
        ('default', 'r-new'),
      ]);
      expect(snapshot.pending.last.kind, PendingKind.approval);
      expect(
        snapshot.pending.last.createdAt,
        DateTime.utc(2026, 10, 10, 11, 58),
      );
    });

    test('keep the time a request was first seen', () async {
      final previous = SurfaceSnapshot(
        updatedAt: now,
        pending: [
          PendingRequest(
            profile: 'default',
            threadId: 'd2',
            threadTitle: 'Old idea',
            kind: PendingKind.approval,
            requestId: 'r-new',
            createdAt: DateTime.utc(2026, 10, 10, 10),
          ),
        ],
      );

      final snapshot = await build(previous: previous, hints: hints);

      expect(snapshot.pending.single.createdAt, DateTime.utc(2026, 10, 10, 10));
    });
  });

  group('redact', () {
    test('empties titles and drops snippets and job names', () async {
      server
        ..on('GET', '/api/cron/jobs', [
          cronJobRow(
            id: 'f2',
            name: 'Backup',
            lastRunAt: '2026-10-09T03:00:00Z',
            lastStatus: 'error',
            nextRunAt: '2026-10-11T08:00:00Z',
          ),
        ])
        ..on('GET', '/api/dashboard/plugins', [
          {'name': 'kanban'},
        ])
        ..on(
          'GET',
          '/api/plugins/kanban/board',
          kanbanBoardBody([kanbanTaskRow(id: '1', status: 'blocked')]),
        );
      final hints = ChatHints(
        profile: 'default',
        threads: [
          ThreadHint(
            id: 'd1',
            title: 'Trip plan',
            updatedAt: DateTime.utc(2026, 10, 10, 9),
            snippet: 'Booked',
          ),
        ],
        requests: [
          RequestHint(
            threadId: 'd1',
            threadTitle: 'Trip plan',
            kind: PendingKind.question,
            requestId: 'r1',
            seenAt: now,
          ),
        ],
      );

      final open = await build(hints: hints);
      final locked = await build(hints: hints, redact: true);

      expect(locked.recentChats.map((c) => c.title), everyElement(''));
      expect(locked.recentChats.map((c) => c.snippet), everyElement(isNull));
      expect(locked.pending.single.threadTitle, '');
      expect(locked.schedules!.nextJobName, isNull);
      expect(locked.schedules!.lastFailed!.name, '');
      expect(locked.recentChats.map((c) => c.url), [
        for (final c in open.recentChats) c.url,
      ]);
      expect(locked.pending.single.url, open.pending.single.url);
      expect(locked.kanban, open.kanban);
      expect(
        open.recentChats.firstWhere((c) => c.id == 'd1').snippet,
        'Booked',
      );
    });
  });
}
