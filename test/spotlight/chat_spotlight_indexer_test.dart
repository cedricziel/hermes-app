import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/spotlight/chat_spotlight_indexer.dart';
import 'package:hermes_app/src/spotlight/spotlight_index.dart';
import 'package:hermes_app/src/spotlight/spotlight_settings.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_spotlight_index.dart';
import '../support/fake_surface_storage.dart';

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

SurfaceSnapshot snapshot(List<RecentChat> chats, {bool signedIn = true}) =>
    SurfaceSnapshot(updatedAt: noon, signedIn: signedIn, recentChats: chats);

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

  ChatSpotlightIndexer newIndexer() => ChatSpotlightIndexer(
    index: index,
    settings: settings,
    store: store,
    appLock: lock,
    signedOut: signedOut.stream,
    prefs: prefs,
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

    test('leaves out a chat without a title', () async {
      await record(snapshot([chat('a', ''), chat('b', 'Groceries')]));

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

    test('is retried with the next change in the same run', () async {
      await settings.setEnabled(true);
      await indexer.start();
      await record(snapshot([chat('a', 'Trip plan')]));
      index.succeeds = false;
      await record(snapshot([], signedIn: false));
      index.succeeds = true;

      signedOut.add(null);
      await settle();

      expect(index.items, isEmpty);
      expect(index.calls.where((c) => c == 'deleteAll'), hasLength(2));
    });

    test('a failed index call is retried with the same chats', () async {
      await settings.setEnabled(true);
      await indexer.start();
      index.succeeds = false;
      await record(snapshot([chat('a', 'Trip plan')]));
      index.succeeds = true;

      await settings.setEnabled(false);
      await settings.setEnabled(true);
      await settle();

      expect(index.items['chat']!.single.title, 'Trip plan');
    });
  });
}
