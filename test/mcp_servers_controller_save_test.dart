import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_command_review_items.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late McpServersController controller;

  const remote = McpNewRemoteServer(name: 'linear', url: 'https://a.test/mcp');
  const command = McpNewCommandServer(
    name: 'notes',
    command: 'npx',
    args: ['-y', 'pkg'],
    env: {'NOTES_TOKEN': 'secret-value'},
  );

  Future<McpServersController> connect() async {
    final controller = McpServersController(
      repository: HermesMcpRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  int posts() => server.requestsTo('POST', '/api/mcp/servers').length;
  int puts() => server.requestsTo('PUT', '/api/mcp/servers').length;

  setUp(() async {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]))
      ..on('POST', '/api/mcp/servers', mcpServerRow(name: 'x'))
      ..on('PUT', '/api/mcp/servers', {'ok': true})
      ..on('GET', '/api/config', {'mcp_servers': <String, Object?>{}});
    controller = await connect();
  });

  Future<bool> approve(List<McpCommandReviewItem> _) async => true;
  Future<bool> refuse(List<McpCommandReviewItem> _) async => false;

  group('addServer', () {
    test('adds a remote server without a review and lists it', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'linear', url: 'https://a.test'),
        ]),
      );
      var reviews = 0;

      final outcome = await controller.addServer(
        remote,
        review: (_) async {
          reviews++;
          return true;
        },
      );

      expect(outcome, isA<McpAdded>().having((o) => o.name, 'name', 'linear'));
      expect(reviews, 0);
      expect(controller.serverNamed('linear'), isNotNull);
      expect(
        server
            .requestsTo('POST', '/api/mcp/servers')
            .single
            .queryParameters['profile'],
        'work',
      );
    });

    test(
      'makes no request until the review of a command server is confirmed',
      () async {
        List<McpCommandReviewItem>? shown;
        var postsWhileReviewing = -1;

        final outcome = await controller.addServer(
          command,
          review: (items) async {
            shown = items;
            postsWhileReviewing = posts();
            return true;
          },
        );

        expect(postsWhileReviewing, 0);
        expect(shown!.single.command, 'npx');
        expect(shown!.single.envNames, ['NOTES_TOKEN']);
        expect(posts(), 1);
        expect(outcome, isA<McpAdded>());
      },
    );

    test('makes no request when the review is declined', () async {
      final outcome = await controller.addServer(command, review: refuse);

      expect(outcome, isA<McpAddCancelled>());
      expect(posts(), 0);
    });

    test('makes no request when the review fails', () async {
      final outcome = await controller.addServer(
        command,
        review: (_) => throw StateError('no route'),
      );

      expect(outcome, isA<McpAddFailed>());
      expect(posts(), 0);
    });

    test('a second add during the review is ignored', () async {
      final answer = Completer<bool>();
      var reviews = 0;

      final first = controller.addServer(
        command,
        review: (_) {
          reviews++;
          return answer.future;
        },
      );
      expect(controller.isSaving, isTrue);
      final second = await controller.addServer(command, review: approve);
      answer.complete(true);
      await first;

      expect(second, isA<McpAddCancelled>());
      expect(reviews, 1);
      expect(posts(), 1);
      expect(controller.isSaving, isFalse);
    });

    test('a second add during the request is ignored', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', '/api/mcp/servers', (_) => answer.future);

      final first = controller.addServer(remote, review: approve);
      await Future<void>.delayed(Duration.zero);
      final second = await controller.addServer(remote, review: approve);
      answer.complete((status: 200, body: mcpServerRow(name: 'linear')));
      await first;

      expect(second, isA<McpAddCancelled>());
      expect(posts(), 1);
    });

    test('a duplicate name is a conflict', () async {
      server.on('POST', '/api/mcp/servers', {
        'detail': "Server 'linear' already exists",
      }, status: 409);

      expect(
        await controller.addServer(remote, review: approve),
        isA<McpAddDuplicate>(),
      );
    });

    test('a 400 carries Hermes reason', () async {
      server.on('POST', '/api/mcp/servers', {
        'detail':
            "Server 'notes' rejected: suspicious command/args configuration",
      }, status: 400);

      final outcome = await controller.addServer(command, review: approve);

      expect(
        outcome,
        isA<McpAddRefused>().having(
          (o) => o.reason,
          'reason',
          contains('suspicious'),
        ),
      );
    });

    test('any other failure is a failure', () async {
      server.on('POST', '/api/mcp/servers', {'detail': 'boom'}, status: 500);

      expect(
        await controller.addServer(remote, review: approve),
        isA<McpAddFailed>(),
      );
      expect(controller.isSaving, isFalse);
    });

    test('changes nothing when the profile could not be learned', () async {
      server.on('GET', '/api/profiles/active', {'detail': 'boom'}, status: 500);
      final unknown = await connect();

      final outcome = await unknown.addServer(remote, review: approve);

      expect(outcome, isA<McpAddFailed>());
      expect(posts(), 0);
    });
  });

  group('replaceServers', () {
    const loaded = <String, Object?>{
      'notes': {
        'command': 'npx',
        'args': ['-y', 'pkg'],
      },
      'linear': {'url': 'https://a.test/mcp'},
    };

    test('asks nothing when no command server is new or changed', () async {
      var reviews = 0;

      final outcome = await controller.replaceServers(
        loaded,
        {
          'notes': {
            'command': 'npx',
            'args': ['-y', 'pkg'],
            'enabled': false,
          },
          'linear': {'url': 'https://b.test/mcp'},
        },
        review: (_) async {
          reviews++;
          return true;
        },
      );

      expect(outcome, isA<McpReplaced>());
      expect(reviews, 0);
      expect(puts(), 1);
    });

    test('makes no request until the changed command is confirmed', () async {
      List<McpCommandReviewItem>? shown;
      var putsWhileReviewing = -1;

      await controller.replaceServers(
        loaded,
        {
          'notes': {'command': 'bash', 'args': <Object?>[]},
          'extra': {'command': 'true'},
        },
        review: (items) async {
          shown = items;
          putsWhileReviewing = puts();
          return true;
        },
      );

      expect(putsWhileReviewing, 0);
      expect(shown!.map((i) => i.name), ['notes', 'extra']);
      expect(puts(), 1);
    });

    test('makes no request when the review is declined', () async {
      final outcome = await controller.replaceServers(loaded, {
        'notes': {'command': 'bash'},
      }, review: refuse);

      expect(outcome, isA<McpReplaceCancelled>());
      expect(puts(), 0);
    });

    test('sends what was reviewed even if the map changes meanwhile', () async {
      final next = <String, Map<String, Object?>>{
        'notes': {
          'command': 'npx',
          'args': <Object?>['-y', 'pkg'],
        },
        'new': {'command': 'true'},
      };

      await controller.replaceServers(
        loaded,
        next,
        review: (_) async {
          next['sneaky'] = {'command': 'bash'};
          (next['new']!)['command'] = 'rm';
          return true;
        },
      );

      final body =
          jsonBody(server.requestsTo('PUT', '/api/mcp/servers').single) as Map;
      expect((body['servers'] as Map).keys, ['notes', 'new']);
      expect((body['servers'] as Map)['new'], {'command': 'true'});
    });

    test('a second save during the review is ignored', () async {
      final answer = Completer<bool>();

      final first = controller.replaceServers(loaded, {
        'new': {'command': 'true'},
      }, review: (_) => answer.future);
      final second = await controller.replaceServers(loaded, {
        'new': {'command': 'true'},
      }, review: approve);
      answer.complete(true);
      await first;

      expect(second, isA<McpReplaceCancelled>());
      expect(puts(), 1);
    });

    test('a 400 carries the problems', () async {
      server.on('PUT', '/api/mcp/servers', {
        'detail': "Server 'a': bad; Server 'b': worse",
      }, status: 400);

      final outcome = await controller.replaceServers(loaded, {
        'linear': <String, Object?>{},
      }, review: approve);

      expect(
        outcome,
        isA<McpReplaceRefused>().having((o) => o.problems, 'problems', [
          "Server 'a': bad",
          "Server 'b': worse",
        ]),
      );
    });

    test('any other failure is a failure', () async {
      server.on('PUT', '/api/mcp/servers', {'detail': 'boom'}, status: 500);

      expect(
        await controller.replaceServers(loaded, {}, review: approve),
        isA<McpReplaceFailed>(),
      );
    });

    test('lists the servers again after a save', () async {
      final before = server.requestsTo('GET', '/api/mcp/servers').length;

      await controller.replaceServers(loaded, {}, review: approve);

      expect(server.requestsTo('GET', '/api/mcp/servers').length, before + 1);
    });

    test('changes nothing when the profile could not be learned', () async {
      server.on('GET', '/api/profiles/active', {'detail': 'boom'}, status: 500);
      final unknown = await connect();

      final outcome = await unknown.replaceServers(loaded, {}, review: approve);

      expect(outcome, isA<McpReplaceFailed>());
      expect(puts(), 0);
    });
  });

  group('loadRawServers', () {
    test('reads the config of the active profile', () async {
      server.on('GET', '/api/config', {
        'mcp_servers': {
          'a': {'url': 'https://a.test', 'timeout': 5},
        },
      });

      final servers = await controller.loadRawServers();

      expect(servers['a'], {'url': 'https://a.test', 'timeout': 5});
      expect(
        server
            .requestsTo('GET', '/api/config')
            .single
            .queryParameters['profile'],
        'work',
      );
    });

    test('reads nothing when the profile could not be learned', () async {
      server.on('GET', '/api/profiles/active', {'detail': 'boom'}, status: 500);
      final unknown = await connect();

      await expectLater(unknown.loadRawServers(), throwsA(isA<StateError>()));
      expect(server.requestsTo('GET', '/api/config'), isEmpty);
    });
  });
}
