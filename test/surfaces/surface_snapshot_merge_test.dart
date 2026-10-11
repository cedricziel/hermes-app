import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

import '../support/fake_surface_storage.dart';

DateTime at(int minute) => DateTime.utc(2026, 10, 10, 12, minute);

PendingRequest request(String profile, String id, {String title = 'Chat'}) =>
    PendingRequest(
      profile: profile,
      threadId: 'chat-$id',
      threadTitle: title,
      kind: PendingKind.approval,
      requestId: id,
      createdAt: at(0),
    );

RecentChat chat(String profile, String id, {int minute = 0}) => RecentChat(
  profile: profile,
  id: id,
  title: 'Title $id',
  updatedAt: at(minute),
);

SnapshotBuild built(
  SurfaceSnapshot snapshot, {
  SurfaceSnapshot? base,
  SnapshotFreshness fresh = const SnapshotFreshness(),
  bool redacted = false,
}) => (
  snapshot: snapshot,
  sourcesFailed: 0,
  fresh: fresh,
  base: base,
  redacted: redacted,
);

void main() {
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;

  setUp(() {
    storage = FakeSurfaceStorage();
    store = SurfaceSnapshotStore(storage: storage);
    addTearDown(store.dispose);
  });

  SurfaceSnapshot stored() => SurfaceSnapshot.fromJson(storage.saved.last)!;

  /// What the app in front built from a base it read before a background run
  /// wrote its cross-profile list.
  Future<SurfaceSnapshot> foregroundWrite({
    required SurfaceSnapshot base,
    required SurfaceSnapshot mine,
  }) => store.writeBuilt(
    built(
      mine,
      base: base,
      fresh: const SnapshotFreshness(
        chatProfiles: {'default'},
        pendingProfiles: {'default'},
        openProfile: true,
      ),
    ),
  );

  test('the app in front keeps the open requests a background run found in '
      'other profiles', () async {
    final base = SurfaceSnapshot(updatedAt: at(0), profile: 'default');
    await store.write(
      SurfaceSnapshot(
        updatedAt: at(5),
        profile: 'default',
        pending: [request('work', 'w1')],
      ),
    );

    final written = await foregroundWrite(
      base: base,
      mine: SurfaceSnapshot(
        updatedAt: at(6),
        profile: 'default',
        recentChats: [chat('default', 'd1')],
        pending: [request('default', 'd-req')],
      ),
    );

    expect(written.pending.map((p) => p.requestId), ['d-req', 'w1']);
    expect(stored().pending.map((p) => p.requestId), ['d-req', 'w1']);
    expect(stored().recentChats.map((c) => c.id), ['d1']);
  });

  test(
    'a background run keeps what the app in front wrote meanwhile',
    () async {
      final base = SurfaceSnapshot(updatedAt: at(0), profile: 'default');
      await store.write(
        SurfaceSnapshot(
          updatedAt: at(5),
          profile: 'work',
          recentChats: [chat('work', 'w1', minute: 5)],
          pending: [request('work', 'w-open')],
        ),
      );

      final written = await store.writeBuilt(
        built(
          SurfaceSnapshot(
            updatedAt: at(6),
            profile: 'default',
            recentChats: [chat('default', 'd1', minute: 6)],
            // The run read every profile's chats and requests, and its list is
            // the newer word on the requests.
            pending: [request('default', 'd-req')],
            kanban: const KanbanSummary(blocked: 1, review: 0),
          ),
          base: base,
          fresh: const SnapshotFreshness(
            chatProfiles: {'default'},
            allPending: true,
            profileList: true,
            kanban: true,
          ),
        ),
      );

      expect(written.pending.map((p) => p.requestId), ['d-req']);
      // Work's chats were not read by the run, so the stored ones stay; the
      // open profile is the app's own.
      expect(written.recentChats.map((c) => c.id), containsAll(['w1', 'd1']));
      expect(written.profile, 'work');
      expect(written.kanban?.blocked, 1);
    },
  );

  test('a section it did not refresh comes from the stored snapshot', () async {
    final base = SurfaceSnapshot(updatedAt: at(0));
    await store.write(
      SurfaceSnapshot(
        updatedAt: at(5),
        kanban: const KanbanSummary(blocked: 4, review: 2),
        schedules: ScheduleSummary(nextJobName: 'Digest'),
        profiles: const ['default', 'work'],
      ),
    );

    final written = await store.writeBuilt(
      built(SurfaceSnapshot(updatedAt: at(6)), base: base),
    );

    expect(written.kanban?.blocked, 4);
    expect(written.schedules?.nextJobName, 'Digest');
    expect(written.profiles, ['default', 'work']);
  });

  test('writes as built when nobody wrote since its base', () async {
    final base = SurfaceSnapshot(
      updatedAt: at(0),
      pending: [request('work', 'old')],
    );
    await store.write(base);

    final written = await store.writeBuilt(
      built(
        SurfaceSnapshot(updatedAt: at(6), pending: const []),
        base: base,
        fresh: const SnapshotFreshness(pendingProfiles: {'default'}),
      ),
    );

    // Its own parts are all it knows: the work request it did not read stays
    // only when the stored snapshot is newer than the base.
    expect(written.pending, isEmpty);
  });

  test('a merge keeps titles out while App Lock is on', () async {
    final base = SurfaceSnapshot(updatedAt: at(0));
    await store.write(
      SurfaceSnapshot(
        updatedAt: at(5),
        recentChats: [chat('work', 'w1')],
        pending: [request('work', 'w1', title: 'Merger plans')],
      ),
    );

    final written = await store.writeBuilt(
      built(
        SurfaceSnapshot(updatedAt: at(6)).redacted(),
        base: base,
        redacted: true,
      ),
    );

    expect(written.recentChats.single.title, isEmpty);
    expect(written.pending.single.threadTitle, isEmpty);
  });

  test('a sign-out written meanwhile is not undone by a build', () async {
    final base = SurfaceSnapshot(
      updatedAt: at(0),
      pending: [request('a', '1')],
    );
    await store.write(SurfaceSnapshot.signedOut(at(5)));

    final written = await store.writeBuilt(
      built(SurfaceSnapshot(updatedAt: at(6)), base: base),
    );

    expect(written.signedIn, isFalse);
    expect(stored().signedIn, isFalse);
  });

  test('a sign-out is written over anything', () async {
    final base = SurfaceSnapshot(updatedAt: at(0));
    await store.write(SurfaceSnapshot(updatedAt: at(5)));

    final written = await store.writeBuilt(
      built(SurfaceSnapshot.signedOut(at(6)), base: base),
    );

    expect(written.signedIn, isFalse);
  });
}
