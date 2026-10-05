import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_chat_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  const bot = BotModeBot(serverId: 'server', name: 'research', revision: 1);
  const row = {'id': 'root', 'resolved_id': 'tip', 'title': 'Bot Chat'};
  late List<(String, Map<String, Object?>)> calls;
  late Future<Map<String, Object?>> Function(String, Map<String, Object?>)
  reply;
  late BotModeChatRepository repository;
  setUp(() {
    calls = [];
    reply = (_, _) async => {
      'sessions': [row],
    };
    repository = BotModeChatRepository((method, params) {
      calls.add((method, params));
      return reply(method, params);
    });
  });

  test('exact lookup adopts compression tip under the owner', () async {
    final chat = await repository.open(bot);
    expect(chat.rootId, 'root');
    expect(chat.storedId, 'tip');
    expect(chat.profile, 'research');
    expect(calls.single.$1, 'session.list');
    expect(calls.single.$2, {
      'profile': 'research',
      'title': 'Bot Chat',
      'include_hidden': true,
      'limit': 200,
    });
  });

  test('failed lookup creates nothing', () async {
    reply = (_, _) async => throw const GatewayRpcException(4000, 'failed');
    await expectLater(
      repository.open(bot),
      throwsA(isA<GatewayRpcException>()),
    );
    expect(calls.map((c) => c.$1), ['session.list']);
  });

  test('malformed registry cannot establish absence', () async {
    reply = (_, _) async => {};
    await expectLater(repository.open(bot), throwsStateError);
    expect(calls.length, 1);
  });

  test('roster pointer prevents replacement after empty lookup', () async {
    reply = (_, _) async => {'sessions': []};
    await expectLater(
      repository.open(
        const BotModeBot(
          serverId: 'server',
          name: 'research',
          revision: 1,
          canonicalSessionId: 'root',
        ),
      ),
      throwsStateError,
    );
    expect(calls.length, 1);
  });

  test(
    'creation is serialized and title materialized without a prompt',
    () async {
      var persisted = false;
      final gate = Completer<void>();
      reply = (method, _) async {
        if (method == 'session.list') {
          return {
            'sessions': persisted ? [row] : [],
          };
        }
        if (method == 'session.create') {
          await gate.future;
          return {'session_id': 'runtime', 'stored_session_id': 'root'};
        }
        persisted = true;
        return {'title': 'Bot Chat', 'pending': false};
      };
      final first = repository.open(bot);
      final second = repository.open(bot);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      expect((await first).storedId, 'root');
      expect((await second).storedId, 'tip');
      expect(calls.where((c) => c.$1 == 'session.create').length, 1);
      expect(calls.firstWhere((c) => c.$1 == 'session.create').$2, {
        'profile': 'research',
        'title': 'Bot Chat',
        'hidden': true,
        'follow_profile_config': true,
      });
      expect(calls.firstWhere((c) => c.$1 == 'session.title').$2, {
        'session_id': 'runtime',
        'title': 'Bot Chat',
      });
      expect(calls.any((c) => c.$1 == 'prompt.submit'), isFalse);
    },
  );

  test('pending title must be verified in registry', () async {
    var lookups = 0;
    reply = (method, _) async => switch (method) {
      'session.list' => {
        'sessions': lookups++ == 0 ? [] : [row],
      },
      'session.create' => {
        'session_id': 'runtime',
        'stored_session_id': 'root',
      },
      _ => {'pending': true},
    };
    expect((await repository.open(bot)).storedId, 'tip');
  });

  test('pending title without persisted row is retryable failure', () async {
    reply = (method, _) async => switch (method) {
      'session.list' => {'sessions': []},
      'session.create' => {
        'session_id': 'runtime',
        'stored_session_id': 'root',
      },
      _ => {'pending': true},
    };
    await expectLater(repository.open(bot), throwsStateError);
    await expectLater(repository.open(bot), throwsStateError);
    expect(calls.where((c) => c.$1 == 'session.create').length, 1);
  });

  test(
    'unsupported title materialization cannot create another draft',
    () async {
      reply = (method, _) async {
        if (method == 'session.list') return {'sessions': []};
        if (method == 'session.create') {
          return {'session_id': 'runtime', 'stored_session_id': 'root'};
        }
        throw const GatewayRpcException(-32601, 'session.title unsupported');
      };
      for (var retry = 0; retry < 2; retry++) {
        await expectLater(
          repository.open(bot),
          throwsA(isA<GatewayRpcException>()),
        );
      }
      expect(calls.where((c) => c.$1 == 'session.create').length, 1);
    },
  );

  test('title conflict adopts the competing creator', () async {
    var lookups = 0;
    reply = (method, _) async {
      if (method == 'session.list') {
        return {
          'sessions': lookups++ == 0 ? [] : [row],
        };
      }
      if (method == 'session.create') {
        return {'session_id': 'runtime', 'stored_session_id': 'stray'};
      }
      throw const GatewayRpcException(4090, 'title already exists');
    };
    expect((await repository.open(bot)).rootId, 'root');
    expect(calls.where((c) => c.$1 == 'session.create').length, 1);
  });
}
