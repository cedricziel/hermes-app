import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

import '../support/fake_surface_storage.dart';
import '../support/recorded_events.dart';

SurfaceSnapshot snapshot({int hour = 12, String profile = 'default'}) =>
    SurfaceSnapshot(
      updatedAt: DateTime.utc(2026, 10, 10, hour),
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

    test('reloads the three Home Screen widgets by default', () async {
      await SurfaceSnapshotStore().write(snapshot());

      expect(
        calls
            .where((c) => c.method == 'updateWidget')
            .map((c) => (c.arguments as Map)['ios']),
        ['HermesRecentChats', 'HermesNeedsYou', 'HermesBoard'],
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

    test('does not write the same content again', () async {
      await store.write(snapshot());
      await store.write(snapshot(hour: 13));

      expect(storage.saved, hasLength(1));
      expect(storage.reloaded, ['Recent']);
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
      await store.write(snapshot(hour: 13));

      expect(storage.saved, hasLength(1));
      expect(events.named('surface.snapshot.write_failed'), isEmpty);
      expect(events.named('widgets.reload_failed'), [
        {'widget.kind': 'Recent', 'error.type': 'StateError'},
      ]);
    });

    test('content already stored is not written again after a start', () async {
      await store.write(snapshot());
      final restarted = SurfaceSnapshotStore(
        storage: storage,
        widgetKinds: const ['Recent'],
      );
      addTearDown(restarted.dispose);

      await restarted.write(snapshot(hour: 13));
      await restarted.write(snapshot(profile: 'work'));

      expect(storage.saved, hasLength(2));
      expect(storage.reloads, 2);
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
      expect(storage.reloaded, ['Recent', 'Needs', 'Recent', 'Needs']);
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
