import 'dart:async';
import 'dart:convert';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_settings.dart';
import 'package:hermes_app/src/memory/memory_settings_controller.dart';
import 'package:hermes_app/src/memory/memory_settings_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/config', memorySettingsConfig())
      ..on('PUT', '/api/config', {'ok': true});
  });

  Future<MemorySettingsController> bound({
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) async {
    final controller = MemorySettingsController(breadcrumbs: breadcrumbs);
    addTearDown(controller.dispose);
    controller.bind(MemorySettingsRepository(server.client().raw), 'work');
    await controller.whenIdle;
    return controller;
  }

  List<Object?> writes() => [
    for (final request in server.requestsTo('PUT', '/api/config'))
      jsonDecode(request.data as String),
  ];

  test('reads the settings of the profile when bound', () async {
    final controller = await bound();
    expect(controller.settings, MemorySettings.defaults);
    expect(controller.unreadable, isFalse);
  });

  test('a change shows at once and keeps the server answer', () async {
    final controller = await bound();
    controller.change(MemorySetting.writeApproval, true);
    expect(controller.settings!.writeApproval, isTrue);
    await controller.whenIdle;
    expect(controller.settings!.writeApproval, isTrue);
    expect(controller.message, isNull);
    expect(writes(), [
      {
        'config': {
          'memory': {'write_approval': true},
        },
        'profile': 'work',
      },
    ]);
  });

  test('a refused change goes back and says which one', () async {
    final controller = await bound();
    server.on('PUT', '/api/config', {'detail': 'no'}, status: 400);
    controller.change(MemorySetting.agentNotes, false);
    expect(controller.settings!.agentNotes, isFalse);
    await controller.whenIdle;
    expect(controller.settings!.agentNotes, isTrue);
    expect(controller.message, "Couldn't change Keep agent notes. Try again.");
  });

  test('a change made while the key is in flight goes after it', () async {
    final controller = await bound();
    final first = Completer<void>();
    server.onRequest('PUT', '/api/config', (_) async {
      if (server.requestsTo('PUT', '/api/config').length == 1) {
        await first.future;
      }
      return (status: 200, body: {'ok': true});
    });
    controller.change(MemorySetting.reviewInterval, 5);
    await pumpEventQueue();
    controller.change(MemorySetting.reviewInterval, 20);
    expect(controller.settings!.reviewInterval, 20);
    expect(writes(), hasLength(1));
    first.complete();
    await controller.whenIdle;
    expect(writes().map((w) => (w as Map)['config']), [
      {
        'memory': {'nudge_interval': 5},
      },
      {
        'memory': {'nudge_interval': 20},
      },
    ]);
    expect(controller.settings!.reviewInterval, 20);
  });

  test('other keys are not held up by a write in flight', () async {
    final controller = await bound();
    final first = Completer<void>();
    server.onRequest('PUT', '/api/config', (_) async {
      if (server.requestsTo('PUT', '/api/config').length == 1) {
        await first.future;
      }
      return (status: 200, body: {'ok': true});
    });
    controller.change(MemorySetting.userProfile, false);
    await pumpEventQueue();
    controller.change(MemorySetting.writeApproval, true);
    await pumpEventQueue();
    expect(writes(), hasLength(2));
    first.complete();
    await controller.whenIdle;
  });

  test('a value the app does not offer is kept', () async {
    server.on(
      'GET',
      '/api/config',
      memorySettingsConfig(interval: 15, updates: 'loud'),
    );
    final controller = await bound();
    expect(controller.settings!.reviewInterval, 15);
    expect(controller.settings!.updatesInChat, 'loud');
  });

  test('an unreadable config hides the settings and can be retried', () async {
    server.on('GET', '/api/config', {'detail': 'x'}, status: 500);
    final controller = await bound();
    expect(controller.settings, isNull);
    expect(controller.unreadable, isTrue);
    server.on('GET', '/api/config', memorySettingsConfig());
    await controller.load();
    expect(controller.settings, isNotNull);
    expect(controller.unreadable, isFalse);
  });

  test('a change notes a breadcrumb with the key only', () async {
    final trail = BreadcrumbTrail();
    final controller = await bound(breadcrumbs: Breadcrumbs.of(trail));
    controller.change(MemorySetting.writeApproval, true);
    await controller.whenIdle;
    final crumb = trail.recent.single;
    expect(crumb.name, 'memory.setting_toggled');
    expect(crumb.attributes, {'key': 'write_approval'});
  });

  test('binding another profile clears the state and reads again', () async {
    final controller = await bound();
    server.on(
      'GET',
      '/api/config',
      memorySettingsConfig(writeApproval: true),
      query: {'profile': 'other'},
    );
    controller.bind(MemorySettingsRepository(server.client().raw), 'other');
    expect(controller.settings, isNull);
    await controller.whenIdle;
    expect(controller.settings!.writeApproval, isTrue);
    controller.bind(null, null);
    expect(controller.settings, isNull);
  });
}
