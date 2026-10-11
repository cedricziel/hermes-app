import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/spotlight/chat_spotlight_indexer.dart';
import 'package:hermes_app/src/spotlight/spotlight_index.dart';
import 'package:hermes_app/src/spotlight/spotlight_settings.dart';
import 'package:hermes_app/src/surfaces/chat_hints.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/surfaces/surface_snapshots.dart'
    show SurfaceSession;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_spotlight_index.dart';
import '../support/fake_surface_storage.dart';
import '../support/recorded_events.dart';

const _flagKey = 'hermes.spotlight.dirty';

/// Preferences whose writes of the indexer's flag can be made to fail.
base class _FlakyPrefs extends InMemorySharedPreferencesAsync {
  _FlakyPrefs() : super.empty();

  var failing = false;

  @override
  Future<bool> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    if (failing && key == _flagKey) throw StateError('disk full');
    return super.setBool(key, value, options);
  }
}

/// A storage whose read waits for [gate].
class _SlowStorage extends FakeSurfaceStorage {
  final gate = Completer<void>();

  @override
  Future<String?> load() async {
    await gate.future;
    return super.load();
  }
}

final noon = DateTime.utc(2026, 10, 10, 12);

RecentChat chat(
  String id,
  String title, {
  String? snippet,
  String profile = 'default',
}) => RecentChat(
  profile: profile,
  id: id,
  title: title,
  snippet: snippet,
  updatedAt: noon,
);

