import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_send_journal.dart';

void main() {
  test('restart preserves dispatch uncertainty and saved completion', () async {
    final store = MemoryJournalStore();
    final now = DateTime.utc(2026, 10, 13);
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('context', 1);
    final identity = WatchSendIdentity(
      'send',
      now.millisecondsSinceEpoch,
      null,
      null,
      'prompt',
    );
    await journal.reserve(context, identity);
    await journal.markDispatched(context, 'send');
    final restarted = WatchSendJournal(store: store, now: () => now);
    expect((await restarted.lookup(context, 'send'))!.state, 'uncertain');
    await restarted.complete(context, 'send', {
      'ok': true,
      'text': 'owned reply',
    });
    expect(
      (await WatchSendJournal(
        store: store,
        now: () => now,
      ).lookup(context, 'send'))!.result!['text'],
      'owned reply',
    );
  });
  test('changed payload and timestamp cannot reuse an identity', () async {
    final journal = WatchSendJournal(
      store: MemoryJournalStore(),
      now: () => DateTime.utc(2026),
    );
    const context = WatchContext('c', 1);
    final at = DateTime.utc(2026).millisecondsSinceEpoch;
    await journal.reserve(
      context,
      WatchSendIdentity('id', at, 'p', 't', 'first'),
    );
    await expectLater(
      journal.reserve(
        context,
        WatchSendIdentity('id', at, 'p', 't', 'changed'),
      ),
      throwsA(isA<WatchJournalException>()),
    );
    await expectLater(
      journal.reserve(
        context,
        WatchSendIdentity('id', at + 1, 'p', 't', 'first'),
      ),
      throwsA(isA<WatchJournalException>()),
    );
  });
  test('write failure never creates dispatch evidence', () async {
    final store = MemoryJournalStore()..failWrites = true;
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(store: store, now: () => now);
    await expectLater(
      journal.reserve(
        const WatchContext('c', 1),
        WatchSendIdentity(
          'id',
          now.millisecondsSinceEpoch,
          null,
          null,
          'private prompt',
        ),
      ),
      throwsStateError,
    );
    expect(store.values, isEmpty);
  });
  test('failed purge leaves an invalidation marker after restart', () async {
    final store = MemoryJournalStore();
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('c', 1);
    await journal.reserve(
      context,
      WatchSendIdentity(
        'id',
        now.millisecondsSinceEpoch,
        null,
        null,
        'private prompt',
      ),
    );
    store.failDelete = true;
    await expectLater(journal.invalidate(context), throwsStateError);
    await expectLater(
      WatchSendJournal(store: store).lookup(context, 'id'),
      throwsA(isA<WatchJournalException>()),
    );
  });
  test(
    'forget releases a slot while blocking delayed first delivery',
    () async {
      final now = DateTime.utc(2026);
      final journal = WatchSendJournal(
        store: MemoryJournalStore(),
        now: () => now,
      );
      const context = WatchContext('c', 1);
      final identity = WatchSendIdentity(
        'id',
        now.millisecondsSinceEpoch,
        null,
        null,
        'private prompt',
      );
      await journal.reserve(context, identity);
      await journal.forget(context, 'id');
      expect(await journal.lookup(context, 'id'), isNull);
      expect((await journal.reserve(context, identity))!.state, 'uncertain');
    },
  );
  test('expired and future first delivery reject without records', () async {
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(
      store: MemoryJournalStore(),
      now: () => now,
    );
    const context = WatchContext('c', 1);
    await expectLater(
      journal.reserve(
        context,
        WatchSendIdentity(
          'old',
          now.subtract(const Duration(minutes: 11)).millisecondsSinceEpoch,
          null,
          null,
          'text',
        ),
      ),
      throwsA(isA<WatchJournalException>()),
    );
    await expectLater(
      journal.reserve(
        context,
        WatchSendIdentity(
          'future',
          now.add(const Duration(seconds: 61)).millisecondsSinceEpoch,
          null,
          null,
          'text',
        ),
      ),
      throwsA(isA<WatchJournalException>()),
    );
    expect(await journal.lookup(context, 'old'), isNull);
  });
  test('corrupted storage fails closed', () async {
    final store = MemoryJournalStore();
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('c', 1);
    await journal.reserve(
      context,
      WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
    );
    store.values[store.values.keys.single] = '{broken';
    await expectLater(
      journal.lookup(context, 'id'),
      throwsA(isA<WatchJournalException>()),
    );
  });

  test(
    'active capacity refuses new sends and detached expiry releases slots',
    () async {
      var now = DateTime.utc(2026);
      final journal = WatchSendJournal(
        store: MemoryJournalStore(),
        now: () => now,
      );
      const context = WatchContext('c', 1);
      await fillJournal(journal, context, now);
      await expectLater(
        journal.reserve(
          context,
          WatchSendIdentity(
            'overflow',
            now.millisecondsSinceEpoch,
            null,
            null,
            'text',
          ),
        ),
        throwsA(isA<WatchJournalException>()),
      );
      journal.detach(context, '0');
      now = now.add(const Duration(days: 7));
      expect(
        await journal.reserve(
          context,
          WatchSendIdentity(
            'new',
            now.millisecondsSinceEpoch,
            null,
            null,
            'text',
          ),
        ),
        isNull,
      );
      expect((await journal.lookup(context, '1'))!.state, 'uncertain');
    },
  );
  test('terminal pressure eviction keeps a non-dispatch tombstone', () async {
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(
      store: MemoryJournalStore(),
      now: () => now,
    );
    const context = WatchContext('c', 1);
    await fillJournal(journal, context, now);
    await journal.complete(context, '0', {'ok': true, 'text': 'done'});
    expect(
      await journal.reserve(
        context,
        WatchSendIdentity(
          'new',
          now.millisecondsSinceEpoch,
          null,
          null,
          'text',
        ),
      ),
      isNull,
    );
    expect(
      (await journal.reserve(
        context,
        WatchSendIdentity('0', now.millisecondsSinceEpoch, null, null, 'text'),
      ))!.state,
      'uncertain',
    );
  });

  test(
    'journal telemetry carries fixed values and cannot break persistence',
    () async {
      final now = DateTime.utc(2026);
      final events = <Map<String, Object>>[];
      final journal = WatchSendJournal(
        store: MemoryJournalStore(),
        now: () => now,
        events: (name, [attributes = const <String, Object>{}]) {
          expect(name, 'watch.send.journal');
          events.add(Map<String, Object>.from(attributes));
          throw StateError('telemetry unavailable');
        },
      );
      await journal.reserve(
        const WatchContext('private-context', 1),
        WatchSendIdentity(
          'private-send',
          now.millisecondsSinceEpoch,
          'private-profile',
          null,
          'private prompt',
        ),
      );
      expect(events, [
        {'operation': 'read', 'outcome': 'success'},
        {'operation': 'write', 'outcome': 'success'},
      ]);
    },
  );

  test('active Forget retains recovery and late completion cannot restore purged data', () async {
    final now = DateTime.utc(2026);
    final store = MemoryJournalStore();
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('c', 1);
    await journal.reserve(
      context,
      WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
    );
    await journal.markDispatched(context, 'id');
    await journal.forget(context, 'id');
    expect((await journal.lookup(context, 'id'))!.state, 'uncertain');
    final purged = journal.invalidate(context);
    await expectLater(
      journal.complete(context, 'id', {'ok': true, 'text': 'late'}),
      throwsA(isA<WatchJournalException>()),
    );
    await purged;
    expect(store.values.values, ['1']);
  });
  test(
    'tombstone still blocks delivery at the inclusive validity boundary',
    () async {
      var now = DateTime.utc(2026);
      final journal = WatchSendJournal(
        store: MemoryJournalStore(),
        now: () => now,
      );
      const context = WatchContext('c', 1);
      final identity = WatchSendIdentity(
        'id',
        now.millisecondsSinceEpoch,
        null,
        null,
        'text',
      );
      await journal.reserve(context, identity);
      await journal.forget(context, 'id');
      now = now.add(const Duration(minutes: 10));
      expect((await journal.reserve(context, identity))!.state, 'uncertain');
    },
  );
  test('malformed saved completion fails closed', () async {
    final store = MemoryJournalStore();
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('c', 1);
    await journal.reserve(
      context,
      WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
    );
    await journal.complete(context, 'id', {'ok': true, 'text': 'reply'});
    final key = store.values.keys.single;
    final data = jsonDecode(store.values[key]!) as Map<String, dynamic>;
    final records = data['records'] as Map<String, dynamic>;
    final record = records['id'] as Map<String, dynamic>;
    final result = record['result'] as Map<String, dynamic>;
    result['failed'] = 'wrong type';
    store.values[key] = jsonEncode(data);
    await expectLater(
      journal.lookup(context, 'id'),
      throwsA(isA<WatchJournalException>()),
    );
  });

  test('invalidation during existing reservation read never releases private reply', () async {
    final store = MemoryJournalStore();
    final now = DateTime.utc(2026);
    final journal = WatchSendJournal(store: store, now: () => now);
    const context = WatchContext('c', 1);
    await journal.reserve(
      context,
      WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
    );
    await journal.complete(context, 'id', {
      'ok': true,
      'text': 'private reply',
    });
    final release = Completer<void>();
    final started = Completer<void>();
    store.beforeRead = (key) async {
      if (!key.endsWith('.invalid')) {
        started.complete();
        await release.future;
      }
    };
    final lookup = journal.reserve(
      context,
      WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
    );
    await started.future;
    final rejected = expectLater(lookup, throwsA(isA<WatchJournalException>()));
    final purged = journal.invalidate(context);
    release.complete();
    await rejected;
    await purged;
  });
  test(
    'invalidation during reservation write never authorizes dispatch',
    () async {
      final store = MemoryJournalStore();
      final now = DateTime.utc(2026);
      final journal = WatchSendJournal(store: store, now: () => now);
      const context = WatchContext('c', 1);
      final release = Completer<void>();
      final started = Completer<void>();
      store.beforeWrite = (key) async {
        if (!key.endsWith('.invalid')) {
          started.complete();
          await release.future;
        }
      };
      final reserved = journal.reserve(
        context,
        WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
      );
      await started.future;
      final rejected = expectLater(
        reserved,
        throwsA(isA<WatchJournalException>()),
      );
      final purged = journal.invalidate(context);
      release.complete();
      await rejected;
      await purged;
    },
  );

  test(
    'invalidation during lookup write never releases private reply',
    () async {
      final store = MemoryJournalStore();
      final now = DateTime.utc(2026);
      final journal = WatchSendJournal(store: store, now: () => now);
      const context = WatchContext('c', 1);
      await journal.reserve(
        context,
        WatchSendIdentity('id', now.millisecondsSinceEpoch, null, null, 'text'),
      );
      await journal.complete(context, 'id', {
        'ok': true,
        'text': 'private reply',
      });
      final release = Completer<void>();
      final started = Completer<void>();
      store.beforeWrite = (key) async {
        if (!key.endsWith('.invalid')) {
          started.complete();
          await release.future;
        }
      };
      final lookup = journal.lookup(context, 'id');
      await started.future;
      final rejected = expectLater(
        lookup,
        throwsA(isA<WatchJournalException>()),
      );
      final purged = journal.invalidate(context);
      release.complete();
      await rejected;
      await purged;
    },
  );
  test('durable capability requires a successful protected write', () async {
    final store = MemoryJournalStore()..failWrites = true;
    final journal = WatchSendJournal(store: store);
    const context = WatchContext('c', 1);
    expect(await journal.available(context), isFalse);
    store.failWrites = false;
    expect(await journal.available(context), isTrue);
  });
  test(
    'compact tombstone capacity refuses dispatch until expiry releases it',
    () async {
      var now = DateTime.utc(2026);
      final journal = WatchSendJournal(
        store: MemoryJournalStore(),
        now: () => now,
      );
      const context = WatchContext('c', 1);
      await fillTombstones(journal, context, now);
      await expectLater(
        journal.reserve(
          context,
          WatchSendIdentity(
            'overflow',
            now.millisecondsSinceEpoch,
            null,
            null,
            'text',
          ),
        ),
        throwsA(isA<WatchJournalException>()),
      );
      now = now.add(const Duration(minutes: 11));
      expect(
        await journal.reserve(
          context,
          WatchSendIdentity(
            'fresh',
            now.millisecondsSinceEpoch,
            null,
            null,
            'text',
          ),
        ),
        isNull,
      );
    },
  );
}

class MemoryJournalStore implements WatchJournalStore {
  final values = <String, String>{};
  bool failWrites = false;
  bool failDelete = false;
  Future<void> Function(String)? beforeRead;
  Future<void> Function(String)? beforeWrite;
  @override
  Future<String?> read(String key) async {
    await beforeRead?.call(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key);
    if (failWrites) throw StateError('unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('unavailable');
    values.remove(key);
  }
}

Future<void> fillJournal(
  WatchSendJournal journal,
  WatchContext context,
  DateTime now,
) async {
  for (var index = 0; index < 100; index++) {
    await journal.reserve(
      context,
      WatchSendIdentity(
        '$index',
        now.millisecondsSinceEpoch,
        null,
        null,
        'text',
      ),
    );
    await journal.markDispatched(context, '$index');
  }
}

Future<void> fillTombstones(
  WatchSendJournal journal,
  WatchContext context,
  DateTime now,
) async {
  for (var index = 0; index < 1000; index++) {
    await journal.reserve(
      context,
      WatchSendIdentity(
        '$index',
        now.millisecondsSinceEpoch,
        null,
        null,
        'text',
      ),
    );
    await journal.forget(context, '$index');
  }
}
