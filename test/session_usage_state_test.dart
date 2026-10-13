import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import 'support/recording_tracer.dart';

void main() {
  test(
    'nested usage loading retirement sends no request and clears binding',
    () async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      var calls = 0;
      final controller = SessionUsageController()
        ..bind(owner, (_, _) async {
          calls++;
          return {'total': 1};
        });
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      var nested = false;
      controller.addListener(() {
        if (!nested) {
          nested = true;
          controller.notifyListeners();
        } else {
          controller.dispose();
          controller.dispose();
          expect(controller.snapshot, isNull);
          expect(controller.bound, isFalse);
        }
      });
      try {
        await controller.refresh();
        expect(errors, isEmpty);
        expect(calls, 0);
        expect(controller.canRefresh, isFalse);
        controller.dispose();
        controller.notifyListeners();
      } finally {
        FlutterError.onError = previous;
        controller.dispose();
      }
    },
  );

  test('live usage retirement clears counters and rejects a held late fetch result', () async {
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: 'work',
    );
    final pending = Completer<Map<String, Object?>>();
    var calls = 0, retire = false;
    final controller = SessionUsageController()
      ..bind(owner, (_, _) {
        calls++;
        return pending.future;
      });
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    controller.addListener(() {
      if (retire) controller.dispose();
    });
    try {
      final refresh = controller.refresh();
      expect(calls, 1);
      retire = true;
      controller.tick(owner, {'total': 7});
      pending.complete({'total': 1});
      await refresh;
      expect(errors, isEmpty);
      expect(controller.snapshot, isNull);
      expect(controller.bound, isFalse);
      expect(controller.canRefresh, isFalse);
      controller.dispose();
      controller.notifyListeners();
    } finally {
      FlutterError.onError = previous;
      controller.dispose();
    }
  });

  test('usage snapshots preserve absence and reject malformed metrics', () {
    final usage = UsageSnapshot.decode({
      'model': 'scripted',
      'input': 3,
      'output': -1,
      'total': 8,
      'calls': 1,
      'reasoning': 2,
      'cost_usd': double.nan,
      'context_used': 4.5,
    });
    expect(usage!.input, 3);
    expect(usage.output, isNull);
    expect(usage.total, 8);
    expect(usage.reasoning, 2);
    expect(usage.costUsd, isNull);
    expect(usage.contextUsed, isNull);
    expect(
      UsageSnapshot.decode({'input': -1, 'output': double.infinity}),
      isNull,
    );
  });

  test(
    'live ticks replace session counters and final absence preserves freshness',
    () {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      final controller = SessionUsageController()
        ..bind(owner, (_, _) async => {});
      addTearDown(controller.dispose);
      controller.tick(owner, {'input': 10, 'total': 15});
      controller.tick(owner, {'input': 10, 'total': 15});
      expect(controller.snapshot!.total, 15);
      controller.complete(owner, {'input': 11, 'total': 16});
      expect(controller.snapshot!.total, 16);
      expect(controller.source, UsageSource.completion);
      controller.complete(owner, null);
      expect(controller.snapshot!.total, 16);
      expect(controller.source, UsageSource.completion);
      controller.tick(owner, {'input': 2, 'total': 3});
      expect(controller.snapshot!.total, 3);
    },
  );

  test(
    'usage requests carry explicit session and profile and newer ticks win',
    () async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      final pending = Completer<Map<String, Object?>>();
      final calls = <(String, Map<String, Object?>)>[];
      final controller = SessionUsageController()
        ..bind(owner, (method, params) {
          calls.add((method, params));
          return pending.future;
        });
      addTearDown(controller.dispose);
      final loading = controller.opened();
      controller.tick(owner, {'total': 20});
      pending.complete({'total': 1});
      await loading;
      expect(calls.single.$1, 'session.usage');
      expect(calls.single.$2, {'session_id': 'runtime', 'profile': 'work'});
      expect(controller.snapshot!.total, 20);
    },
  );

  test(
    'scope replacement rejects stale responses and wrong-session ticks',
    () async {
      final connection = Object();
      final oldOwner = UsageScope(
        connection: connection,
        sessionId: 'runtime',
        profile: 'one',
      );
      final newOwner = UsageScope(
        connection: connection,
        sessionId: 'runtime',
        profile: 'two',
      );
      final pending = Completer<Map<String, Object?>>();
      final controller = SessionUsageController()
        ..bind(oldOwner, (_, _) => pending.future);
      addTearDown(controller.dispose);
      final loading = controller.opened();
      controller.bind(newOwner, (_, _) async => {'total': 2});
      controller.tick(oldOwner, {'total': 10});
      pending.complete({'total': 1});
      await loading;
      expect(controller.snapshot, isNull);
      await controller.opened();
      expect(controller.snapshot!.total, 2);
    },
  );

  test('completion without usage invalidates an older read without inventing new totals', () async {
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: 'work',
    );
    final pending = Completer<Map<String, Object?>>();
    final controller = SessionUsageController()
      ..bind(owner, (_, _) => pending.future);
    addTearDown(controller.dispose);
    controller.tick(owner, {'total': 8});
    final loading = controller.refresh();
    controller.complete(owner, null);
    pending.complete({'total': 1});
    await loading;
    expect(controller.snapshot!.total, 8);
    expect(controller.source, UsageSource.live);
    expect(controller.freshness, UsageFreshness.current);
  });

  test('malformed ticks retain known counters with stale freshness', () {
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: 'work',
    );
    final controller = SessionUsageController()
      ..bind(owner, (_, _) async => {});
    addTearDown(controller.dispose);
    controller.tick(owner, {'total': 8});
    controller.tick(owner, {'total': -1});
    expect(controller.snapshot!.total, 8);
    expect(controller.freshness, UsageFreshness.stale);
  });

  test(
    'foreign session and connection ticks cannot replace owned counters',
    () {
      final connection = Object();
      final owner = UsageScope(
        connection: connection,
        sessionId: 'runtime-a',
        profile: 'work',
      );
      final otherSession = UsageScope(
        connection: connection,
        sessionId: 'runtime-b',
        profile: 'work',
      );
      final otherConnection = UsageScope(
        connection: Object(),
        sessionId: 'runtime-a',
        profile: 'work',
      );
      final controller = SessionUsageController()
        ..bind(owner, (_, _) async => {});
      addTearDown(controller.dispose);
      controller.tick(owner, {'total': 8});
      controller.tick(otherSession, {'total': 100});
      controller.tick(otherConnection, {'total': 200});
      expect(controller.snapshot!.total, 8);
      controller.bind(null, null);
      expect(controller.snapshot, isNull);
      expect(controller.bound, isFalse);
    },
  );

  test(
    'unsupported usage disables inspection while retaining chat independence',
    () async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: null,
      );
      var requests = 0;
      final controller = SessionUsageController()
        ..bind(owner, (_, params) async {
          requests++;
          expect(params, {'session_id': 'runtime', 'profile': null});
          throw const GatewayRpcException(
            -32601,
            'Unsupported private details',
          );
        });
      addTearDown(controller.dispose);
      await controller.opened();
      await controller.opened();
      expect(controller.freshness, UsageFreshness.unsupported);
      expect(requests, 1);
    },
  );

  test(
    'disconnect marks known counters stale and reconnect refreshes them',
    () async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      final controller = SessionUsageController()
        ..bind(owner, (_, _) async => {'total': 2});
      addTearDown(controller.dispose);
      controller.tick(owner, {'total': 1});
      controller.disconnected();
      expect(controller.freshness, UsageFreshness.stale);
      expect(controller.snapshot!.total, 1);
      await controller.reconnected();
      expect(controller.snapshot!.total, 2);
      expect(controller.freshness, UsageFreshness.current);
    },
  );

  test(
    'reconnection replaces an unfinished usage read with a fresh generation',
    () async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      final oldRead = Completer<Map<String, Object?>>();
      var requests = 0;
      final controller = SessionUsageController()
        ..bind(owner, (_, _) {
          requests++;
          return requests == 1 ? oldRead.future : Future.value({'total': 2});
        });
      addTearDown(controller.dispose);
      final earlier = controller.opened();
      await controller.reconnected();
      oldRead.complete({'total': 1});
      await earlier;
      expect(controller.snapshot!.total, 2);
    },
  );

  test('usage failures log only fixed categories and telemetry cannot break refresh', () async {
    final seen = <Map<String, Object>>[];
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'private-id',
      profile: 'private-profile',
    );
    final controller = SessionUsageController(
      telemetry: ConnectionTelemetry(
        events: (name, [attributes = const {}]) {
          if (name == 'chat.usage.fetch_failed') seen.add(Map.from(attributes));
          throw StateError('Telemetry unavailable');
        },
      ),
    )..bind(owner, (_, _) async => {'input': 'private-payload'});
    addTearDown(controller.dispose);
    await controller.opened();
    expect(controller.failure, UsageFailure.malformed);
    expect(seen, [
      {'category': 'malformed'},
    ]);
  });

  test('usage fetch spans inherit server metadata without usage payloads or identities', () async {
    final tracer = RecordingTracer();
    final trail = BreadcrumbTrail();
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'private-id',
      profile: 'private-profile',
    );
    final controller = SessionUsageController(
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        serverAttributes: {'hermes.version': 'test'},
      ),
      breadcrumbs: Breadcrumbs.of(trail),
    )..bind(owner, (_, _) async => {'model': 'private-model', 'total': 123});
    addTearDown(controller.dispose);
    await controller.opened();
    expect(tracer.spans.single.name, 'chat.usage.fetch');
    expect(tracer.spans.single.attributes, {
      'hermes.version': 'test',
      'outcome': 'success',
    });
    expect(tracer.spans.single.ended, isTrue);
    expect(
      trail.recent
          .singleWhere((crumb) => crumb.name == 'chat.usage.open')
          .attributes,
      isEmpty,
    );
  });

  test('throwing usage tracer cannot prevent a successful response', () async {
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: null,
    );
    final controller = SessionUsageController(
      telemetry: ConnectionTelemetry(tracer: ThrowingTracer()),
    )..bind(owner, (_, _) async => {'total': 0});
    addTearDown(controller.dispose);
    await controller.opened();
    expect(controller.snapshot!.total, 0);
  });
  test(
    'a reentrant usage bind retires the old request before it is sent',
    () async {
      final old = UsageScope(
        connection: Object(),
        sessionId: 'old-runtime',
        profile: 'old-profile',
      );
      final next = UsageScope(
        connection: Object(),
        sessionId: 'new-runtime',
        profile: 'new-profile',
      );
      var oldRequests = 0;
      final controller = SessionUsageController()
        ..bind(old, (_, _) async {
          oldRequests++;
          return {'total': 1};
        });
      addTearDown(controller.dispose);
      controller.addListener(() {
        if (controller.loading) {
          controller.bind(next, (_, _) async => {'total': 2});
        }
      });
      await controller.refresh();
      expect(oldRequests, 0);
      expect(controller.snapshot, isNull);
      expect(controller.loading, isFalse);
    },
  );
}
