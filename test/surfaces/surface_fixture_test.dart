import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';

const _dartFixture = 'test/fixtures/surface_snapshot_v1.json';
const _swiftFixture =
    'ios/HermesSurfaceKit/Tests/Fixtures/surface_snapshot_v1.json';

/// The snapshot the fixture holds: every section, two profiles, and
/// characters a link has to encode.
SurfaceSnapshot fixtureSnapshot() => SurfaceSnapshot(
  updatedAt: DateTime.utc(2026, 10, 10, 12),
  revision: 7,
  profile: 'default',
  profiles: const ['default', 'work'],
  recentChats: [
    RecentChat(
      profile: 'default',
      id: 'abc',
      title: 'Trip plan',
      snippet: 'Booked the flights and the first hotel.',
      updatedAt: DateTime.utc(2026, 10, 10, 11, 50),
    ),
    RecentChat(
      profile: 'work',
      id: 'w 1',
      title: 'C++ review',
      snippet: 'The destructor runs twice.',
      updatedAt: DateTime.utc(2026, 10, 10, 10),
    ),
    RecentChat(
      profile: 'default',
      id: 'c++',
      title: 'Compiler notes',
      snippet: 'Why 1 + 1 is not 2 in C++.',
      updatedAt: DateTime.utc(2026, 10, 9, 20),
    ),
    RecentChat(
      profile: 'default',
      id: 'def',
      title: 'Groceries',
      updatedAt: DateTime.utc(2026, 10, 9, 18),
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
    PendingRequest(
      profile: 'work',
      threadId: 'w 1',
      threadTitle: 'C++ review',
      kind: PendingKind.question,
      requestId: 'r2',
      createdAt: DateTime.utc(2026, 10, 10, 11, 45),
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

void main() {
  test('the fixture is what the app writes', () {
    final fixture = jsonDecode(File(_dartFixture).readAsStringSync());
    expect(fixtureSnapshot().toJson(), fixture);
  });

  test('the Swift package decodes the same fixture', () {
    expect(
      File(_swiftFixture).readAsStringSync(),
      File(_dartFixture).readAsStringSync(),
    );
  });
}
