import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart' show SessionRename;

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
/// profile test switches the active profile back to `default`, the setup
/// test writes and then clears a Telegram token (skipped if one is set), and
/// the session tests rename, pin and archive the newest session, then undo it
/// (a title the session had not set is left as its displayed one). Deleting
/// is not tried. The gateway test makes two real model calls, which cost
/// money. The Telegram pairing test contacts the hosted setup service, so it
/// also needs `HERMES_DEV_TELEGRAM_PAIRING=1`.
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

  test('session pages follow each other without gaps', () async {
    final repository = HermesChatRepository(client.raw);
    final first = await repository.loadThreadPage(limit: 2);
    if (!first.hasMore) return;

    final second = await repository.loadThreadPage(
      limit: 2,
      offset: first.nextOffset,
    );

    final pinnedIds = {
      for (final t in [...first.threads, ...second.threads])
        if (t.pinned) t.id,
    };
    final ids = {for (final t in first.threads) t.id};
    expect(
      second.threads.where(
        (t) => ids.contains(t.id) && !pinnedIds.contains(t.id),
      ),
      isEmpty,
    );
  }, skip: skip);

  test('a session can be renamed and renamed back', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;
    final thread = threads.first;
    final renamed = 'contract check ${DateTime.now().microsecondsSinceEpoch}';

    try {
      expect(await repository.renameThread(thread.id, renamed), renamed);
      final reloaded = await repository.loadThreads();
      expect(reloaded.firstWhere((t) => t.id == thread.id).title, renamed);
    } finally {
      await repository.renameThread(thread.id, thread.title);
    }
  }, skip: skip);

  test('a session can be pinned and unpinned', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;
    final thread = threads.firstWhere(
      (t) => !t.pinned,
      orElse: () => threads.first,
    );

    try {
      await repository.setPinned(thread.id, !thread.pinned);
      final flipped = (await repository.loadThreads()).firstWhere(
        (t) => t.id == thread.id,
      );
      expect(flipped.pinned, !thread.pinned);
    } finally {
      await repository.setPinned(thread.id, thread.pinned);
    }
  }, skip: skip);

  test('an archived session leaves the list and comes back', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;
    final thread = threads.first;

    try {
      await repository.archiveThread(thread.id);
      final after = await repository.loadThreads();
      expect(after.map((t) => t.id), isNot(contains(thread.id)));
    } finally {
      await client.raw.renameSessionEndpointApiSessionsSessionIdPatch(
        sessionId: thread.id,
        sessionRename: SessionRename(archived: false),
      );
    }
    final restored = await repository.loadThreads();
    expect(restored.map((t) => t.id), contains(thread.id));
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

  test('a platform\'s setup can be saved, shows as set without its value, '
      'and cleared again', () async {
    final repository = HermesBotsRepository(client.raw);
    Future<HermesBotEnvVar> tokenVar() async => (await repository.load())
        .firstWhere((b) => b.id == 'telegram')
        .envVars
        .firstWhere((v) => v.key == 'TELEGRAM_BOT_TOKEN');
    if ((await tokenVar()).isSet) {
      markTestSkipped('a Telegram token is already set on this backend');
      return;
    }
    final value = '123456789:${'a' * 35}';

    try {
      await repository.saveSetup(
        'telegram',
        env: {'TELEGRAM_BOT_TOKEN': value},
      );
      final saved = await tokenVar();
      expect(saved.isSet, isTrue);
      expect(saved.redactedValue, isNot(value));
    } finally {
      await repository.saveSetup('telegram', clear: ['TELEGRAM_BOT_TOKEN']);
    }
    expect((await tokenVar()).isSet, isFalse);
  }, skip: skip);

  test('a value the dashboard refuses comes back with the reason', () async {
    final repository = HermesBotsRepository(client.raw);

    await expectLater(
      repository.saveSetup('telegram', env: {'TELEGRAM_BOT_TOKEN': 'abc'}),
      throwsA(
        isA<BotSetupRejected>().having(
          (e) => e.message,
          'message',
          contains('bot token'),
        ),
      ),
    );
  }, skip: skip);

  test('an unknown Telegram pairing is reported as such', () async {
    final repository = HermesBotsRepository(client.raw);

    await expectLater(
      repository.telegramPairingStatus('no-such-pairing'),
      throwsA(isA<BotSetupRejected>()),
    );
  }, skip: skip);

  test('Telegram user ids that are not numeric are refused before anything is '
      'saved', () async {
    final repository = HermesBotsRepository(client.raw);

    await expectLater(
      repository.applyTelegramPairing('no-such-pairing', ['abc']),
      throwsA(
        isA<BotSetupRejected>().having(
          (e) => e.message,
          'message',
          contains('numeric'),
        ),
      ),
    );
  }, skip: skip);

  test(
    'a Telegram pairing starts, waits for the user and can be cancelled',
    () async {
      final repository = HermesBotsRepository(client.raw);

      final pairing = await repository.startTelegramPairing();
      final status = await repository.telegramPairingStatus(pairing.id);
      await repository.cancelTelegramPairing(pairing.id);

      expect(Uri.parse(pairing.deepLink).host, 't.me');
      expect(status.ready, isFalse);
    },
    skip: Platform.environment['HERMES_DEV_TELEGRAM_PAIRING'] == null
        ? 'set HERMES_DEV_TELEGRAM_PAIRING to run (contacts the hosted setup '
              'service)'
        : skip,
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
