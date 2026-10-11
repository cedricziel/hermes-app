import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

import '../support/fake_surface_storage.dart';
import '../support/recorded_events.dart';

SurfaceSnapshot snapshot({
  int hour = 12,
  int minute = 0,
  String profile = 'default',
}) => SurfaceSnapshot(
  updatedAt: DateTime.utc(2026, 10, 10, hour, minute),
  profile: profile,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('on the home_widget channel', () {
    late List<MethodCall> calls;
    late Object? Function(MethodCall call) answer;

    setUp(() {
      calls = [];
      answer = (_) => true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (
            call,
          ) async {
            calls.add(call);
            return answer(call);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('home_widget'), null),
      );
    });

    test('saves the JSON in the App Group', () async {
      final store = SurfaceSnapshotStore(widgetKinds: const ['Recent']);

      await store.write(snapshot());

      final save = calls.firstWhere((c) => c.method == 'saveWidgetData');
      expect(save.arguments, {
        'id': 'hermes.surface.v1',
        'data': snapshot().encode(),
        'appGroupId': 'group.com.cedricziel.hermesApp',
      });
    });

    test('reloads every widget kind that reads it', () async {
      final store = SurfaceSnapshotStore(
        widgetKinds: const ['Recent', 'Needs'],
      );

      await store.write(snapshot());

      expect(
        calls
            .where((c) => c.method == 'updateWidget')
            .map((c) => (c.arguments as Map)['ios']),
        ['Recent', 'Needs'],
      );
    });

    test('reloads every widget kind by default', () async {
      await SurfaceSnapshotStore().write(snapshot());

      expect(
        calls
            .where((c) => c.method == 'updateWidget')
            .map((c) => (c.arguments as Map)['ios']),
        [
          'HermesRecentChats',
          'HermesNeedsYou',
          'HermesBoard',
          'HermesNewChat',
          'HermesDictate',
          'HermesQuickLaunch',
        ],
      );
    });

    test('reads what was saved', () async {
      answer = (call) =>
          call.method == 'getWidgetData' ? snapshot().encode() : null;

      expect(await SurfaceSnapshotStore().read(), snapshot());
    });
  });

  group('with a storage', () {
    late FakeSurfaceStorage storage;
    late RecordedEvents events;
    late SurfaceSnapshotStore store;

    setUp(() {
      storage = FakeSurfaceStorage();
      events = RecordedEvents();
      store = SurfaceSnapshotStore(
        storage: storage,
        events: events.call,
        widgetKinds: const ['Recent'],
      );
      addTearDown(store.dispose);
    });

    test('stores the same content again with the newer time, '
        'without reloading the widgets', () async {
      final seen = <SurfaceSnapshot>[];
      store.writes.listen(seen.add);
      await store.write(snapshot());

      await store.write(snapshot(minute: 30));
      await pumpEventQueue();

      expect(storage.saved, hasLength(2));
      expect(
        SurfaceSnapshot.fromJson(storage.saved.last)!.updatedAt,
        DateTime.utc(2026, 10, 10, 12, 30),
      );
      expect(storage.reloaded, ['Recent']);
      expect(seen, hasLength(1));
    });

    test(
      'does not store the same content with an older or equal time',
      () async {
        await store.write(snapshot(hour: 13));

        await store.write(snapshot());
        await store.write(snapshot(hour: 13));

        expect(storage.saved, hasLength(1));
      },
    );

    test('a refresh reloads the widgets when it pushes back the stale '
        'entry they still hold', () async {
      await store.write(snapshot()); // T0: the widgets reload.

      await store.write(snapshot(hour: 17)); // T0 + 5 h, app opened.

      expect(storage.reloaded, [
        'Recent',
        'Recent',
      ], reason: 'the widgets would otherwise call it stale at T0 + 6 h');
    });

    test('a refresh within the hour of the last reload reloads nothing, '
        'and the hour counts from that reload', () async {
      await store.write(snapshot());

      await store.write(snapshot(minute: 59));
      expect(storage.reloaded, ['Recent']);

      await store.write(snapshot(hour: 13));
      expect(storage.reloaded, ['Recent', 'Recent']);

      await store.write(snapshot(hour: 13, minute: 59));
      expect(storage.reloaded, ['Recent', 'Recent']);
    });

    group('a widget that reads only whether anyone is signed in', () {
      late SurfaceSnapshotStore both;

      setUp(() {
        both = SurfaceSnapshotStore(
          storage: storage,
          widgetKinds: const ['Recent', 'HermesNewChat'],
        );
        addTearDown(both.dispose);
      });

      test('reloads with the first sign-in, and with a sign-out', () async {
        await both.write(snapshot());
        expect(storage.reloaded, ['Recent', 'HermesNewChat']);

        storage.reloaded.clear();
        await both.write(
          SurfaceSnapshot.signedOut(DateTime.utc(2026, 10, 10, 13)),
        );
        expect(storage.reloaded, ['Recent', 'HermesNewChat']);
      });

      test('is not reloaded by a change that leaves it signed in', () async {
        await both.write(snapshot());
        storage.reloaded.clear();

        await both.write(snapshot(profile: 'work'));
        await both.write(snapshot(hour: 17));

        expect(storage.reloaded, ['Recent', 'Recent']);
      });

      test('is reloaded again when the first save failed', () async {
        storage.failure = StateError('no group');
        await both.write(snapshot());
        storage.failure = null;

        await both.write(snapshot(profile: 'work'));

        expect(storage.reloaded, ['Recent', 'HermesNewChat']);
      });
    });

    test('a failed refresh of the same content keeps what is stored', () async {
      await store.write(snapshot());
      storage.failure = StateError('no group');

      await store.write(snapshot(minute: 10));
      storage.failure = null;
      await store.write(snapshot(minute: 20));

      expect(storage.saved, hasLength(2));
      expect(storage.reloaded, ['Recent']);
      expect(events.named('surface.snapshot.write_failed'), hasLength(1));
    });

    test('writes a change', () async {
      await store.write(snapshot());
      await store.write(snapshot(profile: 'work'));

      expect(storage.saved, hasLength(2));
    });

    test('tells listeners about each write', () async {
      final seen = <SurfaceSnapshot>[];
      store.writes.listen(seen.add);

      await store.write(snapshot());
      await store.write(snapshot(hour: 13));
      await store.write(snapshot(profile: 'work'));
      await pumpEventQueue();

      expect(seen.map((s) => s.profile), ['default', 'work']);
    });

    test('a failing storage is logged and still reaches listeners', () async {
      storage.failure = StateError('no group');
      final seen = <SurfaceSnapshot>[];
      store.writes.listen(seen.add);

      await store.write(snapshot());
      await pumpEventQueue();

      expect(seen, hasLength(1));
      expect(events.named('surface.snapshot.write_failed'), [
        {'error.type': 'StateError'},
      ]);
    });

    test(
      'a failing reload is logged by kind, the others still reload',
      () async {
        final several = SurfaceSnapshotStore(
          storage: storage,
          events: events.call,
          widgetKinds: const ['Recent', 'Needs'],
        );
        addTearDown(several.dispose);
        storage.failingKinds.add('Recent');
        final seen = <SurfaceSnapshot>[];
        several.writes.listen(seen.add);

        await several.write(snapshot());
        await pumpEventQueue();

        expect(storage.reloaded, ['Needs']);
        expect(events.named('widgets.reload_failed'), [
          {'widget.kind': 'Recent', 'error.type': 'StateError'},
        ]);
        expect(events.named('surface.snapshot.write_failed'), isEmpty);
        expect(seen, hasLength(1));
      },
    );

    test('a failed write is tried again', () async {
      storage.failure = StateError('no group');
      await store.write(snapshot());
      storage.failure = null;

      await store.write(snapshot());

      expect(storage.saved, hasLength(1));
    });

    test('a failing widget reload is not a failed write', () async {
      storage.reloadFailure = StateError('no widgets');

      await store.write(snapshot());
      await store.write(snapshot(minute: 30));

      expect(storage.saved, hasLength(2));
      expect(events.named('surface.snapshot.write_failed'), isEmpty);
      expect(events.named('widgets.reload_failed'), [
        {'widget.kind': 'Recent', 'error.type': 'StateError'},
      ]);
    });

    test('content already stored is only refreshed after a start', () async {
      await store.write(snapshot());
      final restarted = SurfaceSnapshotStore(
        storage: storage,
        widgetKinds: const ['Recent'],
      );
      addTearDown(restarted.dispose);

      await restarted.write(snapshot(minute: 5));
      await restarted.write(snapshot(profile: 'work'));

      expect(storage.saved, hasLength(3));
      expect(
        storage.reloads,
        3,
        reason: 'a new start does not know when the widgets last reloaded',
      );
    });

    test('writes land in the order they were asked for', () async {
      await store.write(snapshot());
      storage.saved.clear();
      final gate = storage.saveGate = Completer<void>();
      final titled = SurfaceSnapshot(
        updatedAt: DateTime.utc(2026, 10, 10, 12),
        recentChats: [
          RecentChat(
            profile: 'default',
            id: 'c1',
            title: 'Trip plan',
            updatedAt: DateTime.utc(2026, 10, 10, 11),
          ),
        ],
      );

      final first = store.write(titled);
      final second = store.write(titled.redacted());
      gate.complete();
      await Future.wait([first, second]);

      expect(
        storage.saved
            .map(SurfaceSnapshot.fromJson)
            .map((s) => s!.recentChats.single.title),
        ['Trip plan', ''],
      );
    });

    test('a write that throws does not stop the ones after it', () async {
      await store.write(snapshot());

      await expectLater(
        store.write(_Unreadable(DateTime.utc(2026, 10, 10, 12))),
        throwsStateError,
      );
      await store.write(snapshot(profile: 'work'));

      expect(storage.saved, hasLength(2));
    });

    test('clear writes the signed-out form', () async {
      await store.write(snapshot());

      await store.clear(now: DateTime.utc(2026, 10, 11));

      final written = SurfaceSnapshot.fromJson(storage.saved.last)!;
      expect(written.signedIn, isFalse);
      expect(written.recentChats, isEmpty);
      expect(storage.reloaded, ['Recent', 'Recent']);
    });

    test('reads nothing back when it holds nothing', () async {
      expect(await store.read(), isNull);
    });
  });
}

/// A snapshot that cannot be compared, which makes a write throw.
class _Unreadable extends SurfaceSnapshot {
  _Unreadable(DateTime updatedAt) : super(updatedAt: updatedAt);

  @override
  Map<String, Object?> toJson() => throw StateError('unreadable');
}
