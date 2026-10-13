import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/invalidation/change_invalidation_controller.dart';
import 'package:hermes_app/src/chat/invalidation/change_signal.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';

import '../../support/fake_hermes_server.dart';

void main() {
  late ChangeInvalidationController controller;
  late ChangeInvalidationScope scope;
  late ValueNotifier<bool> activity;
  setUp(() {
    activity = ValueNotifier(true);
    controller = ChangeInvalidationController(activity: activity);
    scope = ChangeInvalidationScope(
      connection: Object(),
      server: 'server',
      account: 'account',
      profile: 'work',
    );
    controller.bind(scope);
  });
  tearDown(() {
    controller.dispose();
    activity.dispose();
  });

  test(
    'signals decode to resource hints without interpreting payload contents',
    () {
      expect(
        ChangeSignal.decode('sessions.changed', {})?.resource,
        InvalidationResource.sessions,
      );
      expect(
        ChangeSignal.decode('cron.changed', {})?.resource,
        InvalidationResource.schedules,
      );
      expect(
        ChangeSignal.decode('platforms.changed', {
          'platforms': ['untrusted'],
        })?.resource,
        InvalidationResource.platforms,
      );
      expect(
        ChangeSignal.decode('pairing.changed', {})?.resource,
        InvalidationResource.pairing,
      );
      expect(ChangeSignal.decode('cron.changed', null), isNull);
      expect(ChangeSignal.decode('cron.changed', []), isNull);
      expect(ChangeSignal.decode('projects.changed', {}), isNull);
    },
  );

  test(
    'a rejected snapshot stays dirty without an automatic read loop',
    () async {
      final unexpected = Completer<int>();
      var reads = 0;
      final applied = <int>[];
      controller.register<int>(
        InvalidationResource.schedules,
        readSnapshot: (_) => ++reads == 1 ? Future.value(1) : unexpected.future,
        applySnapshot: applied.add,
        snapshotIsCurrent: (_) => false,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.schedules),
        scope: scope,
      );
      await pumpEventQueue();
      expect(reads, 1);
      expect(applied, isEmpty);
      expect(controller.dirty(InvalidationResource.schedules), true);
      expect(controller.loading(InvalidationResource.schedules), false);
      controller.retry(InvalidationResource.schedules);
      await pumpEventQueue();
      expect(reads, 2);
    },
  );
  test(
    'an actual hint during a rejected read gets exactly one follow-up',
    () async {
      final first = Completer<int>(), unexpected = Completer<int>();
      var reads = 0;
      controller.register<int>(
        InvalidationResource.schedules,
        readSnapshot: (_) => ++reads == 1
            ? first.future
            : reads == 2
            ? Future.value(2)
            : unexpected.future,
        applySnapshot: (_) {},
        snapshotIsCurrent: (_) => false,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.schedules),
        scope: scope,
      );
      await pumpEventQueue();
      controller.invalidate(
        const ChangeSignal(InvalidationResource.schedules),
        scope: scope,
      );
      first.complete(1);
      await pumpEventQueue();
      expect(reads, 2);
      expect(controller.dirty(InvalidationResource.schedules), true);
      expect(controller.loading(InvalidationResource.schedules), false);
    },
  );

  test('bursts during a read coalesce into exactly one follow-up', () async {
    final first = Completer<int>(), second = Completer<int>();
    var reads = 0;
    final applied = <int>[];
    controller.register<int>(
      InvalidationResource.schedules,
      readSnapshot: (_) => ++reads == 1 ? first.future : second.future,
      applySnapshot: applied.add,
      active: true,
    );
    controller.invalidate(
      const ChangeSignal(InvalidationResource.schedules),
      scope: scope,
    );
    await pumpEventQueue();
    controller.invalidate(
      const ChangeSignal(InvalidationResource.schedules),
      scope: scope,
    );
    controller.invalidate(
      const ChangeSignal(InvalidationResource.schedules),
      scope: scope,
    );
    controller.invalidate(
      const ChangeSignal(InvalidationResource.schedules),
      scope: scope,
    );
    first.complete(1);
    await pumpEventQueue();
    expect(reads, 2);
    second.complete(2);
    await pumpEventQueue();
    expect(reads, 2);
    expect(applied, [1, 2]);
    expect(controller.dirty(InvalidationResource.schedules), isFalse);
  });

  test(
    'inactive pairing keeps its hint until a known pairing is activated',
    () async {
      var reads = 0;
      controller.register<int>(
        InvalidationResource.pairing,
        readSnapshot: (_) async => ++reads,
        applySnapshot: (_) {},
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.pairing),
        scope: scope,
      );
      await pumpEventQueue();
      expect(reads, 0);
      expect(controller.dirty(InvalidationResource.pairing), isTrue);
      controller.setActive(InvalidationResource.pairing, true);
      await pumpEventQueue();
      expect(reads, 1);
    },
  );

  test(
    'local pending mutations block refresh while retaining dirty state',
    () async {
      var reads = 0;
      controller.register<int>(
        InvalidationResource.platforms,
        readSnapshot: (_) async => ++reads,
        applySnapshot: (_) {},
        active: true,
      );
      controller.setBlocked(InvalidationResource.platforms, true);
      controller.invalidate(
        const ChangeSignal(InvalidationResource.platforms),
        scope: scope,
      );
      await pumpEventQueue();
      expect(reads, 0);
      expect(controller.dirty(InvalidationResource.platforms), isTrue);
      controller.setBlocked(InvalidationResource.platforms, false);
      await pumpEventQueue();
      expect(reads, 1);
    },
  );

  test(
    'suspending activity after scheduling prevents the awaited read',
    () async {
      var reads = 0;
      controller.register<int>(
        InvalidationResource.sessions,
        readSnapshot: (_) async => ++reads,
        applySnapshot: (_) {},
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      activity.value = false;
      await pumpEventQueue();
      expect(reads, 0);
      expect(controller.dirty(InvalidationResource.sessions), isTrue);
      activity.value = true;
      await pumpEventQueue();
      expect(reads, 1);
    },
  );

  test(
    'reentrant suspension during loading notification prevents the read',
    () async {
      var reads = 0;
      controller.register<int>(
        InvalidationResource.sessions,
        readSnapshot: (_) async => ++reads,
        applySnapshot: (_) {},
        active: true,
      );
      controller.addListener(() {
        if (controller.loading(InvalidationResource.sessions)) {
          activity.value = false;
        }
      });
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      await pumpEventQueue();
      expect(reads, 0);
      expect(controller.dirty(InvalidationResource.sessions), isTrue);
    },
  );

  test(
    'a result retired by suspension cannot apply after activity resumes',
    () async {
      final old = Completer<int>(), fresh = Completer<int>();
      var reads = 0;
      final applied = <int>[];
      controller.register<int>(
        InvalidationResource.sessions,
        readSnapshot: (_) => ++reads == 1 ? old.future : fresh.future,
        applySnapshot: applied.add,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      await pumpEventQueue();
      activity.value = false;
      activity.value = true;
      await pumpEventQueue();
      old.complete(1);
      await pumpEventQueue();
      expect(applied, isEmpty);
      fresh.complete(2);
      await pumpEventQueue();
      expect(applied, [2]);
    },
  );

  test(
    'profile replacement rejects old signals and old read results',
    () async {
      final old = Completer<int>();
      final applied = <int>[];
      controller.register<int>(
        InvalidationResource.sessions,
        readSnapshot: (_) => old.future,
        applySnapshot: applied.add,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      await pumpEventQueue();
      controller.bind(
        ChangeInvalidationScope(
          connection: scope.connection,
          server: scope.server,
          account: scope.account,
          profile: 'other',
        ),
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      old.complete(1);
      await pumpEventQueue();
      expect(applied, isEmpty);
      expect(controller.dirty(InvalidationResource.sessions), isFalse);
    },
  );

  test(
    'failed reads retain prior data and dirty state until explicit retry',
    () async {
      var data = 'prior', failed = false, reads = 0;
      controller.register<String>(
        InvalidationResource.platforms,
        readSnapshot: (_) async {
          reads++;
          throw StateError('private failure');
        },
        applySnapshot: (value) => data = value,
        onFailure: (_) => failed = true,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.platforms),
        scope: scope,
      );
      await pumpEventQueue();
      expect(data, 'prior');
      expect(failed, isTrue);
      expect(reads, 1);
      expect(controller.dirty(InvalidationResource.platforms), isTrue);
      expect(controller.failed(InvalidationResource.platforms), isTrue);
      controller.retry(InvalidationResource.platforms);
      await pumpEventQueue();
      expect(reads, 2);
    },
  );

  test('unregistering a destination discards its awaited result', () async {
    final result = Completer<int>();
    var applied = false;
    final unregister = controller.register<int>(
      InvalidationResource.pairing,
      readSnapshot: (_) => result.future,
      applySnapshot: (_) => applied = true,
      active: true,
    );
    controller.invalidate(
      const ChangeSignal(InvalidationResource.pairing),
      scope: scope,
    );
    await pumpEventQueue();
    unregister();
    result.complete(1);
    await pumpEventQueue();
    expect(applied, isFalse);
  });

  test('existing generated-client platform read supplies data instead of the signal payload', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(id: 'telegram', name: 'Telegram', enabled: true),
        ]),
        query: {'profile': 'work'},
      );
    final repository = HermesMessagingRepository(server.client().raw);
    var rows = <HermesMessagingPlatform>[];
    controller.register<List<HermesMessagingPlatform>>(
      InvalidationResource.platforms,
      readSnapshot: (scope) => repository.forProfile(scope.profile).load(),
      applySnapshot: (value) => rows = value,
      active: true,
    );
    controller.invalidate(
      ChangeSignal.decode('platforms.changed', {
        'platforms': [
          {'id': 'invented'},
        ],
      })!,
      scope: scope,
    );
    await pumpEventQueue();
    expect(rows.single.id, 'telegram');
    expect(rows.single.enabled, isTrue);
  });

  test(
    'fixed outcome logging excludes payloads and survives telemetry errors',
    () async {
      controller.dispose();
      final exported = <String>[];
      controller = ChangeInvalidationController(
        activity: activity,
        events: (name, [attributes = const {}]) {
          exported.add('$name $attributes');
          throw StateError('telemetry unavailable');
        },
      );
      controller.bind(scope);
      var applied = false;
      controller.register<int>(
        InvalidationResource.platforms,
        readSnapshot: (_) async => 1,
        applySnapshot: (_) => applied = true,
        active: true,
      );
      controller.invalidate(
        ChangeSignal.decode('platforms.changed', {
          'private': 'secret payload',
        })!,
        scope: scope,
      );
      await pumpEventQueue();
      expect(applied, isTrue);
      expect(exported.join(), isNot(contains('secret payload')));
      expect(exported.join(), isNot(contains('work')));
      expect(exported.join(), isNot(contains('account')));
      expect(exported, isNotEmpty);
    },
  );
  test('a signal received without a mounted destination stays dirty until registration', () async {
    controller.invalidate(
      const ChangeSignal(InvalidationResource.schedules),
      scope: scope,
    );
    await pumpEventQueue();
    expect(controller.dirty(InvalidationResource.schedules), isTrue);
    var reads = 0;
    controller.register<int>(
      InvalidationResource.schedules,
      readSnapshot: (_) async => ++reads,
      applySnapshot: (_) {},
      active: true,
    );
    await pumpEventQueue();
    expect(reads, 1);
    expect(controller.dirty(InvalidationResource.schedules), isFalse);
  });

  test('deactivating a destination discards its result and refreshes once reactivated', () async {
    final old = Completer<int>(), fresh = Completer<int>();
    var reads = 0;
    final applied = <int>[];
    controller.register<int>(
      InvalidationResource.pairing,
      readSnapshot: (_) => ++reads == 1 ? old.future : fresh.future,
      applySnapshot: applied.add,
      active: true,
    );
    controller.invalidate(
      const ChangeSignal(InvalidationResource.pairing),
      scope: scope,
    );
    await pumpEventQueue();
    controller.setActive(InvalidationResource.pairing, false);
    old.complete(1);
    await pumpEventQueue();
    expect(applied, isEmpty);
    expect(controller.dirty(InvalidationResource.pairing), isTrue);
    controller.setActive(InvalidationResource.pairing, true);
    await pumpEventQueue();
    fresh.complete(2);
    await pumpEventQueue();
    expect(applied, [2]);
    expect(reads, 2);
  });

  for (final changed in ['server', 'account', 'connection']) {
    test(
      '$changed replacement discards an awaited resource snapshot',
      () async {
        final result = Completer<int>();
        var applied = false;
        controller.register<int>(
          InvalidationResource.sessions,
          readSnapshot: (_) => result.future,
          applySnapshot: (_) => applied = true,
          active: true,
        );
        controller.invalidate(
          const ChangeSignal(InvalidationResource.sessions),
          scope: scope,
        );
        await pumpEventQueue();
        controller.bind(
          ChangeInvalidationScope(
            connection: changed == 'connection' ? Object() : scope.connection,
            server: changed == 'server' ? 'other' : scope.server,
            account: changed == 'account' ? 'other' : scope.account,
            profile: scope.profile,
          ),
        );
        result.complete(1);
        await pumpEventQueue();
        expect(applied, isFalse);
      },
    );
  }

  test(
    'a throwing failure presenter cannot leave a resource loading',
    () async {
      controller.register<int>(
        InvalidationResource.platforms,
        readSnapshot: (_) async => throw StateError('read failure'),
        applySnapshot: (_) {},
        onFailure: (_) => throw StateError('presentation failure'),
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.platforms),
        scope: scope,
      );
      await pumpEventQueue();
      expect(controller.loading(InvalidationResource.platforms), isFalse);
      expect(controller.dirty(InvalidationResource.platforms), isTrue);
      expect(controller.failed(InvalidationResource.platforms), isTrue);
    },
  );
  test(
    'telemetry reentry cannot present a failure after activity is retired',
    () async {
      controller.dispose();
      controller = ChangeInvalidationController(
        activity: activity,
        events: (_, [attributes = const {}]) {
          if (attributes['outcome'] == 'failed') activity.value = false;
        },
      );
      controller.bind(scope);
      var presented = false;
      controller.register<int>(
        InvalidationResource.platforms,
        readSnapshot: (_) async => throw StateError('read failed'),
        applySnapshot: (_) {},
        onFailure: (_) => presented = true,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.platforms),
        scope: scope,
      );
      await pumpEventQueue();
      expect(presented, isFalse);
      expect(controller.dirty(InvalidationResource.platforms), isTrue);
    },
  );

  test(
    'a hidden false activity notification still retires the old result',
    () async {
      controller.dispose();
      activity.dispose();
      activity = ValueNotifier(true);
      activity.addListener(() {
        if (!activity.value) activity.value = true;
      });
      controller = ChangeInvalidationController(activity: activity);
      controller.bind(scope);
      final old = Completer<int>(), fresh = Completer<int>();
      var reads = 0;
      final applied = <int>[];
      controller.register<int>(
        InvalidationResource.sessions,
        readSnapshot: (_) => ++reads == 1 ? old.future : fresh.future,
        applySnapshot: applied.add,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.sessions),
        scope: scope,
      );
      await pumpEventQueue();
      activity.value = false;
      await pumpEventQueue();
      old.complete(1);
      await pumpEventQueue();
      expect(applied, isEmpty);
      fresh.complete(2);
      await pumpEventQueue();
      expect(applied, [2]);
    },
  );

  test(
    'a hint arriving during a failed read gets one recovery follow-up',
    () async {
      final first = Completer<int>(), second = Completer<int>();
      var reads = 0;
      final applied = <int>[];
      controller.register<int>(
        InvalidationResource.schedules,
        readSnapshot: (_) => ++reads == 1 ? first.future : second.future,
        applySnapshot: applied.add,
        active: true,
      );
      controller.invalidate(
        const ChangeSignal(InvalidationResource.schedules),
        scope: scope,
      );
      await pumpEventQueue();
      controller.invalidate(
        const ChangeSignal(InvalidationResource.schedules),
        scope: scope,
      );
      first.completeError(StateError('old read failed'));
      await pumpEventQueue();
      expect(reads, 2);
      second.complete(2);
      await pumpEventQueue();
      expect(applied, [2]);
      expect(controller.failed(InvalidationResource.schedules), isFalse);
    },
  );
}