SurfaceSnapshot snapshot(
  List<RecentChat> chats, {
  bool signedIn = true,
  bool kanban = false,
}) => SurfaceSnapshot(
  updatedAt: noon,
  signedIn: signedIn,
  recentChats: chats,
  kanban: kanban ? const KanbanSummary(blocked: 1, review: 0) : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsync prefs;
  late FakeSpotlightIndex index;
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late SpotlightSettings settings;
  late AppLockController lock;
  late StreamController<void> signedOut;
  late ChatSpotlightIndexer indexer;
  late RecordedEvents events;

  ChatSpotlightIndexer newIndexer() => ChatSpotlightIndexer(
    index: index,
    settings: settings,
    store: store,
    appLock: lock,
    signedOut: signedOut.stream,
    prefs: prefs,
    events: events.call,
  );

  Future<void> settle() => pumpEventQueue();

  Future<void> record(SurfaceSnapshot next) async {
    await store.write(next);
    await settle();
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    index = FakeSpotlightIndex();
    events = RecordedEvents();
    storage = FakeSurfaceStorage();
    store = SurfaceSnapshotStore(storage: storage);
    settings = SpotlightSettings(prefs: prefs);
    lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    signedOut = StreamController<void>.broadcast(sync: true);
    await lock.load();
    await settings.load();
    indexer = newIndexer();
  });

  tearDown(() async {
    indexer.dispose();
    lock.dispose();
    settings.dispose();
    await signedOut.close();
    await store.dispose();
  });

  test('indexes nothing while the switch is off', () async {
    await settings.setEnabled(false);
    await indexer.start();
    await record(snapshot([chat('a', 'Trip plan')]));

    expect(index.calls, isEmpty);
  });

  test('replaces the chat domain from the recent chats once on', () async {
    await indexer.start();
    await record(
      snapshot([
        chat('a', 'Trip plan', snippet: 'Booked the flights'),
        chat('b', 'Groceries', profile: 'work'),
      ]),
    );

    await settings.setEnabled(true);
    await settle();

    expect(index.calls, ['replace chat']);
    expect(index.items['chat'], const [
      SpotlightItem(
        domain: 'chat',
        id: 'default/a',
        title: 'Trip plan',
        text: 'Booked the flights',
        url: 'hermes://chat?profile=default&id=a',
      ),
      SpotlightItem(
        domain: 'chat',
        id: 'work/b',
        title: 'Groceries',
        text: '',
        url: 'hermes://chat?profile=work&id=b',
      ),
    ]);
  });

  test('indexes the snapshot stored by an earlier run', () async {
    await storage.save(snapshot([chat('a', 'Trip plan')]).encode());
    await settings.setEnabled(true);

    await indexer.start();
    await settle();

    expect(index.items['chat']!.single.title, 'Trip plan');
  });

  group('while on', () {
    setUp(() async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan', snippet: 'Booked')]));
      index.calls.clear();
    });

    test('makes no call for a snapshot that says the same', () async {
      await store.write(
        SurfaceSnapshot(
          updatedAt: noon.add(const Duration(minutes: 1)),
          recentChats: [chat('a', 'Trip plan', snippet: 'Booked')],
          kanban: const KanbanSummary(blocked: 1, review: 0),
        ),
      );
      await settle();

      expect(index.calls, isEmpty);
    });

    test('updates a renamed chat and drops one that left the set', () async {
      await record(
        snapshot([
          chat('a', 'Lisbon trip', snippet: 'Booked'),
          chat('b', 'Groceries'),
        ]),
      );
      expect(
        [for (final i in index.items['chat']!) i.title],
        ['Lisbon trip', 'Groceries'],
      );

      await record(snapshot([chat('b', 'Groceries')]));

      expect([for (final i in index.items['chat']!) i.title], ['Groceries']);
    });

    test('changes items in place and removes only the dropped ones', () async {
      await record(snapshot([chat('a', 'Trip plan'), chat('b', 'Groceries')]));
      index.calls.clear();
      index.updates.clear();

      await record(snapshot([chat('b', 'Groceries'), chat('c', 'Taxes')]));

      expect(index.calls, ['update chat']);
      final (upsert, remove) = index.updates.single;
      expect([for (final i in upsert) i.title], ['Taxes']);
      expect(remove, ['hermes://chat?profile=default&id=a']);
    });

    test('leaves out chats that have no real title', () async {
      await record(
        snapshot([
          chat('a', kUnnamedChatLabel, snippet: 'Plan a trip to Lisbon'),
          chat('b', 'Groceries'),
          chat('c', ''),
        ]),
      );

      expect([for (final i in index.items['chat']!) i.title], ['Groceries']);
    });

    test('removes everything when the switch is turned off', () async {
      await settings.setEnabled(false);
      await settle();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });

    test('removes everything for a signed-out snapshot', () async {
      await record(snapshot([], signedIn: false));

      expect(index.calls, ['deleteAll']);
    });

    test(
      'removes everything on sign-out, before the snapshot says so',
      () async {
        signedOut.add(null);
        await settle();

        expect(index.calls, ['deleteAll']);
        expect(index.items, isEmpty);
      },
    );

    test('calls deleteAll once, not for every later snapshot', () async {
      signedOut.add(null);
      await settle();
      await record(snapshot([], signedIn: false));
      await record(snapshot([], signedIn: false));

      expect(index.calls, ['deleteAll']);
    });

    test('indexes again after signing back in', () async {
      signedOut.add(null);
      await settle();

      await record(snapshot([chat('c', 'Fresh')]));

      expect(index.items['chat']!.single.title, 'Fresh');
    });

    test('leaves other domains alone when the chat set changes', () async {
      await index.replace('memory', const [
        SpotlightItem(
          domain: 'memory',
          id: 'm',
          title: 'Note',
          text: '',
          url: 'hermes://memory?id=m',
        ),
      ]);

      await record(snapshot([chat('b', 'Groceries')]));

      expect(index.items['memory'], hasLength(1));
    });

    test('runs one call at a time and ends on the latest state', () async {
      index.gate = Completer<void>();
      final gate = index.gate!;

      unawaited(store.write(snapshot([chat('b', 'Second')])));
      await settle();
      unawaited(store.write(snapshot([chat('c', 'Third')])));
      unawaited(settings.setEnabled(false));
      await settle();
      gate.complete();
      index.gate = null;
      await settle();

      expect(index.maxInFlight, 1);
      expect(index.items, isEmpty);
      expect(index.calls.last, 'deleteAll');
    });
  });

  group('App Lock', () {
    setUp(() async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      index.calls.clear();
    });

    test('removes everything when it is turned on', () async {
      await lock.setEnabled(true);
      await settle();

      expect(index.calls, ['deleteAll']);
    });

    test('indexes nothing while it is on', () async {
      await lock.setEnabled(true);
      await record(snapshot([chat('b', 'Groceries')]));

      expect(index.items, isEmpty);
    });

    test('indexes the chats again on the next snapshot once off', () async {
      await lock.setEnabled(true);
      await record(
        SurfaceSnapshot(
          updatedAt: noon,
          recentChats: [chat('a', 'Trip plan').redacted()],
        ),
      );
      await lock.setEnabled(false);
      await record(snapshot([chat('a', 'Trip plan')]));

      expect(index.items['chat']!.single.title, 'Trip plan');
    });
  });

  group('a failed removal', () {
    test('is retried on the next start', () async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      index.succeeds = false;
      await settings.setEnabled(false);
      await settle();
      indexer.dispose();
      index.calls.clear();
      index.succeeds = true;

      indexer = newIndexer();
      await indexer.start();
      await settle();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });

    test('is not repeated once it worked', () async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      await settings.setEnabled(false);
      await settle();
      indexer.dispose();
      index.calls.clear();

      indexer = newIndexer();
      await indexer.start();
      await settle();

      expect(index.calls, isEmpty);
    });

    test('is retried with the next snapshot', () async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      index.succeeds = false;
      await record(snapshot([], signedIn: false));
      index.succeeds = true;

      await record(
        SurfaceSnapshot(updatedAt: noon, signedIn: false, profile: 'other'),
      );

      expect(index.items, isEmpty);
      expect(index.calls.where((c) => c == 'deleteAll'), hasLength(2));
    });

    test('a failed index call is retried by the next snapshot', () async {
      await settings.setEnabled(true);
      await indexer.start();
      index.succeeds = false;
      await record(snapshot([chat('a', 'Trip plan')]));
      index.succeeds = true;

      await record(snapshot([chat('a', 'Trip plan')], kanban: true));

      expect(index.items['chat']!.single.title, 'Trip plan');
    });
  });

  group('while the device is locked', () {
    setUp(() async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      index
        ..calls.clear()
        ..available = false;
    });

    test('makes no call and logs nothing', () async {
      await record(snapshot([chat('b', 'Groceries')]));
      await settings.setEnabled(false);
      await settle();

      expect(index.calls, isEmpty);
      expect(events.named('spotlight.index_failed'), isEmpty);
    });

    test('catches up once the device is unlocked', () async {
      await record(snapshot([chat('b', 'Groceries')]));

      index.available = true;
      index.becameAvailableController.add(null);
      await settle();

      expect([for (final i in index.items['chat']!) i.title], ['Groceries']);
    });

    test('removes everything after a sign-out once it is unlocked', () async {
      signedOut.add(null);
      await settle();
      expect(index.calls, isEmpty);

      index.available = true;
      index.becameAvailableController.add(null);
      await settle();

      expect(index.calls, ['deleteAll']);
    });
  });

  group('starting', () {
    test('a sign-out during the read of the stored snapshot wins', () async {
      final slow = _SlowStorage();
      await slow.save(snapshot([chat('a', 'Trip plan')]).encode());
      store = SurfaceSnapshotStore(storage: slow);
      indexer.dispose();
      indexer = newIndexer();
      await settings.setEnabled(true);

      final starting = indexer.start();
      await settle();
      signedOut.add(null);
      slow.gate.complete();
      await starting;
      await settle();

      expect(index.calls, isEmpty);
    });
  });

  group('a stored snapshot of an account that may be gone', () {
    late ValueNotifier<SurfaceSession> session;

    setUp(() async {
      session = ValueNotifier(SurfaceSession.unknown);
      addTearDown(session.dispose);
      await settings.setEnabled(true);
      await store.write(snapshot([chat('a', 'Trip plan')]));
      indexer.dispose();
      indexer = ChatSpotlightIndexer(
        index: index,
        settings: settings,
        store: store,
        appLock: lock,
        signedOut: signedOut.stream,
        session: () => session.value,
        sessionChanges: session,
        prefs: prefs,
        events: events.call,
      );
    });

    Future<void> owe() async {
      await prefs.setBool(_flagKey, true);
      index.items['chat'] = const [
        SpotlightItem(
          domain: 'chat',
          id: 'default/a',
          title: 'Trip plan',
          text: '',
          url: 'hermes://chat?profile=default&id=a',
        ),
      ];
    }

    test('is not indexed when the app settled signed out', () async {
      session.value = SurfaceSession.signedOut;

      await indexer.start();
      await settle();

      expect(index.calls, isEmpty);
    });

    test('is removed when the app settled signed out', () async {
      await owe();
      session.value = SurfaceSession.signedOut;

      await indexer.start();
      await settle();

      expect(index.calls, ['deleteAll']);
    });

    test('waits while the connection is not known', () async {
      await indexer.start();
      await settle();

      expect(index.calls, isEmpty);
    });

    test('keeps what is indexed while the connection is not known', () async {
      await owe();

      await indexer.start();
      await settle();

      expect(index.calls, isEmpty);
      expect(index.items['chat'], isNotEmpty);
    });

    test('is indexed once the connection says signed in', () async {
      await indexer.start();
      session.value = SurfaceSession.signedIn;
      await settle();

      expect(index.items['chat']!.single.title, 'Trip plan');
    });

    test('is dropped once the connection says signed out', () async {
      await owe();
      await indexer.start();

      session.value = SurfaceSession.signedOut;
      await settle();

      expect(index.calls, ['deleteAll']);
    });

    test('still honours the switch while the connection is unknown', () async {
      await owe();
      await indexer.start();

      await settings.setEnabled(false);
      await settle();

      expect(index.calls, ['deleteAll']);
    });

    test('gives way to a snapshot written in this app', () async {
      await indexer.start();

      await record(snapshot([chat('b', 'Groceries')]));

      expect([for (final i in index.items['chat']!) i.title], ['Groceries']);
    });
  });

  test('a restart while the device is locked clears the removal that was '
      'owed once it is unlocked', () async {
    await settings.setEnabled(true);
    await store.clear();
    await prefs.setBool(_flagKey, true);
    index.items['chat'] = const [
      SpotlightItem(
        domain: 'chat',
        id: 'default/a',
        title: 'Trip plan',
        text: '',
        url: 'hermes://chat?profile=default&id=a',
      ),
    ];
    index.available = false;
    indexer.dispose();
    indexer = newIndexer();

    await indexer.start();
    await settle();
    expect(index.calls, isEmpty);

    index.available = true;
    index.becameAvailableController.add(null);
    await settle();

    expect(index.calls, ['deleteAll']);
    expect(index.items, isEmpty);
    expect(await prefs.getBool(_flagKey), isFalse);
  });

  group('the flag that a removal is owed', () {
    test('survives a failed write and is saved by a later change', () async {
      final flaky = _FlakyPrefs();
      SharedPreferencesAsyncPlatform.instance = flaky;
      prefs = SharedPreferencesAsync();
      indexer.dispose();
      indexer = newIndexer();
      flaky.failing = true;
      await settings.setEnabled(true);
      await indexer.start();

      await record(snapshot([chat('a', 'Trip plan')]));

      expect(index.items['chat'], isNotNull);
      expect(await prefs.getBool(_flagKey), isNull);
      expect(events.named('spotlight.index_failed'), [
        {
          'operation': 'save_flag',
          'spotlight.domain': 'all',
          'error.type': 'StateError',
        },
      ]);

      flaky.failing = false;
      await record(snapshot([chat('b', 'Groceries')]));

      expect(await prefs.getBool(_flagKey), isTrue);
    });
  });

  group('when a background run put chats in the index meanwhile', () {
    setUp(() async {
      await settings.setEnabled(true);
      await indexer.start();
      await settle();
      // What a run leaves: the index holds chats and the saved flag says so,
      // while this indexer never indexed anything itself.
      await prefs.setBool(_flagKey, true);
      index.items['chat'] = const [
        SpotlightItem(
          domain: 'chat',
          id: 'default/a',
          title: 'Trip plan',
          text: '',
          url: 'hermes://chat?profile=default&id=a',
        ),
      ];
    });

    test('removes everything when the switch is turned off', () async {
      await settings.setEnabled(false);
      await settle();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });

    test('removes everything when App Lock is turned on', () async {
      await lock.setEnabled(true);
      await settle();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });

    test('removes everything on sign-out', () async {
      signedOut.add(null);
      await settle();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });
  });

  group('for one background run, with no App Lock controller', () {
    ChatSpotlightIndexer once({required bool locked}) => ChatSpotlightIndexer(
      index: index,
      settings: settings,
      store: store,
      locked: () => locked,
      prefs: prefs,
    );

    test('has indexed the stored chats when it settles', () async {
      await storage.save(snapshot([chat('a', 'Trip plan')]).encode());
      await settings.setEnabled(true);
      final run = once(locked: false);
      addTearDown(run.dispose);

      await run.start();
      await run.settled();

      expect(index.calls, ['replace chat']);
      expect(index.items['chat']!.single.title, 'Trip plan');
    });

    test('indexes nothing while locked, and clears what it holds', () async {
      await storage.save(snapshot([chat('a', 'Trip plan')]).encode());
      await settings.setEnabled(true);
      await prefs.setBool(_flagKey, true);
      final run = once(locked: true);
      addTearDown(run.dispose);

      await run.start();
      await run.settled();

      expect(index.calls, ['deleteAll']);
    });

    test('leaves a device that is locked alone', () async {
      await storage.save(snapshot([chat('a', 'Trip plan')]).encode());
      await settings.setEnabled(true);
      index.available = false;
      final run = once(locked: false);
      addTearDown(run.dispose);

      await run.start();
      await run.settled();

      expect(index.calls, isEmpty);
    });

    test('settles at once when nothing changed', () async {
      final run = once(locked: false);
      addTearDown(run.dispose);

      await run.settled();

      expect(index.calls, isEmpty);
    });
  });
}
