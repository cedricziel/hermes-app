import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/quick_actions/quick_actions_controller.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../support/fake_quick_actions_port.dart';
import '../support/fake_surface_storage.dart';
import '../support/recorded_events.dart';

SurfaceSnapshot snapshot(List<RecentChat> chats, {int minute = 0}) =>
    SurfaceSnapshot(
      updatedAt: DateTime.utc(2026, 1, 1, 13, minute),
      recentChats: chats,
    );

RecentChat chat(String id, String title, int minute) => RecentChat(
  profile: 'default',
  id: id,
  title: title,
  updatedAt: DateTime.utc(2026, 1, 1, 12, minute),
);

void main() {
  late FakeQuickActionsPort port;
  late SurfaceSnapshotStore store;
  late StreamController<Uri> links;
  late Completer<void> firstFrame;
  late DeepLinks deepLinks;
  late RecordedEvents events;
  late BreadcrumbTrail trail;
  late QuickActionsController controller;
  late DateTime clock;

  setUp(() {
    port = FakeQuickActionsPort();
    store = SurfaceSnapshotStore(storage: FakeSurfaceStorage());
    links = StreamController<Uri>.broadcast(sync: true);
    firstFrame = Completer<void>();
    deepLinks = DeepLinks(links: links.stream, firstFrame: firstFrame.future);
    events = RecordedEvents();
    trail = BreadcrumbTrail();
    clock = DateTime.utc(2026);
    controller = QuickActionsController(
      now: () => clock,
      port: port,
      store: store,
      open: deepLinks.open,
      events: events.call,
      breadcrumbs: Breadcrumbs.of(trail),
    );
  });

  tearDown(() async {
    await controller.dispose();
    deepLinks.dispose();
    await links.close();
    await store.dispose();
  });

  Future<void> write(SurfaceSnapshot snapshot) async {
    await store.write(snapshot);
    await Future<void>.delayed(Duration.zero);
  }

  List<String> titles() => [for (final i in port.items) i.localizedTitle];

  group('menu', () {
    test('registers the handler before it sets any item', () async {
      await store.write(snapshot([]));
      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(port.calls, ['initialize', 'setItems']);
    });

    test('follows each snapshot write', () async {
      await controller.start();

      await write(snapshot([chat('1', 'Trip plan', 1)]));
      expect(titles(), ['New Chat', 'Dictate', 'Trip plan']);

      await write(snapshot([chat('1', 'Trip plan', 1), chat('2', 'Taxes', 2)]));
      expect(titles(), ['New Chat', 'Dictate', 'Taxes', 'Trip plan']);
    });

    test('does not set the same items again', () async {
      await controller.start();
      await write(snapshot([chat('1', 'Trip plan', 1)]));
      await write(snapshot([chat('1', 'Trip plan', 1)], minute: 5));

      expect(port.sets, hasLength(1));
    });

    test('is emptied on sign-out', () async {
      await controller.start();
      await write(snapshot([chat('1', 'Trip plan', 1)]));

      await store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(port.items, isEmpty);
    });

    test('loses the recents under App Lock and regains them', () async {
      await controller.start();
      final open = snapshot([chat('1', 'Trip plan', 1)]);

      await write(open);
      await write(open.redacted());
      expect(titles(), ['New Chat', 'Dictate']);

      await write(snapshot([chat('1', 'Trip plan', 1)], minute: 9));
      expect(titles(), ['New Chat', 'Dictate', 'Trip plan']);
    });

    test('swallows a plugin error, logs it and tries again later', () async {
      await controller.start();
      port.failure = StateError('boom');
      await write(snapshot([chat('1', 'Trip plan', 1)]));

      expect(events.named('quick_actions.update_failed'), [
        {'error.type': 'StateError'},
      ]);

      port.failure = null;
      await write(snapshot([chat('1', 'Trip plan', 1), chat('2', 'Taxes', 2)]));
      expect(titles(), ['New Chat', 'Dictate', 'Taxes', 'Trip plan']);
    });
  });

  test('a write that arrives while the stored one is read wins', () async {
    final gated = GatedStorage();
    final racing = SurfaceSnapshotStore(storage: gated);
    final other = QuickActionsController(
      port: port,
      store: racing,
      open: deepLinks.open,
    );
    addTearDown(() async {
      await other.dispose();
      await racing.dispose();
    });

    final started = other.start();
    await Future<void>.delayed(Duration.zero);
    await racing.write(snapshot([chat('2', 'Fresh', 2)]));
    gated.release(snapshot([chat('1', 'Stale', 1)]).encode());
    await started;
    await Future<void>.delayed(Duration.zero);

    expect(titles(), ['New Chat', 'Dictate', 'Fresh']);
    expect(port.sets, hasLength(1));
  });

  group('picking', () {
    setUp(() async {
      await controller.start();
      await write(snapshot([chat('1', 'Trip plan', 1)]));
    });

    String typeOf(String title) =>
        port.items.firstWhere((i) => i.localizedTitle == title).type;

    test('New Chat opens a new chat', () {
      port.pick(typeOf('New Chat'));

      expect(deepLinks.pending?.target, const NewChat());
    });

    test('Dictate opens a new chat with the microphone', () {
      port.pick(typeOf('Dictate'));

      expect(deepLinks.pending?.target, const NewChat(dictate: true));
    });

    test('a recent chat opens in its profile', () {
      port.pick(typeOf('Trip plan'));

      expect(
        deepLinks.pending?.target,
        const OpenChat(profile: 'default', threadId: '1'),
      );
    });

    test('a pick before the first frame is cold', () {
      port.pick(typeOf('New Chat'));

      expect(deepLinks.pending?.cold, isTrue);
    });

    test('a pick after the first frame is warm', () async {
      firstFrame.complete();
      await Future<void>.delayed(Duration.zero);
      port.pick(typeOf('New Chat'));

      expect(deepLinks.pending?.cold, isFalse);
    });

    test('a launch item delivered twice runs once', () {
      port.pick(typeOf('New Chat'));
      deepLinks.take();
      port.pick(typeOf('New Chat'));

      expect(deepLinks.pending, isNull);
      expect(events.named('quick_action.used'), hasLength(1));
    });

    test('the same item picked again later runs again', () {
      port.pick(typeOf('New Chat'));
      deepLinks.take();
      clock = clock.add(const Duration(seconds: 3));
      port.pick(typeOf('New Chat'));

      expect(deepLinks.pending?.target, const NewChat());
    });

    test('an unknown type is ignored', () {
      port.pick('hermes://memory');
      port.pick('other');

      expect(deepLinks.pending, isNull);
      expect(events.named('quick_action.used'), isEmpty);
    });

    test('logs the kind and leaves out titles, profiles and ids', () {
      port.pick(typeOf('Trip plan'));
      port.pick(typeOf('Dictate'));

      expect(events.named('quick_action.used'), [
        {'kind': 'recent'},
        {'kind': 'dictate'},
      ]);
      final crumbs = [
        for (final c in trail.recent) '${c.name} ${c.attributes}',
      ];
      expect(crumbs, [
        'quick_action.opened {kind: recent, cold_start: true}',
        'quick_action.opened {kind: dictate, cold_start: false}',
      ]);
    });
  });

  group('forPlatform', () {
    QuickActionsController? on(TargetPlatform platform) =>
        QuickActionsController.forPlatform(
          store: store,
          deepLinks: deepLinks,
          platform: platform,
          port: port,
        );

    test('exists on iOS and Android', () {
      expect(on(TargetPlatform.iOS), isNotNull);
      expect(on(TargetPlatform.android), isNotNull);
    });

    test('is not created on macOS, Windows or Linux', () {
      expect(on(TargetPlatform.macOS), isNull);
      expect(on(TargetPlatform.windows), isNull);
      expect(on(TargetPlatform.linux), isNull);
    });

    test('is not created without a snapshot store', () {
      expect(
        QuickActionsController.forPlatform(
          store: null,
          deepLinks: deepLinks,
          platform: TargetPlatform.iOS,
        ),
        isNull,
      );
    });
  });
}

/// Holds back the first load, which is the controller's own read.
class GatedStorage implements SurfaceStorage {
  final _loaded = Completer<String?>();
  var _loads = 0;

  void release(String json) => _loaded.complete(json);

  @override
  Future<String?> load() {
    if (_loads++ == 0) return _loaded.future;
    return Future.value();
  }

  @override
  Future<void> save(String json) async {}

  @override
  Future<void> reload(String kind) async {}
}
