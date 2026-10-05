import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_chat_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

/// Run with HERMES_DEV_URL from scripts/dev-backend.sh. This test refuses a
/// backend outside this checkout's throwaway home before creating profiles.
/// It never submits prompts, mirrors credentials, or switches the CLI default.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final skip = url == null ? 'set HERMES_DEV_URL to a throwaway backend' : null;
  HermesApiClient? api;
  HermesGatewayTransport? gateway;
  final names = <String>[];
  final nonce = DateTime.now().microsecondsSinceEpoch;

  setUpAll(() async {
    if (url == null) return;
    final http = Dio(BaseOptions(baseUrl: url));
    final status = (await http.get<Map<String, dynamic>>('/api/status')).data!;
    final expected = Directory(
      '${Directory.current.path}/.dart_tool/hermes-dev/home',
    ).resolveSymbolicLinksSync();
    final actual = status['hermes_home'];
    if (actual is! String ||
        Directory(actual).resolveSymbolicLinksSync() != expected) {
      throw StateError('Bot conformance requires the checkout throwaway home.');
    }
    final page = await http.get<String>('/');
    final token = RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(page.data ?? '')
        ?.group(1);
    http.options.headers['X-Hermes-Session-Token'] = token;
    api = HermesApiClient(http);
    gateway = HermesGatewayTransport(
      connect: hermesGatewayConnect(
        baseUrl: url,
        authRequired: false,
        api: api!,
      ),
    );
    for (final suffix in ['alpha', 'beta']) {
      final name = 'bot-contract-$nonce-$suffix';
      final created = await gateway!.request('profiles.create', {
        'name': name,
        'description': 'Isolated Bot Chat conformance',
        'mirror_credentials': false,
        'clone_channels': false,
      });
      expect(created['ok'], isTrue);
      names.add(name);
      final configured = await gateway!.request('profiles.configure', {
        'name': name,
        'ui_meta': {
          'hermes-bots': {'title': suffix},
        },
        'ui_meta_expected_revisions': {'hermes-bots': 0},
      });
      expect((configured['applied'] as Map)['ui_meta'], isTrue);
    }
  });

  tearDownAll(() async {
    for (final name in names) {
      await api!.raw.deleteProfileEndpointApiProfilesNameDelete(name: name);
    }
    await gateway?.close();
  });

  test('canonical creation materializes an empty hidden registry and resumes '
      'only under its owner', () async {
    final roster = await BotModeRosterRepository(
      gateway!.request,
      serverId: url!,
    ).load();
    expect(roster.supported, isTrue);
    final repository = BotModeChatRepository(gateway!.request);
    final chats = <BotModeChat>[];
    for (final name in names) {
      final bot = roster.bots.singleWhere((bot) => bot.name == name);
      final chat = await repository.open(bot);
      chats.add(chat);
      final exact = await gateway!.request('session.list', {
        'profile': name,
        'title': 'Bot Chat',
        'include_hidden': true,
        'limit': 200,
      });
      expect(exact['sessions'], hasLength(1));
      expect(((exact['sessions'] as List).single as Map)['id'], chat.rootId);
      final resumed = await gateway!.request('session.resume', {
        'profile': name,
        'session_id': chat.storedId,
      });
      expect(resumed['session_id'], isA<String>());
      expect(
        await HermesChatRepository(api!.raw)
            .loadMessages(chat.storedId, profile: name),
        isEmpty,
      );
    }
    expect(chats[0].storedId, isNot(chats[1].storedId));
    final reopened = await BotModeChatRepository(gateway!.request)
        .open(roster.bots.singleWhere((bot) => bot.name == names.first));
    expect(reopened.rootId, chats.first.rootId);
  }, skip: skip);

  test(
    'competing clients adopt one persisted canonical registry row',
    () async {
      // Retire alpha's first row using the generated profile-scoped REST call.
      final bot = BotModeBot(serverId: url!, name: names.first, revision: 1);
      final first = await BotModeChatRepository(gateway!.request).open(bot);
      await HermesChatRepository(api!.raw)
          .archiveThread(first.rootId, profile: bot.name);
      final independent = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url,
          authRequired: false,
          api: api!,
        ),
      );
      addTearDown(independent.close);
      final results = await Future.wait([
        BotModeChatRepository(gateway!.request).open(bot),
        BotModeChatRepository(independent.request).open(bot),
      ]);
      expect(results.first.rootId, results.last.rootId);
      expect(results.first.rootId, isNot(first.rootId));
    },
    skip: skip,
  );
}
