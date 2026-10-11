import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';

SurfaceSnapshot full() => SurfaceSnapshot(
  updatedAt: DateTime.utc(2026, 10, 10, 12),
  profile: 'default',
  profiles: const ['default', 'work'],
  recentChats: [
    RecentChat(
      profile: 'default',
      id: 'abc',
      title: 'Trip plan',
      snippet: 'Booked…',
      updatedAt: DateTime.utc(2026, 10, 10, 11),
    ),
  ],
  pending: [
    PendingRequest(
      profile: 'default',
      threadId: 'abc',
      threadTitle: 'Trip plan',
      kind: PendingKind.approval,
      requestId: 'r1',
      createdAt: DateTime.utc(2026, 10, 10, 11, 30),
    ),
  ],
  kanban: const KanbanSummary(blocked: 1, review: 2),
  schedules: ScheduleSummary(
    nextRunAt: DateTime.utc(2026, 10, 11, 8),
    nextJobName: 'Daily digest',
    lastFailed: FailedJob(
      profile: 'default',
      jobId: 'j1',
      name: 'Backup',
      at: DateTime.utc(2026, 10, 9, 3),
    ),
  ),
);

RecentChat chat(int n, {String? snippet, String title = 'Chat'}) => RecentChat(
  profile: 'default',
  id: 'c$n',
  title: title,
  snippet: snippet,
  updatedAt: DateTime.utc(2026, 10, 10).add(Duration(minutes: n)),
);

