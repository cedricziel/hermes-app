import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart' show SessionRename;

import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';

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
/// test writes and then clears a Telegram token (skipped if one is set), the
/// skills test switches one skill off and back on, the plugin tests switch a
/// bundled plugin off and on and hide and show it, then put both back, and
/// the session tests rename, pin and archive the newest session, then undo it
/// (a title the session had not set is left as its displayed one). Deleting
/// is not tried. The gateway test makes two real model calls, which cost
/// money and need a provider configured in the backend, so it also needs
/// `HERMES_DEV_MODEL_CALLS=1`. The Telegram pairing test contacts the hosted
/// setup service, so it also needs `HERMES_DEV_TELEGRAM_PAIRING=1`.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final skip = url == null ? 'set HERMES_DEV_URL to run' : null;
  final modelSkip =
      skip ??
      (Platform.environment['HERMES_DEV_MODEL_CALLS'] == '1'
          ? null
          : 'set HERMES_DEV_MODEL_CALLS=1 to make real model calls');

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

  test('skills load with their source, read, and switch off and on', () async {
    final repository = HermesSkillsRepository(client.raw);
    final skills = await repository.list();
    expect(skills, isNotEmpty);
    expect(skills.every((s) => s.name.isNotEmpty), isTrue);

    final skill = skills.first;
    expect(await repository.content(skill.name), isNotEmpty);

    await repository.setEnabled(skill.name, !skill.enabled);
    try {
      final flipped = (await repository.list()).firstWhere(
        (s) => s.name == skill.name,
      );
      expect(flipped.enabled, !skill.enabled);
    } finally {
      await repository.setEnabled(skill.name, skill.enabled);
    }
  }, skip: skip);

  test('messaging platforms load as bots', () async {
    final bots = await HermesBotsRepository(client.raw).load();

    expect(bots, isNotEmpty);
    expect(bots.every((b) => b.name.isNotEmpty), isTrue);
  }, skip: skip);

  group('plugins', () {
    late HermesPluginManagerRepository repository;

    setUp(() => repository = HermesPluginManagerRepository(client.raw));

    Future<InstalledPlugin?> bundledPlugin() async =>
        (await repository.load()).where((p) => p.bundled).firstOrNull;

    test('the hub lists plugins with the fields the app reads', () async {
      final plugins = await repository.load();

      expect(plugins, isNotEmpty);
      expect(plugins.every((p) => p.name.isNotEmpty), isTrue);
      expect(plugins.any((p) => p.bundled), isTrue);
      expect(
        plugins.where((p) => p.bundled).every((p) => !p.canRemove),
        isTrue,
      );
    }, skip: skip);

    test(
      'a bundled plugin can be turned off and on, and the hub follows',
      () async {
        final plugin = await bundledPlugin();
        if (plugin == null) return;
        final wasEnabled = plugin.status == PluginStatus.enabled;
        addTearDown(() => repository.setEnabled(plugin.name, wasEnabled));

        final changed = await repository.setEnabled(plugin.name, !wasEnabled);
        final after = (await repository.load()).singleWhere(
          (p) => p.name == plugin.name,
        );

        expect(changed.ok, isTrue);
        expect(
          after.status,
          wasEnabled ? PluginStatus.disabled : PluginStatus.enabled,
        );
      },
      skip: skip,
    );

    test('hiding a plugin shows in user_hidden and can be undone', () async {
      final plugin = await bundledPlugin();
      if (plugin == null) return;
      addTearDown(() => repository.setHidden(plugin.name, plugin.hidden));

      final hidden = await repository.setHidden(plugin.name, !plugin.hidden);
      final after = (await repository.load()).singleWhere(
        (p) => p.name == plugin.name,
      );

      expect(hidden.ok, isTrue);
      expect(after.hidden, !plugin.hidden);
    }, skip: skip);

    test('an unknown plugin is refused with a reason', () async {
      final result = await repository.setEnabled('no-such-plugin-here', true);

      expect(result.ok, isFalse);
      expect(result.message, isNotEmpty);
    }, skip: skip);

    test(
      'a nested plugin name reaches its route as one encoded segment',
      () async {
        final result = await repository.setEnabled('no/such/plugin', true);

        expect(result.ok, isFalse);
        expect(result.message, contains('not installed'));
      },
      skip: skip,
    );
  });

  test('the gateway accepts the server-request capability and lists what it '
      'may ask', () async {
    final rpc = GatewayRpcClient(
      await hermesGatewayConnect(
        baseUrl: url!,
        authRequired: false,
        api: client,
      )(),
    );
    addTearDown(rpc.close);

    final result = await rpc.request('client.capabilities', {
      'server_requests': true,
    });

    expect(
      (result['server_requests'] as List).cast<String>(),
      containsAll(['approval', 'clarify', 'sudo', 'secret']),
    );
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
    skip: modelSkip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the gateway creates and resumes sessions in the profile it is given',
    () async {
      final profiles = HermesProfilesRepository(client.raw);
      final active = (await profiles.loadActive()).active;
      final transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        ),
      );
      addTearDown(transport.close);

      final first = await transport
          .send(profile: active, text: 'Reply with the single word: pong.')
          .toList();
      final bound = first.first as ThreadBound;
      expect((first.last as ReplyCompleted).failed, isFalse);

      final listed = await HermesChatRepository(client.raw)
          .loadThreads(profile: active);
      expect(listed.map((t) => t.id), contains(bound.threadId));

      final second = await transport
          .send(threadId: bound.threadId, profile: active, text: 'Say: ping')
          .toList();
      expect((second.last as ReplyCompleted).failed, isFalse);
    },
    skip: modelSkip,
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

  group('kanban', () {
    const title = 'contract test task';

    Future<KanbanTask?> findTask(KanbanRepository repository) async {
      final board = await repository.loadBoard();
      return [for (final c in board.columns) ...c.tasks]
          .where((t) => t.title == title)
          .firstOrNull;
    }

    Future<void> cleanUp(KanbanRepository repository) async {
      final task = await findTask(repository);
      if (task != null) await repository.deleteTask(task.id);
    }

    test('the bundled plugin is reported as on', () async {
      expect(
        await HermesPluginsRepository(client.raw).isKanbanEnabled(),
        isTrue,
      );
    }, skip: skip);

    test('the board and the board list parse', () async {
      final repository = KanbanRepository(client);

      final board = await repository.loadBoard();
      final boards = await repository.listBoards();

      expect(board.columns.map((c) => c.name), containsAll(kanbanStatuses));
      expect(boards, isNotEmpty);
      expect(boards.any((b) => b.isCurrent), isTrue);
    }, skip: skip);

    test('a task can be created, changed, commented on and deleted', () async {
      final repository = KanbanRepository(client);
      await cleanUp(repository);
      addTearDown(() => cleanUp(repository));

      await repository.createTask(title: title, body: 'from the app');
      final created = await findTask(repository);
      expect(created, isNotNull);

      await repository.addComment(created!.id, 'hello');
      await repository.updateTask(
        created.id,
        status: 'blocked',
        blockReason: 'waiting',
      );
      final detail = await repository.loadTask(created.id);

      expect(detail.task.title, title);
      expect(detail.task.body, 'from the app');
      expect(detail.task.status, 'blocked');
      expect(detail.comments.map((c) => c.body), contains('hello'));
      expect(detail.events, isNotEmpty);

      await repository.deleteTask(created.id);
      expect(await findTask(repository), isNull);
    }, skip: skip);

    test(
      'an attachment can be uploaded, downloaded byte for byte and removed',
      () async {
        final repository = KanbanRepository(client);
        await cleanUp(repository);
        addTearDown(() => cleanUp(repository));
        await repository.createTask(title: title);
        final task = (await findTask(repository))!;
        final bytes = Uint8List.fromList([0, 255, 128, 10, 13, 200, 1, 2]);

        await repository.uploadAttachment(task.id, 'contract.bin', bytes);
        final attached = (await repository.loadTask(task.id)).attachments;
        final downloaded = await repository.downloadAttachment(
          attached.single.id,
        );
        await repository.removeAttachment(attached.single.id);

        expect(attached.single.filename, 'contract.bin');
        expect(attached.single.size, bytes.length);
        expect(downloaded, bytes);
        expect((await repository.loadTask(task.id)).attachments, isEmpty);
      },
      skip: skip,
    );

    test('a refused change carries the plugin\'s reason', () async {
      final repository = KanbanRepository(client);

      expect(
        repository.updateTask('t_missing', status: 'running'),
        throwsA(isA<KanbanException>()),
      );
    }, skip: skip);

    test('the orchestration settings parse', () async {
      final settings = await KanbanRepository(client).loadOrchestration();

      expect(settings.activeProfile, isNotEmpty);
    }, skip: skip);

    test('the event stream announces a new task', () async {
      final repository = KanbanRepository(client);
      await cleanUp(repository);
      addTearDown(() => cleanUp(repository));
      final since = (await repository.loadBoard()).latestEventId;
      final channel = await hermesSocketConnect(
        baseUrl: url!,
        authRequired: false,
        api: client,
        path: '/api/plugins/kanban/events',
      )({'since': '$since'});

      final frame = channel.stream.first.timeout(const Duration(seconds: 15));
      await repository.createTask(title: title);
      final data = jsonDecode(await frame) as Map;
      await channel.sink.close();

      expect(data['events'], isNotEmpty);
      expect(data['cursor'], greaterThan(since));
    }, skip: skip);
  });
}
