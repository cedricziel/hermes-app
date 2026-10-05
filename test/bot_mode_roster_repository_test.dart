import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  final calls = <(String, Map<String, Object?>)>[];
  final answers = <String, Map<String, Object?>>{};
  late BotModeRosterRepository repository;

  setUp(() {
    calls.clear();
    answers.clear();
    repository = BotModeRosterRepository((method, params) async {
      calls.add((method, params));
      return answers[method] ?? const {};
    }, serverId: 'local');
  });

  test('reads managed rows, optional preview and preserves metadata', () async {
    answers['profiles.list'] = {
      'bot_mode_protocol': true,
      'profiles': [
        {
          'name': 'writer',
          'display_name': 'Writer',
          'model': 'm',
          'provider': 'p',
          'ui_meta_revisions': {'hermes-bots': 4},
          'ui_meta': {
            'hermes-bots': {
              'title': 'Editor',
              'description': 'Copy',
              'color': 'red',
            },
          },
          'canonical_session': {'id': 's1', 'preview': 'Hello'},
        },
        {
          'name': 'plain',
          'ui_meta_revisions': {'hermes-bots': 0},
        },
      ],
    };
    final roster = await repository.load();
    expect(roster.supported, isTrue);
    expect(roster.bots.single.title, 'Editor');
    expect(roster.bots.single.canonicalSessionId, 's1');
    expect(roster.availableProfiles.single.name, 'plain');
    expect(calls.single.$2, {'include_sessions': true});
  });

  test('missing revision support is unavailable, not a write probe', () async {
    answers['profiles.list'] = {
      'bot_mode_protocol': true,
      'profiles': [
        {'name': 'old'},
      ],
    };
    expect((await repository.load()).supported, isFalse);
    expect(calls.map((call) => call.$1), ['profiles.list']);
  });

  test('method absence is unsupported, other errors remain errors', () async {
    repository = BotModeRosterRepository(
      (_, _) async =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'missing'),
      serverId: 'local',
    );
    expect((await repository.load()).supported, isFalse);
    repository = BotModeRosterRepository(
      (_, _) async => throw const GatewayRpcException(403, 'forbidden'),
      serverId: 'local',
    );
    await expectLater(repository.load(), throwsA(isA<GatewayRpcException>()));
  });

  test('CAS patch retains unknown fields and reports conflict', () async {
    answers['profiles.configure'] = {
      'ok': false,
      'applied': {
        'ui_meta': false,
        'ui_meta_conflicts': {
          'hermes-bots': {'actual': 5},
        },
      },
    };
    final bot = BotModeBot(
      serverId: 'local',
      name: 'writer',
      revision: 4,
      metadata: const {'color': 'red', 'title': 'Old'},
    );
    final result = await repository.save(bot, title: 'New');
    expect(result.conflict, isTrue);
    expect(result.applied['ui_meta'], isFalse);
    expect(calls.single.$2['ui_meta_expected_revisions'], {'hermes-bots': 4});
    expect(calls.single.$2['ui_meta'], {
      'hermes-bots': {'color': 'red', 'title': 'New'},
    });
  });

  test('partial save checks requested sections individually', () async {
    answers['profiles.configure'] = {
      'ok': false,
      'applied': {'ui_meta': true, 'soul': false},
    };
    final result = await repository.save(
      const BotModeBot(serverId: 'local', name: 'writer', revision: 0),
      title: 'New',
      soul: 'Instructions',
    );
    expect(result.succeeded, isFalse);
    expect(result.failedSections, ['soul']);
  });

  test('fresh creation explicitly prevents channel cloning', () async {
    answers['profiles.create'] = {'ok': true, 'name': 'writer', 'mirrored': {}};
    final result = await repository.create(
      name: 'writer',
      description: 'Copy',
      mirrorCredentials: false,
    );
    expect(result.name, 'writer');
    expect(calls.single.$2, containsPair('clone_channels', false));
    expect(calls.single.$2, containsPair('mirror_credentials', false));
    expect(calls.single.$2, isNot(contains('clone_from')));
  });
}