void main() {
  test('writes the shape of the contract', () {
    expect(full().toJson(), {
      'version': 1,
      'updatedAt': '2026-10-10T12:00:00Z',
      'revision': 0,
      'signedIn': true,
      'profile': 'default',
      'profiles': ['default', 'work'],
      'recentChats': [
        {
          'profile': 'default',
          'id': 'abc',
          'title': 'Trip plan',
          'snippet': 'Booked…',
          'updatedAt': '2026-10-10T11:00:00Z',
          'url': 'hermes://chat?profile=default&id=abc',
        },
      ],
      'pending': [
        {
          'profile': 'default',
          'threadId': 'abc',
          'threadTitle': 'Trip plan',
          'kind': 'approval',
          'requestId': 'r1',
          'createdAt': '2026-10-10T11:30:00Z',
          'url': 'hermes://chat?profile=default&id=abc',
        },
      ],
      'kanban': {'blocked': 1, 'review': 2},
      'schedules': {
        'nextRunAt': '2026-10-11T08:00:00Z',
        'nextJobName': 'Daily digest',
        'lastFailed': {
          'profile': 'default',
          'jobId': 'j1',
          'name': 'Backup',
          'at': '2026-10-09T03:00:00Z',
          'url': 'hermes://schedules?profile=default&job=j1',
        },
      },
    });
  });

  test('reads back what it wrote', () {
    final read = SurfaceSnapshot.fromJson(jsonEncode(full().toJson()));

    expect(read, full());
  });

  test('percent-encodes the ids in a link', () {
    final row = RecentChat(
      profile: 'my work',
      id: 'a&b=c',
      title: 'x',
      updatedAt: DateTime.utc(2026),
    );

    expect(row.url, 'hermes://chat?profile=my%20work&id=a%26b%3Dc');
  });

  test('keeps the ten newest chats, newest first', () {
    final snapshot = SurfaceSnapshot(
      updatedAt: DateTime.utc(2026),
      recentChats: [for (var n = 0; n < 14; n++) chat(n)],
    );

    expect(snapshot.recentChats, hasLength(10));
    expect(snapshot.recentChats.first.id, 'c13');
    expect(snapshot.recentChats.last.id, 'c4');
  });

  test('cuts a snippet to one line of at most 120 characters', () {
    final snippet = chat(1, snippet: 'line one\n\n  line two ${'x' * 200}');

    expect(snippet.snippet, startsWith('line one line two x'));
    expect(snippet.snippet!.characters.length, 120);
    expect(snippet.snippet, endsWith('…'));
  });

  test('cuts a long title', () {
    final title = chat(1, title: 'y' * 200).title;

    expect(title.characters.length, lessThanOrEqualTo(80));
    expect(title, endsWith('…'));
  });

  test('an empty snippet is left out', () {
    expect(chat(1, snippet: '  \n ').snippet, isNull);
    expect(chat(1, snippet: '  \n ').toJson().containsKey('snippet'), isFalse);
  });

  test('Kanban and schedules are null when the server has none', () {
    final json = SurfaceSnapshot(updatedAt: DateTime.utc(2026)).toJson();

    expect(json['kanban'], isNull);
    expect(json['schedules'], isNull);
  });

  test('the signed-out form holds nothing', () {
    final json = SurfaceSnapshot.signedOut(DateTime.utc(2026)).toJson();

    expect(json['signedIn'], isFalse);
    expect(json['profile'], isNull);
    expect(json['profiles'], isEmpty);
    expect(json['recentChats'], isEmpty);
    expect(json['pending'], isEmpty);
    expect(json['kanban'], isNull);
    expect(json['schedules'], isNull);
  });

  test('unreadable or newer data reads as null', () {
    expect(SurfaceSnapshot.fromJson('not json'), isNull);
    expect(SurfaceSnapshot.fromJson('[]'), isNull);
    expect(
      SurfaceSnapshot.fromJson(jsonEncode({...full().toJson(), 'version': 2})),
      isNull,
    );
    expect(SurfaceSnapshot.fromJson(null), isNull);
  });

  test('data of the wrong type reads as null', () {
    final good = full().toJson();
    for (final broken in <Map<String, Object?>>[
      {...good, 'profiles': 'default'},
      {...good, 'profile': 5},
      {...good, 'signedIn': 'yes'},
      {
        ...good,
        'recentChats': {'a': 1},
      },
      {...good, 'pending': 'none'},
      {
        ...good,
        'schedules': {'nextRunAt': 7, 'nextJobName': 3},
      },
      {...good, 'updatedAt': 12},
    ]) {
      expect(
        SurfaceSnapshot.fromJson(jsonEncode(broken)),
        isNull,
        reason: '$broken',
      );
    }
  });

  test('a row it cannot read is skipped', () {
    final json = full().toJson()
      ..['recentChats'] = [
        {'id': 'no-profile'},
        full().recentChats.single.toJson(),
      ];

    final read = SurfaceSnapshot.fromJson(jsonEncode(json))!;

    expect(read.recentChats.map((c) => c.id), ['abc']);
  });

  test('redacting empties titles and drops snippets and job names', () {
    final redacted = full().redacted();

    expect(redacted.recentChats.single.title, '');
    expect(redacted.recentChats.single.snippet, isNull);
    expect(redacted.pending.single.threadTitle, '');
    expect(redacted.schedules!.nextJobName, isNull);
    expect(redacted.schedules!.lastFailed!.name, '');
    expect(redacted.recentChats.single.url, full().recentChats.single.url);
    expect(redacted.pending.single.requestId, 'r1');
    expect(redacted.kanban, full().kanban);
    expect(redacted.schedules!.nextRunAt, full().schedules!.nextRunAt);
  });

  test('holds no token, address or identity', () {
    final json = jsonEncode(full().toJson());

    expect(json, isNot(contains('token')));
    expect(json, isNot(contains('@')));
    expect(
      RegExp(r'[a-z]+://').allMatches(json).map((m) => m.group(0)).toSet(),
      {'hermes://'},
    );
  });

  test('the update time does not count as a change', () {
    final later = SurfaceSnapshot(
      updatedAt: DateTime.utc(2027),
      profile: 'default',
    );
    final earlier = SurfaceSnapshot(
      updatedAt: DateTime.utc(2026),
      profile: 'default',
    );

    expect(later.sameContent(earlier), isTrue);
    expect(later == earlier, isFalse);
  });
}
