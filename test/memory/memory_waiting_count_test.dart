import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_waiting_count.dart';

import 'memory_proposal_fixtures.dart';
import 'memory_proposal_support.dart';

const _two =
    'Pending memory writes (2):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002  add to memory: Other\n';

void main() {
  late ScriptedSlashTransport transport;
  late DateTime now;
  late MemoryWaitingCount count;

  setUp(() {
    transport = ScriptedSlashTransport()
      ..script['/memory pending'] = _two
      ..script['/skills pending'] = noPendingSkills;
    now = DateTime(2026, 1, 1, 12);
    count = MemoryWaitingCount(
      MemoryProposalsRepository(MemoryProposalSession(transport)),
      now: () => now,
    );
    addTearDown(count.dispose);
  });

  test('reads how many changes wait in the profile', () async {
    await count.refresh('work');
    expect(count.waiting, 2);
    expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
  });

  test('nothing waiting reads as zero', () async {
    transport.script['/memory pending'] = noPendingMemory;
    await count.refresh('work');
    expect(count.waiting, 0);
  });

  test('a read that fails shows no count', () async {
    await count.refresh('work');
    transport.script['/memory pending'] = StateError('socket');
    transport.script['/skills pending'] = StateError('socket');
    await count.refresh('work');
    expect(count.waiting, isNull);
  });

  test('another profile starts without the first one count', () async {
    await count.refresh('work');
    final gate = Completer<String>();
    transport.script['/memory pending'] = gate;
    final reading = count.refresh('home');
    expect(count.waiting, isNull);
    gate.complete(noPendingMemory);
    await reading;
    expect(count.waiting, 0);
  });

  test('a late answer of an earlier profile is dropped', () async {
    final slow = Completer<String>();
    transport.script['/memory pending'] = slow;
    final first = count.refresh('work');
    transport.script['/memory pending'] = noPendingMemory;
    await count.refresh('home');
    slow.complete(_two);
    await first;
    expect(count.waiting, 0);
  });

  test('on resume it reads at most every five minutes', () async {
    await count.refreshIfStale('work');
    await count.refreshIfStale('work');
    now = now.add(const Duration(minutes: 4, seconds: 59));
    await count.refreshIfStale('work');
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(1),
    );
    now = now.add(const Duration(seconds: 2));
    await count.refreshIfStale('work');
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test('on resume another profile is read at once', () async {
    await count.refreshIfStale('work');
    await count.refreshIfStale('home');
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test('clearing forgets the count', () async {
    await count.refresh('work');
    count.clear();
    expect(count.waiting, isNull);
  });

  group('memoryEntryLabel', () {
    test('adds the count only when something waits', () {
      expect(memoryEntryLabel(2), 'Memory · 2 waiting');
      expect(memoryEntryLabel(0), 'Memory');
      expect(memoryEntryLabel(null), 'Memory');
    });
  });
}
