import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
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
    await count.refresh(resolvedProfile('work'));
    expect(count.waiting, 2);
    expect(transport.asked.map((a) => a.$2).toSet(), {'work'});
  });

  test('nothing waiting reads as zero', () async {
    transport.script['/memory pending'] = noPendingMemory;
    await count.refresh(resolvedProfile('work'));
    expect(count.waiting, 0);
  });

  test('a read that fails shows no count', () async {
    await count.refresh(resolvedProfile('work'));
    transport.script['/memory pending'] = const GatewayConnectionClosed();
    transport.script['/skills pending'] = const GatewayConnectionClosed();
    await count.refresh(resolvedProfile('work'));
    expect(count.waiting, isNull);
  });

  test('another profile starts without the first one count', () async {
    await count.refresh(resolvedProfile('work'));
    final gate = Completer<String>();
    transport.script['/memory pending'] = gate;
    final reading = count.refresh(resolvedProfile('home'));
    expect(count.waiting, isNull);
    gate.complete(noPendingMemory);
    await reading;
    expect(count.waiting, 0);
  });

  test('a late answer of an earlier profile is dropped', () async {
    final slow = Completer<String>();
    transport.script['/memory pending'] = slow;
    final first = count.refresh(resolvedProfile('work'));
    transport.script['/memory pending'] = noPendingMemory;
    await count.refresh(resolvedProfile('home'));
    slow.complete(_two);
    await first;
    expect(count.waiting, 0);
  });

  test('triggers that overlap share one read of the profile', () async {
    final gate = Completer<String>();
    transport.script['/memory pending'] = gate;
    final first = count.refresh(resolvedProfile('work'));
    final second = count.refresh(resolvedProfile('work'));
    final third = count.refreshIfStale(resolvedProfile('work'));
    gate.complete(_two);
    await Future.wait([first, second, third]);
    expect(count.waiting, 2);
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(1),
    );
    expect(
      transport.slashRuns.where((c) => c == '/skills pending'),
      hasLength(1),
    );
  });

  test(
    'a read that must see the latest decisions replaces one in flight',
    () async {
      final stale = Completer<String>();
      transport.script['/memory pending'] = stale;
      final first = count.refresh(resolvedProfile('work'));
      transport.script['/memory pending'] = noPendingMemory;
      await count.refresh(resolvedProfile('work'), supersede: true);
      stale.complete(_two);
      await first;
      expect(count.waiting, 0);
      expect(
        transport.slashRuns.where((c) => c == '/memory pending'),
        hasLength(2),
      );
    },
  );

  test('a read asked for after the last one ended is made', () async {
    await count.refresh(resolvedProfile('work'));
    await count.refresh(resolvedProfile('work'));
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test('on resume it reads at most every five minutes', () async {
    await count.refreshIfStale(resolvedProfile('work'));
    await count.refreshIfStale(resolvedProfile('work'));
    now = now.add(const Duration(minutes: 4, seconds: 59));
    await count.refreshIfStale(resolvedProfile('work'));
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(1),
    );
    now = now.add(const Duration(seconds: 2));
    await count.refreshIfStale(resolvedProfile('work'));
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test('on resume another profile is read at once', () async {
    await count.refreshIfStale(resolvedProfile('work'));
    await count.refreshIfStale(resolvedProfile('home'));
    expect(
      transport.slashRuns.where((c) => c == '/memory pending'),
      hasLength(2),
    );
  });

  test('clearing forgets the count', () async {
    await count.refresh(resolvedProfile('work'));
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
