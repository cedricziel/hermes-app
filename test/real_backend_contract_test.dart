import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

/// Runs the repositories against a real Hermes dashboard, to check the
/// response shapes they parse (the spec declares none for these routes), and
/// the chat gateway over its websocket.
///
///     scripts/dev-backend.sh start
///     HERMES_DEV_URL=$(scripts/dev-backend.sh url) flutter test \
///       test/real_backend_contract_test.dart
///
/// Skipped when `HERMES_DEV_URL` is unset. Use a throwaway backend: the
/// profile test switches the active profile back to `default`. The gateway
/// test makes two real model calls, which cost money.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final skip = url == null ? 'set HERMES_DEV_URL to run' : null;

  late HermesApiClient client;

  setUpAll(() async {
    if (url == null) return;
    final page = await Dio().get<String>('$url/');
    final token = RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(page.data ?? '')
        ?.group(1);
    client = HermesApiClient(
      Dio(
        BaseOptions(baseUrl: url, headers: {'X-Hermes-Session-Token': ?token}),
      ),
    );
  });

  test('sessions load as threads', () async {
    final threads = await HermesChatRepository(client.raw).loadThreads();

    expect(threads.every((t) => t.id.isNotEmpty && t.title.isNotEmpty), isTrue);
  }, skip: skip);

  test('the first session\'s messages load', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;

    final messages = await repository.loadMessages(threads.first.id);

    expect(messages.every((m) => m.id.startsWith(threads.first.id)), isTrue);
  }, skip: skip);

  test(
    'the active profile reports both the CLI default and the scope',
    () async {
      final active = await HermesProfilesRepository(client.raw).loadActive();

      expect(active.active, isNotEmpty);
      expect(active.current, isNotEmpty);
    },
    skip: skip,
  );

  test('sessions and their messages load per profile', () async {
    final active = (await HermesProfilesRepository(
      client.raw,
    ).loadActive()).active;
    final repository = HermesChatRepository(client.raw);

    final threads = await repository.loadThreads(profile: active);
    if (threads.isEmpty) return;
    final messages = await repository.loadMessages(
      threads.first.id,
      profile: active,
    );

    expect(messages.every((m) => m.id.startsWith(threads.first.id)), isTrue);
  }, skip: skip);

  test('an unknown profile is refused rather than read as empty', () async {
    final repository = HermesChatRepository(client.raw);

    expect(
      repository.loadThreads(profile: 'no-such-profile'),
      throwsA(isA<DioException>()),
    );
  }, skip: skip);

  test('profiles load and the active one can be set', () async {
    final repository = HermesProfilesRepository(client.raw);

    final overview = await repository.load();
    await repository.setActive(overview.active);

    expect(overview.profiles.map((p) => p.name), contains(overview.active));
  }, skip: skip);

  test('messaging platforms load as bots', () async {
    final bots = await HermesBotsRepository(client.raw).load();

    expect(bots, isNotEmpty);
    expect(bots.every((b) => b.name.isNotEmpty), isTrue);
  }, skip: skip);

  test(
    'the gateway streams a reply and continues the thread it created',
    () async {
      final transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        ),
      );
      addTearDown(transport.close);

      final first = await transport
          .send(text: 'Reply with the single word: pong. Use no tools.')
          .toList();

      final bound = first.first as ThreadBound;
      expect(first.whereType<ReplyStarted>(), isNotEmpty);
      final completed = first.last as ReplyCompleted;
      expect(completed.failed, isFalse);
      expect(completed.text.toLowerCase(), contains('pong'));
      expect(first.whereType<ReplyDelta>(), isNotEmpty);

      final threads = await HermesChatRepository(client.raw).loadThreads();
      expect(threads.map((t) => t.id), contains(bound.threadId));

      final second = await transport
          .send(threadId: bound.threadId, text: 'Now say: ping')
          .toList();

      expect(second.whereType<ThreadBound>(), isEmpty);
      expect((second.last as ReplyCompleted).failed, isFalse);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('platforms describe their setup variables', () async {
    final bots = await HermesBotsRepository(client.raw).load();

    final token = bots
        .firstWhere((b) => b.id == 'telegram')
        .envVars
        .firstWhere((v) => v.key == 'TELEGRAM_BOT_TOKEN');
    expect(token.label, isNotEmpty);
    expect(token.required, isTrue);
    expect(token.isPassword, isTrue);
    final vars = bots.expand((b) => b.envVars);
    expect(vars.every((v) => v.isSet || v.redactedValue == null), isTrue);
  }, skip: skip);
}
