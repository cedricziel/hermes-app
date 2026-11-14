import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/tools_controller.dart';

import '../support/fake_hermes_server.dart';
import 'tools_fixtures.dart';

const _plain = <String, Object?>{
  'name': 'terminal',
  'has_category': true,
  'providers': <Object?>[],
};

void main() {
  late FakeHermesServer server;
  late ToolsController controller;
  late List<String> events;

  List<Object?> catalog({bool terminalOn = false, bool webOn = true}) => [
    {...(toolsetsFixture[0]! as Map<String, Object?>), 'enabled': webOn},
    {...(toolsetsFixture[1]! as Map<String, Object?>), 'enabled': terminalOn},
    {
      'name': 'todo',
      'label': 'Todo',
      'enabled': false,
      'configured': true,
      'platform': 'cli',
    },
  ];

  Iterable<RequestOptions> puts() =>
      server.requests.where((r) => r.method == 'PUT');

  setUp(() async {
    server = FakeHermesServer();
    events = [];
    server
      ..on('GET', '/api/tools/toolsets', catalog())
      ..on('GET', '/api/tools/toolsets/terminal/config', _plain)
      ..on('GET', '/api/tools/toolsets/todo/config', {
        'name': 'todo',
        'has_category': false,
      })
      ..on('GET', '/api/tools/toolsets/web/config', webConfigFixture);
    controller = ToolsController(
      toolsRepository(server),
      checkTimeout: const Duration(milliseconds: 200),
      telemetry: ConnectionTelemetry(
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
      ),
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('groups rows by what works and keeps the server order', () {
    final groups = controller.groups;

    expect(groups.needsSetup.map((t) => t.name), ['web']);
    expect(groups.off.map((t) => t.name), ['terminal', 'todo']);
    expect(groups.on, isEmpty);
    expect(controller.loadState, ToolsLoadState.ready);
  });

  test('a toolset that needs nothing is switched at once', () async {
    server.on('PUT', '/api/tools/toolsets/todo', {
      'ok': true,
      'name': 'todo',
      'enabled': true,
    });
    server.on(
      'GET',
      '/api/tools/toolsets',
      catalog()..[2] = {...(catalog()[2]! as Map), 'enabled': true},
    );

    await controller.requestSwitch('todo', enabled: true);

    expect(puts(), hasLength(1));
    expect(controller.confirmation, isNull);
    expect(controller.groups.on.map((t) => t.name), ['todo']);
    expect(controller.rowState('todo').phase, ToolsRowPhase.idle);
    expect(controller.changedSinceOpen, isTrue);
    expect(
      events,
      contains('tools.toggled {toolset: todo, enabled: true, outcome: ok}'),
    );
  });

  group('a confirm-level toolset', () {
    test('sends nothing and keeps its position until confirmed', () async {
      await controller.requestSwitch('terminal', enabled: true);

      expect(puts(), isEmpty);
      expect(controller.confirmation?.toolset.name, 'terminal');
      expect(controller.confirmation?.risk?.asksBeforeSwitchingOn, isTrue);
      expect(
        controller.rowState('terminal').phase,
        ToolsRowPhase.awaitingConfirmation,
      );
      expect(controller.rowState('terminal').shownEnabled, isNull);
    });

    test('cancel sends nothing and leaves the switch off', () async {
      await controller.requestSwitch('terminal', enabled: true);
      controller.cancel();

      expect(puts(), isEmpty);
      expect(controller.confirmation, isNull);
      expect(controller.rowState('terminal').phase, ToolsRowPhase.idle);
      expect(
        events,
        contains('tools.risk_confirmed {toolset: terminal, confirmed: false}'),
      );
    });

    test('the optimistic state starts only after confirm', () async {
      final gate = Completer<void>();
      server.onRequest('PUT', '/api/tools/toolsets/terminal', (_) async {
        await gate.future;
        return (
          status: 200,
          body: {'ok': true, 'name': 'terminal', 'enabled': true},
        );
      });
      await controller.requestSwitch('terminal', enabled: true);
      expect(controller.rowState('terminal').shownEnabled, isNull);

      final done = controller.confirm();
      await Future<void>.delayed(Duration.zero);

      expect(controller.rowState('terminal').phase, ToolsRowPhase.saving);
      expect(controller.rowState('terminal').shownEnabled, isTrue);
      expect(controller.groups.off.map((t) => t.name), contains('terminal'));
      gate.complete();
      await done;
      expect(controller.rowState('terminal').phase, ToolsRowPhase.idle);
    });

    test('switching off never asks', () async {
      server.on('GET', '/api/tools/toolsets', catalog(terminalOn: true));
      await controller.load();
      server.on('PUT', '/api/tools/toolsets/terminal', {
        'ok': true,
        'name': 'terminal',
        'enabled': false,
      });

      await controller.requestSwitch('terminal', enabled: false);

      expect(controller.confirmation, isNull);
      expect(puts(), hasLength(1));
    });

    test('a second request while a question is open does nothing', () async {
      await controller.requestSwitch('terminal', enabled: true);
      await controller.requestSwitch('todo', enabled: true);

      expect(puts(), isEmpty);
      expect(controller.confirmation?.toolset.name, 'terminal');
    });
  });

  test('a toolset whose provider has an install step asks too', () async {
    // web is on in the fixture: switch it off, then on again.
    server
      ..on('PUT', '/api/tools/toolsets/web', {
        'ok': true,
        'name': 'web',
        'enabled': false,
      })
      ..on('GET', '/api/tools/toolsets', catalog(webOn: false));
    await controller.requestSwitch('web', enabled: false);
    final before = puts().length;

    await controller.requestSwitch('web', enabled: true);

    expect(controller.confirmation?.installsSoftware, isTrue);
    expect(controller.confirmation?.risk, isNull);
    expect(puts().length, before);
  });

  test('a setup that cannot be read sends nothing', () async {
    server.on('GET', '/api/tools/toolsets/terminal/config', {
      'detail': 'x',
    }, status: 500);

    await controller.requestSwitch('terminal', enabled: true);

    expect(puts(), isEmpty);
    expect(controller.confirmation, isNull);
    expect(
      controller.rowState('terminal').error?.kind,
      ToolsRowErrorKind.failed,
    );
  });

  group('failures roll back on the row that was flipped', () {
    Future<void> failWith(int status, Object body) async {
      server.on('PUT', '/api/tools/toolsets/todo', body, status: status);
      await controller.requestSwitch('todo', enabled: true);
    }

    test('a refusal carries Hermes\' text', () async {
      await failWith(400, {'detail': 'Blank value'});

      final row = controller.rowState('todo');
      expect(row.error?.kind, ToolsRowErrorKind.refused);
      expect(row.error?.detail, 'Blank value');
      expect(row.shownEnabled, isNull);
      expect(controller.groups.off.map((t) => t.name), contains('todo'));
      expect(controller.rowState('terminal').error, isNull);
    });

    test('401 and 403 are "not allowed"', () async {
      await failWith(403, {'detail': 'no'});

      expect(
        controller.rowState('todo').error?.kind,
        ToolsRowErrorKind.forbidden,
      );
    });

    test('a 500 is a plain failure', () async {
      await failWith(500, {'detail': 'boom'});

      expect(controller.rowState('todo').error?.kind, ToolsRowErrorKind.failed);
    });

    test('an unknown toolset that is gone from the list says so', () async {
      server.on('GET', '/api/tools/toolsets', [catalog()[0]]);
      await failWith(400, {'detail': 'Unknown toolset: todo'});

      expect(controller.toolVanished, isTrue);
      expect(controller.rowState('todo').error, isNull);
    });

    test('the error goes when the list is read again', () async {
      await failWith(500, {'detail': 'boom'});
      await controller.load();

      expect(controller.rowState('todo').error, isNull);
    });
  });

  group('a lost answer', () {
    void lose() => server.onRequest('PUT', '/api/tools/toolsets/todo', (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });

    test('reads the list again and takes the server\'s state', () async {
      lose();
      server.on(
        'GET',
        '/api/tools/toolsets',
        catalog()..[2] = {...(catalog()[2]! as Map), 'enabled': true},
      );

      await controller.requestSwitch('todo', enabled: true);

      expect(controller.groups.on.map((t) => t.name), ['todo']);
      expect(controller.rowState('todo').phase, ToolsRowPhase.idle);
      expect(puts(), hasLength(1));
    });

    test('ends in "couldn\'t confirm" within the limit when the read '
        'hangs, with the last saved state', () async {
      lose();
      final hang = Completer<void>();
      server.onRequest('GET', '/api/tools/toolsets', (_) async {
        await hang.future;
        return (status: 200, body: catalog());
      });

      final done = controller.requestSwitch('todo', enabled: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.rowState('todo').phase, ToolsRowPhase.checking);
      await done;

      expect(controller.rowState('todo').phase, ToolsRowPhase.unconfirmed);
      expect(controller.rowState('todo').shownEnabled, isNull);
      expect(controller.groups.off.map((t) => t.name), contains('todo'));
      expect(puts(), hasLength(1));
      hang.complete();
    });

    test('ends in "couldn\'t confirm" when the read fails, and nothing '
        'is resent', () async {
      lose();
      server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 500);

      await controller.requestSwitch('todo', enabled: true);

      expect(controller.rowState('todo').phase, ToolsRowPhase.unconfirmed);
      expect(puts(), hasLength(1));
      expect(events.last, contains('outcome: unknown'));
    });
  });

  test('a second tap waits for the first answer', () async {
    final gate = Completer<void>();
    server.onRequest('PUT', '/api/tools/toolsets/todo', (_) async {
      await gate.future;
      return (status: 200, body: {'ok': true, 'name': 'todo', 'enabled': true});
    });
    server.on(
      'GET',
      '/api/tools/toolsets',
      catalog()..[2] = {...(catalog()[2]! as Map), 'enabled': true},
    );
    final first = controller.requestSwitch('todo', enabled: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await controller.requestSwitch('todo', enabled: false);
    expect(puts(), hasLength(1));

    gate.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(puts(), hasLength(2));
  });

  test('post_setup_started is handed on', () async {
    server.on('PUT', '/api/tools/toolsets/todo', {
      'ok': true,
      'name': 'todo',
      'enabled': true,
      'post_setup_started': 'some_driver',
    });

    await controller.requestSwitch('todo', enabled: true);

    expect(controller.postSetupStarted, 'some_driver');
  });

  test('a 404 on a write marks the server as without tools', () async {
    server.on('PUT', '/api/tools/toolsets/todo', {
      'detail': 'Not Found',
    }, status: 404);

    await controller.requestSwitch('todo', enabled: true);

    expect(controller.loadState, ToolsLoadState.unsupported);
  });

  test('a missing profile is not "unsupported"', () async {
    server.on('GET', '/api/tools/toolsets', {
      'detail': "Profile 'work' does not exist",
    }, status: 404);

    await controller.load();

    expect(controller.loadState, ToolsLoadState.profileGone);
  });

  test('a failed read keeps the rows already shown', () async {
    server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 500);

    await controller.load();

    expect(controller.loadState, ToolsLoadState.failed);
    expect(controller.toolsets, hasLength(3));
  });

  test(
    'late answers are dropped after a profile switch and a dispose',
    () async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/tools/toolsets', (_) async {
        await gate.future;
        return (status: 200, body: catalog());
      });
      final late = controller.load();
      controller.switchProfile(toolsRepository(server, profile: 'home'));
      gate.complete();
      await late;

      expect(controller.toolsets, isEmpty);
      expect(controller.profile, 'home');

      final other = ToolsController(toolsRepository(server));
      final pending = other.load();
      other.dispose();
      await pending;
    },
  );

  test('telemetry names only fixed slugs', () async {
    server.on('GET', '/api/tools/toolsets', [
      {'name': 'my_private_plugin', 'enabled': false, 'configured': true},
    ]);
    server.on('GET', '/api/tools/toolsets/my_private_plugin/config', {
      'has_category': false,
    });
    server.on('PUT', '/api/tools/toolsets/my_private_plugin', {
      'ok': true,
      'enabled': true,
    });
    await controller.load();

    await controller.requestSwitch('my_private_plugin', enabled: true);

    expect(events.join(), isNot(contains('my_private_plugin')));
    expect(events.join(), contains('toolset: other'));
  });
}
