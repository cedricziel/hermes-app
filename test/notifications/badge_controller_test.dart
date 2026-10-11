import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/notifications/badge_controller.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_surface_storage.dart';

class _FakeBadge implements BadgeService {
  final counts = <int>[];
  Error? failure;

  @override
  Future<void> update(int count) async {
    if (failure case final error?) throw error;
    counts.add(count);
  }
}

PendingRequest _request(String id, {String profile = 'default'}) =>
    PendingRequest(
      profile: profile,
      threadId: 't-$id',
      threadTitle: 'Chat $id',
      kind: PendingKind.approval,
      requestId: id,
      createdAt: DateTime.utc(2026),
    );

SurfaceSnapshot _snapshot(List<PendingRequest> pending, {int minute = 0}) =>
    SurfaceSnapshot(
      updatedAt: DateTime.utc(2026, 1, 1, 12, minute),
      pending: pending,
    );

void main() {
  late _FakeBadge badge;
  late SurfaceSnapshotStore store;
  late NotificationSettings settings;
  late StreamController<void> signedOut;
  late BreadcrumbTrail trail;
  late BadgeController controller;
  var minute = 0;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    minute = 0;
    badge = _FakeBadge();
    store = SurfaceSnapshotStore(storage: FakeSurfaceStorage());
    settings = NotificationSettings();
    await settings.load();
    signedOut = StreamController<void>.broadcast(sync: true);
    trail = BreadcrumbTrail();
    controller = BadgeController(
      badge: badge,
      store: store,
      settings: settings,
      signedOut: signedOut.stream,
      breadcrumbs: Breadcrumbs.of(trail),
    );
  });

  tearDown(() async {
    await controller.dispose();
    await signedOut.close();
    await store.dispose();
    settings.dispose();
  });

  Future<void> write(List<PendingRequest> pending) async {
    await store.write(_snapshot(pending, minute: ++minute));
    await pumpEventQueue();
  }

  List<String> crumbs() => [
    for (final c in trail.recent)
      if (c.name == 'notification.badge') '${c.attributes['count']}',
  ];

  test('shows how many requests wait, across profiles', () async {
    await controller.start();

    await write([_request('a'), _request('b', profile: 'work')]);

    expect(badge.counts, [2]);
  });

  test('follows the list as requests are answered', () async {
    await controller.start();
    await write([_request('a'), _request('b')]);

    await write([_request('b')]);
    await write([]);

    expect(badge.counts, [2, 1, 0]);
  });

  test('does not touch the badge when the number is unchanged', () async {
    await controller.start();
    await write([_request('a')]);

    await write([_request('b')]);
    await write([_request('b'), _request('c')]);

    expect(badge.counts, [1, 2]);
  });

  test('starts from the stored snapshot', () async {
    await store.write(_snapshot([_request('a'), _request('b')]));

    await controller.start();
    await pumpEventQueue();

    expect(badge.counts, [2]);
  });

  test('clears a leftover badge when the first snapshot has none', () async {
    await controller.start();

    await write([]);

    expect(badge.counts, [0]);
  });

  test('removes the badge after a signed-out snapshot', () async {
    await controller.start();
    await write([_request('a')]);

    await store.clear();
    await pumpEventQueue();

    expect(badge.counts, [1, 0]);
  });

  test('removes the badge on sign-out before any snapshot says so', () async {
    await controller.start();
    await write([_request('a')]);

    signedOut.add(null);
    await pumpEventQueue();

    expect(badge.counts, [1, 0]);
  });

  test('removes the badge while notifications are off', () async {
    await controller.start();
    await write([_request('a'), _request('b')]);

    await settings.setEnabled(false);
    await pumpEventQueue();
    await write([_request('a'), _request('b'), _request('c')]);

    expect(badge.counts, [2, 0]);
  });

  test('shows the badge again when notifications come back', () async {
    await controller.start();
    await write([_request('a')]);
    await settings.setEnabled(false);
    await pumpEventQueue();

    await settings.setEnabled(true);
    await pumpEventQueue();

    expect(badge.counts, [1, 0, 1]);
  });

  test('waits for the saved setting before it shows anything', () async {
    final unloaded = NotificationSettings();
    final waiting = BadgeController(
      badge: badge,
      store: store,
      settings: unloaded,
      breadcrumbs: Breadcrumbs.of(trail),
    );
    await waiting.start();
    await store.write(_snapshot([_request('a')]));
    await pumpEventQueue();
    expect(badge.counts, isEmpty);

    await unloaded.load();
    await pumpEventQueue();

    expect(badge.counts, [1]);
    await waiting.dispose();
    unloaded.dispose();
  });

  test(
    'swallows a plugin that fails and tries again with the next change',
    () async {
      await controller.start();
      badge.failure = StateError('no launcher');
      await write([_request('a')]);

      badge.failure = null;
      await write([_request('b')]);
      await write([_request('b'), _request('c')]);

      expect(badge.counts, [1, 2]);
    },
  );

  group('breadcrumb', () {
    test('notes the bucket only when it changes', () async {
      await controller.start();

      await write([_request('a')]);
      await write([_request('b')]);
      await write([_request('b'), _request('c')]);
      await write([_request('b'), _request('c'), _request('d')]);
      await write(List.generate(6, (i) => _request('$i')));
      await write(List.generate(9, (i) => _request('$i')));
      await write([]);

      expect(crumbs(), ['1', '2-5', '6+', '0']);
    });

    test('holds no ids, titles or profiles', () async {
      await controller.start();
      await write([_request('secret-id', profile: 'private')]);

      final text = [for (final c in trail.recent) '${c.name} ${c.attributes}']
          .join();
      expect(text, isNot(contains('secret-id')));
      expect(text, isNot(contains('private')));
      expect(text, isNot(contains('Chat')));
    });

    test('says nothing for a first snapshot without requests', () async {
      await controller.start();
      await write([]);

      expect(crumbs(), isEmpty);
    });
  });

  group('forPlatform', () {
    BadgeController? build(TargetPlatform platform) =>
        BadgeController.forPlatform(
          platform: platform,
          store: store,
          settings: settings,
          signedOut: signedOut.stream,
          badge: badge,
        );

    test('is there on iOS, macOS and Android', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
      ]) {
        expect(build(platform), isNotNull, reason: '$platform');
      }
    });

    test('is not there on desktop systems without a badge', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(build(platform), isNull, reason: '$platform');
      }
    });

    test('is not there without a snapshot store', () {
      expect(
        BadgeController.forPlatform(
          platform: TargetPlatform.iOS,
          store: null,
          settings: settings,
          badge: badge,
        ),
        isNull,
      );
    });
  });
}
