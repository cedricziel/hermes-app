import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

import '../support/fake_surface_storage.dart';
import '../support/recorded_events.dart';

DateTime at(int minute) => DateTime.utc(2026, 10, 10, 12, minute);

SurfaceSnapshot snapshot(
  int minute, {
  int revision = 0,
  bool signedIn = true,
  List<PendingRequest> pending = const [],
  List<RecentChat> chats = const [],
}) => SurfaceSnapshot(
  updatedAt: at(minute),
  revision: revision,
  signedIn: signedIn,
  profile: 'default',
  pending: pending,
  recentChats: chats,
);

PendingRequest request(String id, {String title = 'Merger plans'}) =>
    PendingRequest(
      profile: 'work',
      threadId: 'chat-$id',
      threadTitle: title,
      kind: PendingKind.approval,
      requestId: id,
      createdAt: at(0),
    );

void main() {
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late RecordedEvents events;
  var lockOn = false;

  setUp(() {
    lockOn = false;
    storage = FakeSurfaceStorage();
    events = RecordedEvents();
    store = SurfaceSnapshotStore(storage: storage, events: events.call);
    addTearDown(store.dispose);
  });

  SurfaceSnapshot stored() => SurfaceSnapshot.fromJson(storage.saved.last)!;

  Future<SurfaceSnapshot?> background(
    SurfaceSnapshot built, {
    bool Function()? cancelled,
  }) => store.writeIfCurrent(
    built,
    appLockOn: () async => lockOn,
    cancelled: cancelled,
  );

  group('every write is the next revision', () {
    test('counts from the stored one', () async {
      await store.write(snapshot(0));
      await store.write(snapshot(1, pending: [request('r1')]));

      expect(stored().revision, 2);
    });

    test('a snapshot stored by an earlier build has revision 0', () {
      const json =
          '{"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true}';

      expect(SurfaceSnapshot.fromJson(json)!.revision, 0);
    });

    test('goes on from what another writer stored', () async {
      await store.write(snapshot(0));
      // Another isolate's store object writes to the same storage.
      final other = SurfaceSnapshotStore(storage: storage);
      addTearDown(other.dispose);
      await other.write(snapshot(1, pending: [request('r1')]));

      await store.write(snapshot(2, pending: [request('r1'), request('r2')]));

      expect(stored().revision, 3);
    });
  });

  group('a background write', () {
    test('saves when the stored revision is the one it built from', () async {
      await store.write(snapshot(0));
      final base = stored();

      final written = await background(
        snapshot(5, revision: base.revision, pending: [request('r1')]),
      );

      expect(written!.revision, base.revision + 1);
      expect(stored().pending.single.requestId, 'r1');
    });

    test('is dropped, whole, when someone wrote since', () async {
      await store.write(snapshot(0));
      final base = stored();
      await store.write(snapshot(1, chats: []));

      final written = await background(
        snapshot(5, revision: base.revision, pending: [request('r1')]),
      );

      expect(written, isNull);
      expect(stored().pending, isEmpty);
      expect(storage.saved, hasLength(2));
      expect(events.named('surface.snapshot.write_skipped'), [
        {'reason': 'revision_changed'},
      ]);
    });

    test('never replaces a signed-out snapshot', () async {
      await store.write(SurfaceSnapshot.signedOut(at(0)));
      final base = stored();

      final written = await background(
        snapshot(5, revision: base.revision, pending: [request('r1')]),
      );

      expect(written, isNull);
      expect(stored().signedIn, isFalse);
      expect(events.named('surface.snapshot.write_skipped'), [
        {'reason': 'signed_out'},
      ]);
    });

    test('reads App Lock when it saves, not when it built', () async {
      await store.write(snapshot(0));
      final base = stored();
      final built = snapshot(
        5,
        revision: base.revision,
        pending: [request('r1')],
        chats: [
          RecentChat(
            profile: 'work',
            id: 'w1',
            title: 'Merger plans',
            updatedAt: at(4),
          ),
        ],
      );
      // On by the time it saves.
      lockOn = true;

      await background(built);

      expect(stored().pending.single.threadTitle, isEmpty);
      expect(stored().recentChats.single.title, isEmpty);
      expect(stored().pending.single.requestId, 'r1');
    });

    test('asks App Lock before it reads what is stored', () async {
      await store.write(snapshot(0));
      final base = stored();
      final order = <String>[];
      final spied = SurfaceSnapshotStore(storage: _Spy(storage, order));
      addTearDown(spied.dispose);

      await spied.writeIfCurrent(
        snapshot(5, revision: base.revision),
        appLockOn: () async {
          order.add('lock');
          return false;
        },
      );

      expect(order, ['lock', 'load', 'save']);
    });

    test('is dropped when its run is over', () async {
      await store.write(snapshot(0));
      final base = stored();
      var over = false;
      final gate = Completer<bool>();

      final pending = store.writeIfCurrent(
        snapshot(5, revision: base.revision, pending: [request('r1')]),
        appLockOn: () => gate.future,
        cancelled: () => over,
      );
      over = true;
      gate.complete(false);

      expect(await pending, isNull);
      expect(storage.saved, hasLength(1));
      expect(events.named('surface.snapshot.write_skipped'), [
        {'reason': 'cancelled'},
      ]);
    });

    test('starts from nothing stored', () async {
      final written = await background(snapshot(5));

      expect(written!.revision, 1);
    });
  });
}

/// Records the order of the storage calls.
class _Spy implements SurfaceStorage {
  _Spy(this._inner, this._order);

  final FakeSurfaceStorage _inner;
  final List<String> _order;

  @override
  Future<String?> load() {
    _order.add('load');
    return _inner.load();
  }

  @override
  Future<void> save(String json) {
    _order.add('save');
    return _inner.save(json);
  }

  @override
  Future<void> reload(String kind) => _inner.reload(kind);
}
