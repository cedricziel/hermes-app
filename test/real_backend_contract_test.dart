import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart'
    show
        CronJobCreate,
        CustomEndpointUpdate,
        EnvVarUpdate,
        MCPCatalogInstall,
        MCPServerCreate,
        MoaConfigPayload,
        ProfileCreate,
        RawConfigUpdate,
        SessionRename,
        TTSSpeakRequest;
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_proposal_session.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/memory_proposals_repository.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/hermes_files_repository.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/provider_settings.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/providers/provider_results.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/server_care/action_status.dart';
import 'package:hermes_app/src/server_care/care_result.dart';
import 'package:hermes_app/src/server_care/doctor_report.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/telemetry/hermes_server_attributes.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/voice/synthesized_speech.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:hermes_app/src/voice/wav.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';

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
/// The model provider tests only read the five list routes and call both
/// validate routes with an empty value; they save no key, start no sign-in and
/// remove nothing.
/// The media tests write throwaway files under the backend's `images` folder
/// and the system temp directory, so they need a backend on this machine, and
/// delete them after. The scripted-model tests create a throwaway profile
/// named `contract-check-…` (Hermes also writes its `~/.local/bin` wrapper)
/// whose model is a scripted one this test serves on the loopback interface,
/// so their turns cost nothing; the agent runs `rm -rf` on a folder the test
/// made in the system temp directory, and the profile is deleted after. Hermes
/// keeps the deleted profile's state open, so a second run against the same
/// backend fails ("Named profile home does not exist") until it restarts.
/// The server files tests only read: they list, read and download files in
/// the folder the dashboard runs in, and write nothing on the backend.
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

  test('the status carries the fields telemetry describes the server '
      'with', () async {
    final status = (await Dio().get<Map<String, dynamic>>('$url/api/status'))
        .data!;

    expect(status['version'], isA<String>());
    expect(status['config_version'], isA<int>());
    expect(status['auth_required'], isA<bool>());
    expect(status['auth_providers'], everyElement(isA<String>()));
    expect(status['gateway_mode'], isA<String>());
    expect(status['profiles'], everyElement(isA<String>()));
    expect(status['gateway_state'], anyOf(isNull, isA<String>()));
    expect(status['overall'], anyOf('ok', 'degraded'));
    if (status.containsKey('install_id')) {
      expect(status['install_id'], isA<String>());
    }
    expect(
      hermesServerAttributes(status).keys,
      containsAll([
        'hermes.version',
        'hermes.config_version',
        'hermes.auth.required',
        'hermes.gateway.mode',
        'hermes.overall',
      ]),
    );
  }, skip: skip);

  group('server care', () {
    // Read-only: no update, restart or start is ever called here. The doctor
    // check does not modify anything (the route never passes --fix).
    late ServerCareRepository care;
    setUp(() => care = ServerCareRepository(client));

    T value<T>(CareResult<T> r) {
      expect(r, isA<CareOk<T>>(), reason: 'the route answered: $r');
      return (r as CareOk<T>).value;
    }

    test('status carries the fields the headline reads', () async {
      final status = value(await care.status(profile: 'default'));
      expect(status.version, isNotNull);
      expect(status.profiles, isNotEmpty);
      // Null until a gateway has run on this backend.
      expect(status.gatewayStateRaw, anyOf(isNull, isA<String>()));
    });

    test('health answers ok with a commit', () async {
      final health = value(await care.health());
      expect(health.version, isNotNull);
      expect(health.commit, anyOf(isNull, isA<String>()));
    });

    test('the update check answers, not forced', () async {
      final check = value(await care.checkUpdate());
      expect(check.installMethodRaw, isNotNull);
      expect(check.behind, anyOf(isNull, isA<int>()));
    });

    test('each log file answers lines', () async {
      for (final file in CareLogFile.values) {
        final lines = value(await care.logs(profile: 'default', file: file));
        expect(lines, isA<List<Object>>(), reason: file.name);
      }
    });

    test('usage for 7 days has one row per day', () async {
      final report = value(
        await care.usage(profile: 'default', days: 7, today: DateTime.now()),
      );
      expect(report.days, hasLength(7));
    });

    test('a doctor run is followed to its end', () async {
      value(await care.startDoctor(profile: 'default'));
      ActionStatus? done;
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (DateTime.now().isBefore(deadline)) {
        final status = value(await care.actionStatus(CareAction.doctor));
        if (!status.running && status.lines.isNotEmpty) {
          done = status;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(done, isNotNull, reason: 'the doctor run finished');
      final report = DoctorReport.parse(done!.lines);
      expect(report.sections.isNotEmpty || report.allPassed, isTrue);
    });
  }, skip: skip);

  group('voice', () {
    test('voice-config describes both directions', () async {
      final response = await client.raw
          .getClientVoiceConfigApiAudioVoiceConfigGet();
      final body = response.data! as Map;

      for (final key in ['stt', 'tts']) {
        final section = body[key] as Map;
        expect(section['mode'], anyOf('relay', 'direct'), reason: key);
        if (section['mode'] == 'relay') {
          expect(section['reason'], isA<String>(), reason: key);
        }
      }
      final stt = body['stt'] as Map;
      if (stt.containsKey('streaming')) {
        expect(stt['streaming'], isA<bool>());
      }
    }, skip: skip);

    test(
      'speak answers a data URL of audio, or fails without a provider',
      () async {
        final config = await client.raw
            .getClientVoiceConfigApiAudioVoiceConfigGet();
        final usable = VoiceSupport.fromJson(config.data).textToSpeech;
        try {
          final response = await client.raw.speakTextApiAudioSpeakPost(
            tTSSpeakRequest: TTSSpeakRequest(text: 'Hello.'),
          );
          final body = response.data! as Map;
          if (body['ok'] == true) {
            // The shape Read aloud and voice calls decode.
            final speech = SynthesizedSpeech.fromJson(body);
            expect(speech.mimeType, startsWith('audio/'));
            expect(speech.bytes, isNotEmpty);
          } else {
            expect(usable, isFalse, reason: 'voice-config said it can speak');
          }
        } on DioException catch (error) {
          expect(error.response?.statusCode, greaterThanOrEqualTo(400));
          if (usable) markTestSkipped('the TTS provider failed: $error');
        }
      },
      skip: skip,
    );

    test('a speech-to-text lease is taken and released', () async {
      final repository = HermesChatRepository(client.raw);

      try {
        await repository.holdSpeechToText(
          'app:voice-input:contract',
          active: true,
        );
      } on DioException catch (error) {
        // The route came in Hermes v0.21.6; the app ignores its absence.
        if (const {404, 405}.contains(error.response?.statusCode)) {
          markTestSkipped('stt-lease is not on this Hermes');
          return;
        }
        rethrow;
      }
      await repository.holdSpeechToText(
        'app:voice-input:contract',
        active: false,
      );
    }, skip: skip);

    test('a second of silence transcribes to nothing, or fails without a '
        'speech-to-text provider', () async {
      final silence = wavFromPcm16(Uint8List(32000), sampleRate: 16000);
      try {
        final text = await HermesChatRepository(client.raw)
            .transcribe(silence, mimeType: 'audio/wav');
        expect(text, isEmpty);
      } on DioException catch (error) {
        expect(error.response?.statusCode, anyOf(400, 500));
      }
    }, skip: skip);

    test(
      'transcribe-stream answers eos with a final or an error frame',
      () async {
        final config =
            (await client.raw.getClientVoiceConfigApiAudioVoiceConfigGet())
                    .data!
                as Map;
        // The socket came in Hermes v0.21.6, together with `stt.streaming`.
        if (!(config['stt'] as Map).containsKey('streaming')) {
          markTestSkipped('transcribe-stream is not on this Hermes');
          return;
        }
        final connect = hermesMixedSocketConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
          path: '/api/audio/transcribe-stream',
        );
        final channel = await connect();
        channel.sink
          ..add(jsonEncode({'sample_rate': 16000}))
          ..add(Uint8List(3200))
          ..add(jsonEncode({'eos': true}));

        final frame = await channel.stream
            .where((f) => f is String)
            .map((f) => jsonDecode(f! as String) as Map)
            .firstWhere((f) => f['type'] != 'partial')
            .timeout(const Duration(seconds: 60));
        await channel.sink.close();

        expect(frame['type'], anyOf('final', 'error'));
        if (frame['type'] == 'final') {
          expect(frame['transcript'], isA<String>());
        } else {
          expect(frame['message'], isA<String>());
        }
      },
      skip: skip,
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

  test('a session is found by its id through the search', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;
    final id = threads.first.id;

    final response = await client.raw.searchSessionsApiSessionsSearchGet(q: id);
    final hits = await repository.searchThreads(id);

    expect(
      response.data,
      isA<Map>().having((b) => b['results'], 'results', isA<List>()),
    );
    final rows = (response.data! as Map)['results'] as List;
    expect(rows, everyElement(containsPair('session_id', isA<String>())));
    expect(hits, isNotEmpty);
    expect(hits.length, rows.length);
    expect(hits.every((h) => h.id.isNotEmpty && h.title.isNotEmpty), isTrue);
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

  test('a profile takes its own default model back', () async {
    final profile = (await HermesProfilesRepository(
      client.raw,
    ).loadActive()).active;
    final current = (await HermesModelsRepository(
      client.raw,
    ).load(profile: profile)).current;
    if (current == null) {
      markTestSkipped('the dev backend has no default model');
      return;
    }

    final warning = await HermesModelsRepository(client.raw)
        .assignMain(current, profile: profile);

    expect(warning, isNull);
    final after = (await HermesModelsRepository(
      client.raw,
    ).load(profile: profile)).current;
    expect(after, current);
  }, skip: skip);

  test('the app hint is saved per profile without touching the rest', () async {
    final hints = PlatformHintRepository(client.raw);
    final profiles = await HermesProfilesRepository(client.raw).list();
    expect(profiles, isNotEmpty);
    final profile = profiles.last.name;
    Future<Map<dynamic, dynamic>> saved() async =>
        (await client.raw.getConfigApiConfigGet(
              profile: profile,
              includeDefaults: false,
            )).data!
            as Map;
    final before = await saved();

    expect(await hints.state(profile), isNotNull);
    await hints.write(profile);

    expect(await hints.state(profile), PlatformHintState.current);
    final after = await saved();
    for (final key in before.keys.where((k) => k != 'platform_hints')) {
      expect(after[key], before[key], reason: '$key');
    }
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
    final bots = await HermesMessagingRepository(client.raw).load();

    expect(bots, isNotEmpty);
    expect(bots.every((b) => b.name.isNotEmpty), isTrue);
  }, skip: skip);

  group('model providers (read only)', () {
    // Reads the five list routes and calls both validate routes with an empty
    // value, so nothing reaches a provider or an endpoint. No key is saved,
    // no sign-in started and nothing removed here.
    Map<String, dynamic> object(Object? body, String route) {
      expect(body, isA<Map<String, dynamic>>(), reason: route);
      return body! as Map<String, dynamic>;
    }

    test(
      'model options with the unconfigured rows carry the provider fields',
      () async {
        final body = object(
          (await client.raw.getModelOptionsApiModelOptionsGet(
            profile: 'default',
            includeUnconfigured: true,
          )).data,
          'options',
        );
        expect(body['model'], anyOf(isNull, isA<String>()));
        expect(body['provider'], anyOf(isNull, isA<String>()));
        final rows = (body['providers']! as List).cast<Map<String, dynamic>>();
        expect(rows, isNotEmpty);
        for (final row in rows) {
          expect(row['slug'], isA<String>());
          expect(row['name'], anyOf(isNull, isA<String>()));
          expect(row['authenticated'], anyOf(isNull, isA<bool>()));
          expect(row['is_current'], anyOf(isNull, isA<bool>()));
          expect(row['models'], anyOf(isNull, isA<List<dynamic>>()));
          if (row['authenticated'] == false) {
            expect(row['auth_type'], anyOf(isNull, isA<String>()));
            expect(row['key_env'], anyOf(isNull, isA<String>()));
          }
        }
      },
    );

    test('env variables carry the provider key fields', () async {
      final body = object(
        (await client.raw.getEnvVarsApiEnvGet(profile: 'default')).data,
        'env',
      );
      final providerKeys = body.values.cast<Map<String, dynamic>>().where(
        (row) => row['category'] == 'provider',
      );
      expect(providerKeys, isNotEmpty);
      for (final row in providerKeys) {
        expect(row['provider'], isA<String>());
        expect(row['is_set'], isA<bool>());
        expect(row['is_password'], isA<bool>());
        expect(row['provider_primary'], anyOf(isNull, isA<bool>()));
        expect(row['url'], anyOf(isNull, isA<String>()));
        expect(row['redacted_value'], anyOf(isNull, isA<String>()));
      }
    });

    test('OAuth providers carry their flow and status', () async {
      final body = object(
        (await client.raw.listOauthProvidersApiProvidersOauthGet(
          profile: 'default',
        )).data,
        'oauth',
      );
      final rows = (body['providers']! as List).cast<Map<String, dynamic>>();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row['id'], isA<String>());
        expect(row['flow'], anyOf('device_code', 'external'));
        expect(row['disconnectable'], isA<bool>());
        expect((row['status']! as Map)['logged_in'], isA<bool>());
      }
    });

    test('custom endpoints carry the endpoint fields', () async {
      final body = object(
        (await client.raw.listCustomEndpointsApiProvidersCustomEndpointsGet(
          profile: 'default',
        )).data,
        'endpoints',
      );
      for (final row
          in (body['endpoints']! as List).cast<Map<String, dynamic>>()) {
        expect(row['id'], isA<String>());
        expect(row['base_url'], isA<String>());
        expect(row['has_api_key'], isA<bool>());
        expect(row['is_current'], anyOf(isNull, isA<bool>()));
      }
    });

    test('the credential pool carries source and auth type', () async {
      final body = object(
        (await client.raw.listCredentialPoolApiCredentialsPoolGet(
          profile: 'default',
        )).data,
        'pool',
      );
      for (final group
          in (body['providers']! as List).cast<Map<String, dynamic>>()) {
        expect(group['provider'], isA<String>());
        for (final entry
            in (group['entries']! as List).cast<Map<String, dynamic>>()) {
          expect(entry['source'], anyOf(isNull, isA<String>()));
          expect(entry['auth_type'], anyOf(isNull, isA<String>()));
        }
      }
    });

    test('the five routes load and merge without a skipped row', () async {
      final snapshot = await ProvidersRepository(client.raw).load('default');
      expect(snapshot, isA<ProvidersLoaded>());
      final loaded = snapshot as ProvidersLoaded;
      for (final source in ProviderSource.values) {
        expect(loaded.state(source), isA<SourceOk>(), reason: source.name);
      }
      expect(loaded.catalog.skippedRows, 0);
      expect(loaded.catalog.entries, isNotEmpty);
    });

    test('the provider key check answers its three fields, or refuses an '
        'empty value', () async {
      final response = await client.raw
          .validateProviderCredentialApiProvidersValidatePost(
            envVarUpdate: EnvVarUpdate(key: 'OPENROUTER_API_KEY', value: ''),
            validateStatus: (_) => true,
          );
      if (response.statusCode == 200) {
        final body = object(response.data, 'validate');
        expect(body['ok'], isA<bool>());
        expect(body['reachable'], isA<bool>());
        expect(body['message'], anyOf(isNull, isA<String>()));
      } else {
        expect(response.statusCode, lessThan(500));
      }
    });

    test('the endpoint check answers its fields, or refuses an empty '
        'address', () async {
      final response = await client.raw
          .validateCustomEndpointApiProvidersCustomEndpointsValidatePost(
            customEndpointUpdate: CustomEndpointUpdate(
              name: '',
              baseUrl: '',
              model: '',
            ),
            validateStatus: (_) => true,
          );
      if (response.statusCode == 200) {
        final body = object(response.data, 'endpoint validate');
        expect(body['ok'], isA<bool>());
        expect(body['reachable'], isA<bool>());
        expect(body['models'], anyOf(isNull, isA<List<dynamic>>()));
        expect(body['resolved_base_url'], anyOf(isNull, isA<String>()));
      } else {
        expect(response.statusCode, lessThan(500));
      }
    });
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
        final hub =
            (await client.raw.getPluginsHubApiDashboardPluginsHubGet()).data
                as Map<String, dynamic>;
        final providers = hub['providers'] as Map<String, dynamic>;
        final options = (providers['memory_options'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          {
            for (final option in settings.memoryOptions)
              option.name: option.status,
          },
          {
            for (final option in options)
              option['name'] as String: switch (option['status']) {
                'ready' => ProviderStatus.ready,
                'needs_config' => ProviderStatus.needsSetup,
                _ => ProviderStatus.unavailable,
              },
          },
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

  group('the Bot Screen over the gateway (no model call)', () {
    late GatewayRpcClient rpc;
    late BotScreenRepository screen;

    setUp(() async {
      rpc = GatewayRpcClient(
        await hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        )(),
      );
      addTearDown(rpc.close);
      screen = BotScreenRepository(rpc.requestWithin);
    });

    // A macOS backend reports `supported: false` and never shows a screen;
    // set HERMES_DEV_BOT_SCREEN=1 against a Linux backend whose default
    // profile has a started screen (the verify-bot-screen skill) to check
    // the running shapes too.
    final running = Platform.environment['HERMES_DEV_BOT_SCREEN'] == '1';

    test('display.status for the default profile has the shape the app '
        'relies on', () async {
      final raw = await rpc.request('display.status', {'profile': 'default'});

      expect(raw['supported'], isA<bool>());
      expect(raw['installed'], isA<bool>());
      expect(raw['missing'], isA<List<Object?>>());
      expect(raw['running'], isA<bool>());
      expect(raw['geometry'], isA<String>());
      expect(raw['profile_key'], isA<String>());
      expect(raw['lease'], containsPair('holder', isIn(['agent', 'human'])));
      expect(raw['lease'], containsPair('epoch', isA<int>()));

      final status = switch (await screen.status('default')) {
        BotScreenOk(:final value) => value,
        final other => fail('expected a status, got $other'),
      };
      if (running) {
        expect(status.supported, isTrue);
        expect(status.running, isTrue);
      } else if (!status.supported) {
        expect(status.running, isFalse);
      }
    }, skip: skip);

    test('display.thumbnail for the default profile is a JPEG, or says why '
        'there is none', () async {
      final raw = await rpc.request('display.thumbnail', {
        'profile': 'default',
      });
      final frame = switch (await screen.thumbnail('default')) {
        BotScreenOk(:final value) => value,
        final other => fail('expected a frame result, got $other'),
      };

      expect(raw, contains('data_url'));
      switch (frame) {
        case BotScreenJpeg(:final bytes):
          expect(bytes.take(2), [0xff, 0xd8]);
        case BotScreenSuppressed() || BotScreenStopped():
          expect(running, isFalse);
      }
    }, skip: skip);
  });

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

  // The request bodies below were written from the design (read from the
  // Hermes source), not recorded from a live backend: no `hermes` binary was
  // available when they were written. Run them against a throwaway backend
  // and fix the shapes the first run corrects. They write only to a folder
  // they create in the system temp directory and to chats they create, which
  // the backend keeps until its home is thrown away. Set
  // `HERMES_DEV_FILES_ROOT` to the folder the backend was started with via
  // `HERMES_DASHBOARD_FILES_ROOT` to check the read boundary too.
  group('working directory (no model call)', () {
    late GatewayRpcClient rpc;
    late HermesWorkspacesRepository workspaces;
    late Directory root;
    late String inner;
    final filesRoot = Platform.environment['HERMES_DEV_FILES_ROOT'];

    Map<String, Object?> infoOf(Map<String, Object?> created) =>
        (created['info'] as Map).cast<String, Object?>();

    Future<Map<String, Object?>> create(Map<String, Object?> extra) async {
      final created = await rpc.request('session.create', {
        'profile': 'default',
        'source': 'hermes_app',
        ...extra,
      });
      addTearDown(
        () => rpc
            .request('session.close', {'session_id': created['session_id']})
            .then((_) {}, onError: (Object _) {}),
      );
      return created;
    }

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
      workspaces = HermesWorkspacesRepository(client.raw, rpc.requestWithin);
      // Under the files root when one is set, so fs/list is not refused for
      // the folders these tests create. The server reports resolved paths,
      // so expectations use the resolved ones too (a temp dir can be a
      // symlink, as on macOS).
      final parent = filesRoot == null
          ? Directory.systemTemp
          : Directory(filesRoot);
      final made = await parent.createTemp('hermes-workdir-');
      addTearDown(() => made.delete(recursive: true));
      root = Directory(made.resolveSymbolicLinksSync());
      inner = (await Directory('${root.path}/inner').create()).path;
      await File('${root.path}/note.txt').writeAsString('x');
    });

    T value<T>(WorkspacesResult<T> result) => switch (result) {
      WorkspacesOk(:final value) => value,
      _ => fail('expected a value, got $result'),
    };

    void failedWith<T>(WorkspacesResult<T> result, WorkspacesFailure kind) =>
        expect(
          result,
          isA<WorkspacesFailed<T>>().having((f) => f.kind, 'kind', kind),
        );

    test('the workspaces catalog has the fields the app reads', () async {
      final raw = (await client.raw.getChatWorkspacesApiChatWorkspacesGet(
        profile: 'default',
      )).data!;
      final body = (raw as Map).cast<String, Object?>();
      expect(body['projects'], isA<List<Object?>>());
      expect(body['repos'], isA<List<Object?>>());
      expect(body['default_cwd'], anyOf(isNull, isA<String>()));
      expect(body['home'], anyOf(isNull, isA<String>()));
      expect(body['scan_enabled'], isA<bool>());

      value(await workspaces.catalog(profile: 'default'));
      failedWith(
        await workspaces.catalog(profile: 'contract-check-missing'),
        WorkspacesFailure.unknownProfile,
      );
    }, skip: skip);

    test('fs/list lists the folders of a temp directory and reports a bad '
        'one in a 200 with error', () async {
      final listing = value(await workspaces.listFolders(root.path));
      expect(listing.folders.map((f) => f.name), ['inner']);

      final raw = (await client.raw.fsListApiFsListGet(
        path: '${root.path}/missing',
        profile: 'default',
      )).data!;
      expect((raw as Map)['error'], 'ENOENT');
      failedWith(
        await workspaces.listFolders('${root.path}/missing'),
        WorkspacesFailure.notFound,
      );
      failedWith(
        await workspaces.listFolders('${root.path}/note.txt'),
        WorkspacesFailure.notADirectory,
      );
    }, skip: skip);

    test('complete.path with an absolute word lists folders', () async {
      final got = value(await workspaces.complete('${root.path}/in'));
      expect(got.folders.map((s) => s.text), ['${root.path}/inner/']);
    }, skip: skip);

    test('a chat created with cwd and cwd_explicit runs there, and a bad cwd '
        'falls back', () async {
      final created = await create({'cwd': root.path, 'cwd_explicit': true});
      expect(infoOf(created)['cwd'], root.resolveSymbolicLinksSync());

      final bad = '${root.path}/does-not-exist';
      final fell = await create({'cwd': bad, 'cwd_explicit': true});
      expect(infoOf(fell)['cwd'], isNot(bad));
    }, skip: skip);

    test('a draft chat can be moved, a relative path is refused, and it has '
        'no stored row yet', () async {
      final created = await create({'cwd': root.path, 'cwd_explicit': true});
      final stored = created['stored_session_id'] as String;

      expect(value(await workspaces.moveWorkspace(stored, inner)).cwd, inner);
      // A draft has no stored row until its first message (the server moves
      // it live: "A draft has no row yet; the live re-home still applies"),
      // so the stored chat reads as gone, not as a chat in the new folder.
      failedWith(
        await workspaces.sessionFolder(stored),
        WorkspacesFailure.sessionGone,
      );

      // Not through the repository, which would refuse it without asking.
      await expectLater(
        rpc.request('session.workspace.move', {
          'session_key': stored,
          'cwd': 'inner',
          'profile': 'default',
        }),
        throwsA(isA<GatewayRpcException>()),
      );
      failedWith(
        await workspaces.moveWorkspace(stored, '${root.path}/missing'),
        WorkspacesFailure.notFound,
      );
    }, skip: skip);

    test('a hermes_app chat created with no cwd stores the folder it '
        'reports', () async {
      final created = await create({});
      final reported = infoOf(created)['cwd'];
      expect(reported, anyOf(isNull, isA<String>()));
      final folder = await workspaces.sessionFolder(
        created['stored_session_id'] as String,
      );
      if (reported is String && folder is WorkspacesOk<SessionFolder>) {
        expect(folder.value.cwd, reported);
      }
    }, skip: skip);

    test('with the files root set, outside answers 403 with the boundary '
        'detail and inside lists', () async {
      final base = filesRoot!;
      final outside = Directory(base).parent.path;
      try {
        await client.raw.fsListApiFsListGet(path: outside, profile: 'default');
        fail('expected a 403 outside the files root');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 403);
        final detail = (e.response?.data as Map)['detail'] as String;
        expect(
          detail.toLowerCase(),
          contains('path is outside the managed read boundary'),
        );
      }
      value(await workspaces.listFolders(base));
      failedWith(
        await workspaces.listFolders(outside),
        WorkspacesFailure.outsideBoundary,
      );
    }, skip: skip ?? (filesRoot == null ? 'set HERMES_DEV_FILES_ROOT' : null));
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

    test('subagent.list answers rows the app parses, for a session with none '
        '(read-only: nothing is stopped or steered)', () async {
      final answer = await rpc.request('subagent.list', {
        'session_id': sessionId,
      });
      final list = parseAgentList(answer);
      expect(list, isNotNull);
      expect(list!.agents, isEmpty);
      expect(list.delegations, isEmpty);
      // A runtime id this connection does not hold is refused, not listed.
      await expectLater(
        rpc.request('subagent.list', {'session_id': 'not-a-session'}),
        throwsA(isA<GatewayRpcException>().having((e) => e.code, 'code', 4001)),
      );
    }, skip: skip);

    test(
      'process.list answers rows the app parses, for a session with none '
      '(read-only: nothing is killed, and process.stop is never sent)',
      () async {
        // `process.list` waits for the session's agent; 5032 says it is still
        // starting, which the app reads as a quiet failed read.
        Map<String, Object?>? answer;
        try {
          answer = await rpc.request('process.list', {'session_id': sessionId});
        } on GatewayRpcException catch (error) {
          expect(error.code, 5032);
        }
        if (answer != null) {
          final list = parseProcessList(answer);
          expect(list, isNotNull);
          expect(list!.processes, isEmpty);
        }
        await expectLater(
          rpc.request('process.list', {'session_id': 'not-a-session'}),
          throwsA(
            isA<GatewayRpcException>().having((e) => e.code, 'code', 4001),
          ),
        );
      },
      skip: skip,
    );

    const liveStatuses = {
      'idle',
      'starting',
      'waiting',
      'working',
      'streaming',
      'resuming',
    };

    for (final params in [
      const <String, Object?>{},
      const <String, Object?>{'profile': 'default'},
    ]) {
      test('live sessions list as background refresh reads them '
          '(params: $params)', () async {
        final listed = await rpc.request('session.active_list', params);
        final rows = (listed['sessions'] as List).cast<Map<String, dynamic>>();
        for (final row in rows) {
          expect(row['id'], isA<String>());
          expect(row['session_key'], isA<String>());
          expect(row['title'], isA<String>());
          expect(row['last_active'], isA<num>());
          expect(liveStatuses, contains(row['status']));
        }
        expect(rows.map((row) => row['id']), contains(sessionId));
      }, skip: skip);
    }

    test('a session is listed from a fresh socket once the one that made it '
        'is gone, which is how a background run finds it', () async {
      final made = GatewayRpcClient(
        await hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        )(),
      );
      final created = await made.request('session.create', const {});
      final id = created['session_id'] as String;
      await made.close();

      final fresh = GatewayRpcClient(
        await hermesGatewayConnect(
          baseUrl: url,
          authRequired: false,
          api: client,
        )(),
      );
      addTearDown(fresh.close);
      final listed = await fresh.request('session.active_list', const {});

      final row = [
        for (final row in listed['sessions'] as List)
          if ((row as Map)['id'] == id) row.cast<String, Object?>(),
      ].singleOrNull;
      expect(row, isNotNull, reason: 'the session outlives its socket');
      if (created['stored_session_id'] case final String stored) {
        expect(row!['session_key'], stored);
      }
      expect(row!['status'], isIn(liveStatuses));
    }, skip: skip);

    test('approvals are asked by the runtime session id', () async {
      final Map<String, Object?> pending;
      try {
        pending = await rpc.request('approval.pending', {
          'session_id': sessionId,
          'profile': 'default',
        });
      } on GatewayRpcException catch (error) {
        // A backend with no provider cannot build the agent that holds them;
        // background refresh then reads the session as waiting on something.
        if (error.code == 5032) {
          markTestSkipped('needs a provider configured in the backend');
          return;
        }
        rethrow;
      }
      expect(pending['approvals'], isEmpty);
    }, skip: skip);

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
          // The real server reports where it started the chat (`info.cwd`),
          // so a WorkspaceBound may come before the refusal.
          emitsThrough(emitsError(isA<AttachmentException>())),
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

  group('the gateway stream the transport relies on (model calls)', () {
    const pong = 'Reply with the single word: pong. Use no tools.';
    const counting = 'Count from 1 to 40, one number per line. Use no tools.';

    Future<_GatewayTap> open() async {
      final tap = _GatewayTap(
        GatewayRpcClient(
          await hermesGatewayConnect(
            baseUrl: url!,
            authRequired: false,
            api: client,
          )(),
        ),
      );
      addTearDown(tap.close);
      return tap;
    }

    test(
      'a turn sends session.info running false after message.complete, and '
      'every event frame carries a rising seq',
      () async {
        final tap = await open();
        final session = await tap.rpc.request('session.create', {});
        final sid = session['session_id'] as String;

        final submit = await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': pong,
        });
        await tap.until(
          () => tap.idleAfterComplete(sid),
          'session.info {running: false} after message.complete',
        );

        expect(submit['status'], 'streaming');
        final types = tap.types(sid);
        expect(types, contains('message.complete'));
        expect(
          tap
              .eventsOf(sid)
              .lastIndexWhere(
                (e) =>
                    e.type == 'session.info' && e.payload['running'] == false,
              ),
          greaterThan(types.lastIndexOf('message.complete')),
        );
        final seqs = [for (final e in tap.eventsOf(sid)) e.seq];
        expect(seqs, everyElement(isA<int>()));
        expect(seqs, orderedEquals([...seqs]..sort()));
        expect(seqs.toSet(), hasLength(seqs.length));
      },
      skip: modelSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'a session lists under its stored id while it runs, and its finished '
      'reply is the newest stored message',
      () async {
        final tap = await open();
        final session = await tap.rpc.request('session.create', {});
        final sid = session['session_id'] as String;
        final stored = session['stored_session_id'] as String;
        await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': counting,
        });
        await tap.until(
          () => tap.types(sid).contains('message.start'),
          'message.start',
        );

        Future<Map<String, Object?>?> listed() async {
          final answer = await tap.rpc.request('session.active_list', {});
          return [
            for (final row in (answer['sessions'] as List))
              if ((row as Map)['id'] == sid) row.cast<String, Object?>(),
          ].firstOrNull;
        }

        final running = await listed();
        expect(running, isNotNull);
        expect(running!['session_key'], stored);
        expect(running['status'], isIn(['starting', 'working', 'streaming']));

        await tap.until(
          () => tap.idleAfterComplete(sid),
          'session.info {running: false} after message.complete',
        );

        // Background refresh announces a reply only when its session is listed
        // with its turn ended.
        final finished = await listed();
        expect(finished?['status'], 'idle');
        final page = await HermesChatRepository(client.raw)
            .loadMessagePage(stored, limit: 5);
        expect(page.messages.last.role, ChatRole.assistant);
        expect(page.messages.last.content.trim(), isNotEmpty);
      },
      skip: modelSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'session.events.since after a forced socket close returns the missed '
      'seqs',
      () async {
        final first = await open();
        final session = await first.rpc.request('session.create', {});
        final sid = session['session_id'] as String;
        final stored = session['stored_session_id'] as String;
        await first.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': counting,
        });
        await first.until(
          () => first.types(sid).contains('message.start'),
          'message.start',
        );
        final lastSeen = first.eventsOf(sid).last.seq!;
        // The socket, not the server: the turn goes on without a listener.
        await first.close();

        final second = await open();
        final resumed = await second.rpc.request('session.resume', {
          'session_id': stored,
        });
        expect(resumed['session_id'], sid);
        final since = await second.rpc.request('session.events.since', {
          'session_id': sid,
          'last_seen': lastSeen,
        });

        expect(since['truncated'], isNot(true));
        expect(since['epoch'], isA<String>());
        final replayed = [
          for (final event in since['events'] as List)
            (event as Map)['seq'] as int,
        ];
        expect(replayed, isNotEmpty);
        expect(replayed.first, lastSeen + 1);
        expect(replayed, [
          for (var i = 0; i < replayed.length; i++) lastSeen + 1 + i,
        ]);
        expect(since['latest_seq'], greaterThanOrEqualTo(replayed.last));
      },
      skip: modelSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'a queued prompt sent right after a completion is queued or started, '
      'never folded into the turn',
      () async {
        final tap = await open();
        final session = await tap.rpc.request('session.create', {});
        final sid = session['session_id'] as String;
        await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': pong,
        });
        await tap.until(
          () => tap.types(sid).contains('message.complete'),
          'message.complete',
        );

        final submit = await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': 'Reply with the single word: ping. Use no tools.',
          'queued': true,
        });
        expect(submit['status'], anyOf('queued', 'streaming'));
        await tap.until(
          () =>
              tap.types(sid).where((t) => t == 'message.complete').length >= 2,
          'the second message.complete',
        );
      },
      skip: modelSkip,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

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
    final repository = HermesMessagingRepository(client.raw);
    Future<HermesMessagingEnvVar> tokenVar() async => (await repository.load())
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
    final repository = HermesMessagingRepository(client.raw);

    await expectLater(
      repository.saveSetup('telegram', env: {'TELEGRAM_BOT_TOKEN': 'abc'}),
      throwsA(
        isA<MessagingSetupRejected>().having(
          (e) => e.message,
          'message',
          contains('bot token'),
        ),
      ),
    );
  }, skip: skip);

  test('an unknown Telegram pairing is reported as such', () async {
    final repository = HermesMessagingRepository(client.raw);

    await expectLater(
      repository.telegramPairingStatus('no-such-pairing'),
      throwsA(isA<MessagingSetupRejected>()),
    );
  }, skip: skip);

  test('Telegram user ids that are not numeric are refused before anything is '
      'saved', () async {
    final repository = HermesMessagingRepository(client.raw);

    await expectLater(
      repository.applyTelegramPairing('no-such-pairing', ['abc']),
      throwsA(
        isA<MessagingSetupRejected>().having(
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
      final repository = HermesMessagingRepository(client.raw);

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
    final bots = await HermesMessagingRepository(client.raw).load();

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

    test(
      'model options carry the fields the task model picker reads',
      () async {
        final raw =
            (await client.raw.modelOptionsApiPluginsKanbanModelOptionsGet())
                    .data!
                as Map<String, dynamic>;
        expect(raw['providers'], isA<List<dynamic>>());
        for (final row
            in (raw['providers'] as List).cast<Map<String, dynamic>>()) {
          expect(row['slug'], isA<String>());
          expect(row['label'], isA<String>());
          expect(row['models'], isA<List<dynamic>>());
        }

        final options = await KanbanRepository(client).loadModelOptions();
        expect(
          options.providers.length,
          (raw['providers'] as List).length,
          reason: 'the plugin lists only providers with models',
        );
      },
      skip: skip,
    );

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

    test('a task\'s model override is set, reported and cleared', () async {
      final repository = KanbanRepository(client);
      await cleanUp(repository);
      addTearDown(() => cleanUp(repository));

      // Triage keeps the dispatcher away, so the made-up model never runs.
      await repository.createTask(
        title: title,
        triage: true,
        model: const ModelChoice('contract', 'contract-model', effort: 'high'),
      );
      final id = (await findTask(repository))!.id;
      final set = (await repository.loadTask(id)).task;
      await repository.updateTask(id, clearModel: true);
      final modelCleared = (await repository.loadTask(id)).task;
      await repository.bulkUpdate([id], clearEffort: true);
      final cleared = (await repository.loadTask(id)).task;

      expect(set.modelOverride, 'contract-model');
      expect(set.providerOverride, 'contract');
      expect(set.reasoningEffort, 'high');
      expect(modelCleared.modelOverride, isNull);
      expect(modelCleared.providerOverride, isNull);
      expect(modelCleared.reasoningEffort, 'high');
      expect(cleared.reasoningEffort, isNull);
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

  group('staged memory and skill writes (no model call, local backend)', () {
    late Directory home;
    late HermesGatewayTransport transport;
    late MemoryProposalSession session;
    late MemoryProposalsRepository repository;
    late File memoryFile, userFile;
    String? memoryBefore, userBefore;
    final staged = <File>[];
    var counter = 0;

    setUpAll(() async {
      if (url == null) return;
      final status = (await Dio().get<Map<String, dynamic>>('$url/api/status'))
          .data!;
      home = Directory(status['hermes_home'] as String);
      transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url,
          authRequired: false,
          api: client,
        ),
      );
      session = MemoryProposalSession(transport);
      repository = MemoryProposalsRepository(session);
      memoryFile = File('${home.path}/memories/MEMORY.md');
      userFile = File('${home.path}/memories/USER.md');
    });

    tearDownAll(() async {
      if (url == null) return;
      await transport.close();
    });

    setUp(() {
      if (url == null) return;
      memoryFile.parent.createSync(recursive: true);
      memoryBefore = memoryFile.existsSync()
          ? memoryFile.readAsStringSync()
          : null;
      userBefore = userFile.existsSync() ? userFile.readAsStringSync() : null;
      memoryFile.writeAsStringSync(
        'Prefers tabs in Go\n§\nDeploys with deploy.sh',
      );
      userFile.writeAsStringSync('Likes tea, no sugar');
    });

    tearDown(() {
      if (url == null) return;
      for (final file in staged) {
        if (file.existsSync()) file.deleteSync();
      }
      staged.clear();
      void restore(File file, String? before) {
        if (before == null) {
          if (file.existsSync()) file.deleteSync();
        } else {
          file.writeAsStringSync(before);
        }
      }

      restore(memoryFile, memoryBefore);
      restore(userFile, userBefore);
    });

    /// Writes a pending record the way Hermes' `stage_write` does and returns
    /// its id.
    String stage(
      String subsystem,
      Map<String, Object?> payload, {
      required String summary,
      String origin = 'foreground',
    }) {
      final id =
          (0xa0000000 +
                  DateTime.now().microsecondsSinceEpoch % 0x5fffffff +
                  counter++)
              .toRadixString(16);
      final directory = Directory('${home.path}/pending/$subsystem')
        ..createSync(recursive: true);
      final file = File('${directory.path}/$id.json')
        ..writeAsStringSync(
          jsonEncode({
            'id': id,
            'subsystem': subsystem,
            'action': payload['action'],
            'summary': summary,
            'origin': origin,
            'created_at': DateTime.now().millisecondsSinceEpoch / 1000,
            'payload': payload,
          }),
        );
      staged.add(file);
      return id;
    }

    MemoryDecisions decisions() => MemoryDecisions(
      available: () => true,
      run: (command) => session.run('default', command),
      surface: 'inbox',
    );

    test('the pending list reads into proposals', () async {
      final add = stage('memory', {
        'action': 'add',
        'target': 'user',
        'content': 'Runs on a Mac',
      }, summary: 'add to user profile: Runs on a Mac');
      final replace = stage(
        'memory',
        {
          'action': 'replace',
          'target': 'memory',
          'content': 'Prefers spaces',
          'old_text': 'Prefers tabs',
          'matched_entry': 'Prefers tabs in Go',
        },
        summary:
            'replace in memory: entry matching: Prefers tabs\n'
            'whole entry becomes: Prefers spaces',
      );
      final patch = stage(
        'memory',
        {
          'action': 'patch',
          'target': 'memory',
          'content': 'ship.sh',
          'old_text': 'deploy.sh',
          'matched_entry': 'Deploys with deploy.sh',
        },
        summary: "background review consolidation (patch on memory): - patch span 'deploy.sh' -> 'ship.sh' (rest of the entry is kept)",
        origin: 'background_review',
      );
      final remove = stage(
        'memory',
        {
          'action': 'remove',
          'target': 'user',
          'old_text': 'Likes tea',
          'matched_entry': 'Likes tea, no sugar',
        },
        summary: 'background review consolidation (remove on user): - remove: Likes tea',
        origin: 'background_review',
      );

      final proposals = {
        for (final p in (await repository.load('default')).memory.proposals)
          p.id: p,
      };

      expect(proposals[add]!.action, ProposalAction.add);
      expect(proposals[add]!.target, MemoryTab.aboutYou);
      expect(proposals[add]!.newText, 'Runs on a Mac');
      expect(proposals[add]!.background, isFalse);
      expect(proposals[replace]!.action, ProposalAction.replace);
      expect(proposals[replace]!.replaced, ['Prefers tabs in Go']);
      expect(proposals[replace]!.newText, 'Prefers spaces');
      expect(proposals[patch]!.action, ProposalAction.replace);
      expect(proposals[patch]!.background, isTrue);
      expect(proposals[patch]!.replaced, ['Deploys with deploy.sh']);
      expect(proposals[patch]!.newText, 'ship.sh');
      expect(proposals[remove]!.action, ProposalAction.remove);
      expect(proposals[remove]!.target, MemoryTab.aboutYou);
      expect(proposals[remove]!.replaced, ['Likes tea, no sugar']);
      expect(proposals[remove]!.newText, isNull);
    }, skip: skip);

    test('approving a replace writes it and is read as saved', () async {
      final id = stage(
        'memory',
        {
          'action': 'replace',
          'target': 'memory',
          'content': 'Prefers spaces',
          'old_text': 'Prefers tabs',
          'matched_entry': 'Prefers tabs in Go',
        },
        summary:
            'replace in memory: entry matching: Prefers tabs\n'
            'whole entry becomes: Prefers spaces',
      );
      final inbox = decisions();
      addTearDown(inbox.dispose);

      await inbox.decide(id, approve: true);

      expect(inbox.stateOf(id).phase, MemoryDecisionPhase.saved);
      expect(memoryFile.readAsStringSync(), startsWith('Prefers spaces'));
      final listed = (await repository.load('default')).proposals;
      expect(listed.map((p) => p.id), isNot(contains(id)));
    }, skip: skip);

    test('approving a remove and an add is read as saved', () async {
      final remove = stage(
        'memory',
        {
          'action': 'remove',
          'target': 'user',
          'old_text': 'Likes tea',
          'matched_entry': 'Likes tea, no sugar',
        },
        summary: 'background review consolidation (remove on user): - remove: Likes tea',
        origin: 'background_review',
      );
      final add = stage('memory', {
        'action': 'add',
        'target': 'user',
        'content': 'Runs on a Mac',
      }, summary: 'add to user profile: Runs on a Mac');
      final inbox = decisions();
      addTearDown(inbox.dispose);

      await inbox.decide(remove, approve: true);
      await inbox.decide(add, approve: true);

      expect(inbox.stateOf(remove).phase, MemoryDecisionPhase.saved);
      expect(inbox.stateOf(add).phase, MemoryDecisionPhase.saved);
      expect(userFile.readAsStringSync(), 'Runs on a Mac');
    }, skip: skip);

    test(
      'an entry that changed since staging fails and stays pending',
      () async {
        final id = stage(
          'memory',
          {
            'action': 'replace',
            'target': 'memory',
            'content': 'Prefers spaces',
            'old_text': 'Prefers tabs',
            'matched_entry': 'Prefers tabs in Rust',
          },
          summary:
              'replace in memory: entry matching: Prefers tabs\n'
              'whole entry becomes: Prefers spaces',
        );
        final inbox = decisions();
        addTearDown(inbox.dispose);

        await inbox.decide(id, approve: true);

        expect(inbox.stateOf(id).phase, MemoryDecisionPhase.failed);
        expect(inbox.stateOf(id).text, startsWith('Entry changed'));
        expect(memoryFile.readAsStringSync(), startsWith('Prefers tabs in Go'));
        expect(
          (await repository.load('default')).proposals.map((p) => p.id),
          contains(id),
        );
      },
      skip: skip,
    );

    test('rejecting drops the record and leaves memory alone', () async {
      final id = stage('memory', {
        'action': 'add',
        'target': 'user',
        'content': 'Runs on a Mac',
      }, summary: 'add to user profile: Runs on a Mac');
      final inbox = decisions();
      addTearDown(inbox.dispose);

      await inbox.decide(id, approve: false);

      expect(inbox.stateOf(id).phase, MemoryDecisionPhase.rejected);
      expect(userFile.readAsStringSync(), 'Likes tea, no sugar');
      expect(
        (await repository.load('default')).proposals.map((p) => p.id),
        isNot(contains(id)),
      );
    }, skip: skip);

    test('Approve all decides the ids it was given, not a later one', () async {
      final first = stage('memory', {
        'action': 'add',
        'target': 'user',
        'content': 'Runs on a Mac',
      }, summary: 'add to user profile: Runs on a Mac');
      final listed = (await repository.load('default')).proposals
          .where((p) => p.id == first)
          .toList();
      final later = stage('memory', {
        'action': 'add',
        'target': 'user',
        'content': 'Plays chess',
      }, summary: 'add to user profile: Plays chess');
      final inbox = decisions();
      addTearDown(inbox.dispose);

      await inbox.decideAll(listed, approve: true);

      expect(inbox.stateOf(first).phase, MemoryDecisionPhase.saved);
      expect(inbox.stateOf(later).phase, MemoryDecisionPhase.idle);
      expect(userFile.readAsStringSync(), isNot(contains('chess')));
      expect(
        (await repository.load('default')).proposals.map((p) => p.id),
        contains(later),
      );
    }, skip: skip);

    test('a skill proposal lists, shows its changes and is rejected', () async {
      final id = stage(
        'skills',
        {
          'action': 'create',
          'name': 'contract-check',
          'content': '---\nname: contract-check\ndescription: Checks things\n---\nBody\n',
        },
        summary: "create 'contract-check' — Checks things (60 chars)",
        origin: 'background_review',
      );

      final snapshot = await repository.load('default');
      final skill = snapshot.skills.proposals.singleWhere((p) => p.id == id);
      expect(skill.skillName, 'contract-check');
      expect(skill.background, isTrue);
      expect(await repository.diff('default', id), startsWith('---\nname:'));

      final inbox = decisions();
      addTearDown(inbox.dispose);
      await inbox.decide(id, approve: false, kind: ProposalKind.skill);
      expect(inbox.stateOf(id).phase, MemoryDecisionPhase.rejected);
    }, skip: skip);

    test(
      'a command the server does not know answers Unknown command',
      () async {
        expect(
          await session.run('default', '/nosuch pending'),
          startsWith('Unknown command'),
        );
      },
      skip: skip,
    );

    test('reading proposals leaves no chat behind', () async {
      final before = (await HermesChatRepository(
        client.raw,
      ).loadThreads()).map((t) => t.id).toSet();
      await repository.load('default');
      await repository.load('default');
      final after = (await HermesChatRepository(
        client.raw,
      ).loadThreads()).map((t) => t.id).toSet();
      expect(after, before);
    }, skip: skip);
  });

  group('tools (read only: nothing is switched, saved or installed)', () {
    late HermesToolsRepository tools;

    setUp(() => tools = HermesToolsRepository(client.raw, profile: 'default'));

    T value<T>(ToolsResult<T> result) {
      expect(result, isA<ToolsOk<T>>());
      return (result as ToolsOk<T>).value;
    }

    test('the list has the fields the app reads, and "available" still '
        'copies "enabled"', () async {
      final response = await client.raw.getToolsetsApiToolsToolsetsGet(
        profile: 'default',
      );
      final raw = response.data! as List<dynamic>;
      for (final row in raw.whereType<Map<String, dynamic>>()) {
        expect(row['name'], isA<String>());
        expect(row['enabled'], isA<bool>());
        expect(row['configured'], isA<bool>());
        expect(row['platform'], isA<String>());
        expect(row['available'], row['enabled'], reason: '${row['name']}');
      }

      final list = value(await tools.list());

      expect(list.skipped, 0);
      expect(list.toolsets, isNotEmpty);
      expect(list.toolsets.map((t) => t.name), contains('terminal'));
    });

    test('a toolset with a provider matrix reads its providers', () async {
      final list = value(await tools.list());
      final name = list.toolsets
          .map((t) => t.name)
          .firstWhere(
            (n) => n == 'web',
            orElse: () => list.toolsets.first.name,
          );

      final config = value(await tools.config(name));

      expect(config.skipped, 0);
      if (config.hasCategory) {
        expect(config.providers, isNotEmpty);
        for (final provider in config.providers) {
          expect(provider.name, isNotEmpty);
          for (final env in provider.envVars) {
            expect(env.key, isNotEmpty);
          }
        }
      }
    });

    test('a toolset without a catalog says so', () async {
      final models = value(await tools.models('web'));

      expect(models.hasModels, isFalse);
    });

    test('the terminal backends name an active one', () async {
      final backends = value(await tools.terminalBackends());

      expect(backends.skipped, 0);
      expect(backends.backends, isNotEmpty);
      expect(backends.backends.map((b) => b.name), contains('local'));
    });

    test('the computer use status answers, and a missing permission is '
        'only ever null or a bool', () async {
      final status = value(await tools.computerUseStatus());

      final raw =
          (await client.raw.getComputerUseStatusApiToolsComputerUseStatusGet(
                profile: 'default',
              )).data!
              as Map<String, dynamic>;
      for (final key in ['accessibility', 'screen_recording', 'ready']) {
        expect(raw[key], anyOf(isNull, isA<bool>()), reason: key);
      }
      expect(status.platform, isNotNull);
      if (!status.installed) expect(status.canOfferGrant, isFalse);
    });

    test('an unknown toolset is refused with a 400, not a 404', () async {
      final result = await tools.config(
        'no_such_toolset_${DateTime.now().millisecondsSinceEpoch}',
      );

      expect(result, isA<ToolsRefused<ToolsetConfig>>());
    });

    test('a profile that does not exist is told apart from a missing '
        'route', () async {
      final gone = tools.forProfile(
        'contract-missing-${DateTime.now().millisecondsSinceEpoch}',
      );

      expect(await gone.list(), isA<ToolsProfileGone<ToolsetList>>());
    });
  }, skip: skip);

  group('requests scoped to a second profile (no model call)', () {
    final profile = 'contract-scope-${DateTime.now().millisecondsSinceEpoch}';
    late HermesPluginManagerRepository plugins;

    setUpAll(() async {
      if (url == null) return;
      await client.raw.createProfileEndpointApiProfilesPost(
        profileCreate: ProfileCreate(name: profile, noSkills: true),
      );
    });

    tearDownAll(() async {
      if (url == null) return;
      await client.raw.deleteProfileEndpointApiProfilesNameDelete(
        name: profile,
      );
    });

    setUp(() => plugins = HermesPluginManagerRepository(client.raw));

    test('servers that ignore the profile still answer', () async {
      final cron = HermesCronRepository(client.raw);

      expect((await cron.deliveryTargets(profile: profile)).first.id, 'local');
      await cron.blueprints(profile: profile);
      expect(await plugins.forProfile(profile).load(), isNotEmpty);
    }, skip: skip);

    Future<bool> hubTakesProfile() async {
      try {
        await client.raw.getPluginsHubApiDashboardPluginsHubGet(
          profile: 'no-such-profile',
        );
        return false;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return true;
        rethrow;
      }
    }

    test('the hub and plugin visibility follow the profile', () async {
      if (!await hubTakesProfile()) return;
      final scoped = plugins.forProfile(profile);
      bool hidden(List<InstalledPlugin> list, String name) =>
          list.any((p) => p.name == name && p.hidden);
      final ownHub = await plugins.load();
      final plugin = (await scoped.load()).firstWhere(
        (p) => !p.hidden && !hidden(ownHub, p.name),
      );

      expect((await scoped.setHidden(plugin.name, true)).ok, isTrue);

      expect(hidden(await scoped.load(), plugin.name), isTrue);
      expect(hidden(await plugins.load(), plugin.name), isFalse);
    }, skip: skip);
  });

  group('server files (read only)', () {
    // Only GETs on /api/fs: nothing is written or deleted on the backend. The
    // checks read the folder the dashboard itself runs in, so they hold on
    // whatever files it has. The shapes are from the spec and Hermes' own
    // tests (`test_web_server_fs.py`), not yet recorded against a live
    // backend: cases that need a particular file (a `.env` for 403, a locked
    // database for 409, an SSH workspace) are not covered here.
    late HermesFilesRepository files;
    late ServerPath cwd;

    T value<T>(FilesResult<T> r) {
      expect(r, isA<FilesOk<T>>(), reason: 'the route answered: $r');
      return (r as FilesOk<T>).value;
    }

    setUp(() async {
      files = HermesFilesRepository(client, profile: 'default');
      cwd = value(await files.defaultCwd());
      // The page never leaves the start folder's repository; here the start
      // folder itself stands in, so the boundary is exercised on real rows.
      files.highestFolder = cwd;
    });

    test(
      'the probe finds the routes, and the start folder is absolute',
      () async {
        expect(await files.probe(), isA<FilesOk<void>>());
      },
    );

    test('git-root answers a folder or null', () async {
      value(await files.gitRoot(cwd));
    });

    test('the listing parses, with no row skipped', () async {
      final listing = value(await files.list(cwd));
      expect(listing.skipped, 0);
      final firstFile = listing.entries.indexWhere((e) => !e.isDirectory);
      final lastFolder = listing.entries.lastIndexWhere((e) => e.isDirectory);
      if (firstFile >= 0 && lastFolder >= 0) {
        expect(lastFolder, lessThan(firstFile), reason: 'folders come first');
      }
    });

    test(
      'a missing folder and a file asked for as a folder are failures',
      () async {
        final missing = ServerPath.tryParse(
          '${cwd.value}/contract-check-missing',
        )!;
        final answer = await files.list(missing);
        expect(
          answer,
          isA<FilesFailed<FsListing>>(),
          reason: 'a 200 with ENOENT is not an empty folder',
        );
        expect((answer as FilesFailed<FsListing>).kind, FilesFailure.missing);

        final listing = value(await files.list(cwd));
        final file = listing.entries.where((e) => !e.isDirectory).firstOrNull;
        if (file != null) {
          final asFolder = await files.list(file.path);
          expect(
            asFolder,
            isA<FilesFailed<FsListing>>().having(
              (f) => f.kind,
              'kind',
              FilesFailure.notAFile,
            ),
          );
        }
      },
    );

    test('a profile the server does not have is badRequest', () async {
      final other = HermesFilesRepository(
        client,
        profile: 'contract-check-missing-profile',
      );
      final answer = await other.list(cwd);
      expect(answer, isA<FilesFailed<FsListing>>());
      expect((answer as FilesFailed<FsListing>).kind, FilesFailure.badRequest);
    });

    test('a file reads as text and downloads with its length', () async {
      final listing = value(await files.list(cwd));
      final file = listing.entries.where((e) => !e.isDirectory).firstOrNull;
      if (file == null) {
        markTestSkipped('the backend folder holds no file to read');
        return;
      }
      final text = await files.readText(file.path);
      if (text case FilesOk(:final value)) {
        expect(value.byteSize, greaterThanOrEqualTo(0));
        expect(value.truncated, isA<bool>());
      } else {
        // A secret name or a database in use: a kind, not an exception.
        expect(text, isA<FilesFailed<FsTextFile>>());
      }

      final dir = Directory.systemTemp.createTempSync('contract-files');
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = File('${dir.path}/download');
      final sink = out.openWrite();
      final result = await files.download(file.path, sink: sink);
      await sink.close();
      if (result case FilesOk(:final value) when value.declined) {
        // From 50 MB the repository stops after the headers and asks.
        expect(out.lengthSync(), 0);
        expect(value.contentLength, greaterThanOrEqualTo(kLargeDownloadBytes));
      } else if (result case FilesOk(:final value)) {
        expect(out.lengthSync(), value.bytes);
        // A local profile answers a Content-Length; an SSH workspace none.
        expect(value.contentLength, anyOf(isNull, value.bytes));
      } else {
        expect(result, isA<FilesFailed<FsDownload>>());
      }
    });
  }, skip: skip);

  group('a throwaway profile on a scripted model (no paid model call)', () {
    final profile = 'contract-check-${DateTime.now().millisecondsSinceEpoch}';
    late Directory scratch;
    late HttpServer model;

    setUpAll(() async {
      if (url == null) return;
      scratch = await Directory.systemTemp.createTemp('hermes-contract-');
      model = await _serveScriptedModel(
        command: 'rm -rf ${scratch.path}/doomed',
      );
      await client.raw.createProfileEndpointApiProfilesPost(
        profileCreate: ProfileCreate(name: profile, noSkills: true),
      );
      await client.raw.updateConfigRawApiConfigRawPut(
        profile: profile,
        rawConfigUpdate: RawConfigUpdate(
          yamlText:
              '''
model:
  default: "scripted"
  provider: "custom"
  base_url: "http://127.0.0.1:${model.port}/v1"
  api_key: "scripted"
  context_length: 131072
approvals:
  mode: manual
''',
        ),
      );
    });

    tearDownAll(() async {
      if (url == null) return;
      await client.raw.deleteProfileEndpointApiProfilesNameDelete(
        name: profile,
      );
      await model.close(force: true);
      await scratch.delete(recursive: true);
    });

    HermesGatewayTransport connect() {
      final transport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: url!,
          authRequired: false,
          api: client,
        ),
      );
      addTearDown(transport.close);
      return transport;
    }

    test(
      'an approval offers choices the card can show, and Allow once runs '
      'the command',
      () async {
        final doomed = Directory('${scratch.path}/doomed')..createSync();
        final transport = connect();
        final asked = <ApprovalRequest>[];
        final accepted = <bool>[];

        final events = await transport
            .send(profile: profile, text: 'Clean up.')
            .asyncMap((event) async {
              if (event is ApprovalRequested) {
                asked.add(event.request);
                accepted.add(
                  await transport.answerApproval(
                    event.request.requestId,
                    'once',
                  ),
                );
              }
              return event;
            })
            .toList();

        final request = asked.single;
        expect(request.command, contains('rm -rf'));
        expect(request.choices, containsAll(['once', 'deny']));
        expect(
          request.choices,
          everyElement(isIn(['once', 'session', 'always', 'deny'])),
        );
        expect(accepted, [isTrue]);
        expect((events.last as ReplyCompleted).failed, isFalse);
        expect(doomed.existsSync(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    Future<_GatewayTap> openTap() async {
      final tap = _GatewayTap(
        GatewayRpcClient(
          await hermesGatewayConnect(
            baseUrl: url!,
            authRequired: false,
            api: client,
          )(),
        ),
      );
      addTearDown(tap.close);
      return tap;
    }

    Matcher rpcError(int code) =>
        throwsA(isA<GatewayRpcException>().having((e) => e.code, 'code', code));

    test(
      'a delegation lists two running agents the app parses, which can be '
      'read, steered and stopped, and which only the attached connection '
      'controls',
      () async {
        final tap = await openTap();
        final session = await tap.rpc.request('session.create', {
          'profile': profile,
          'source': 'hermes_app',
        });
        final sid = session['session_id'] as String;
        await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': 'Delegate the crate counting.',
        });
        await tap.until(
          () =>
              tap
                  .eventsOf(sid)
                  .where((e) => e.type == 'subagent.tool')
                  .length >=
              2,
          'two subagent.tool frames',
        );
        final ids = <String>{
          for (final e in tap.eventsOf(sid))
            if (e.type == 'subagent.start') e.payload['subagent_id']! as String,
        };
        expect(ids, hasLength(2));
        Future<Map<String, Object?>> call(
          String method, [
          Map<String, Object?>? p,
        ]) => tap.rpc.request(method, {'session_id': sid, ...?p});

        // subagent.list: both children, running, steerable.
        final list = parseAgentList(await call('subagent.list'))!;
        expect(list.agents.map((a) => a.id).toSet(), ids);
        expect(list.delegations, isEmpty);
        for (final agent in list.agents) {
          expect(agent.state, AgentState.running);
          expect(agent.acceptingSteer, isTrue);
          expect(agent.goal, startsWith('Count the '));
          expect(agent.toolCount, 1);
          expect(agent.lastTool, 'terminal');
          expect(agent.startedAt, isNotNull);
          expect(agent.delegationId, isNotNull);
        }
        final [first, second] = ids.toList();

        // subagent.tail: the child's transcript, with its tool line.
        final tail = parseAgentTail(
          await call('subagent.tail', {'subagent_id': first}),
        )!;
        expect(tail.available, isTrue);
        expect(tail.truncated, isFalse);
        expect(tail.text, contains('terminal(sleep 30)'));

        // subagent.steer: queued for a running child, rejected for an
        // unknown one, and the two request errors.
        expect(
          parseSteerOutcome(
            await call('subagent.steer', {
              'subagent_id': first,
              'text': 'Use the small crate.',
            }),
          ),
          SteerOutcome.queued,
        );
        expect(
          parseSteerOutcome(
            await call('subagent.steer', {
              'subagent_id': 'sa-9-unknown',
              'text': 'Hello',
            }),
          ),
          SteerOutcome.rejected,
        );
        await expectLater(
          call('subagent.steer', {'subagent_id': first, 'text': '  '}),
          rpcError(4002),
        );
        await expectLater(
          call('subagent.steer', {'text': 'x'}),
          rpcError(4000),
        );
        await expectLater(call('subagent.tail'), rpcError(4000));

        // A connection that never resumed the chat: reads and interrupts are
        // 4001, a note is rejected (not 4001).
        final other = await openTap();
        await expectLater(
          other.rpc.request('subagent.list', {'session_id': sid}),
          rpcError(4001),
        );
        await expectLater(
          other.rpc.request('subagent.tail', {
            'session_id': sid,
            'subagent_id': first,
          }),
          rpcError(4001),
        );
        await expectLater(
          other.rpc.request('subagent.interrupt', {
            'session_id': sid,
            'subagent_id': first,
          }),
          rpcError(4001),
        );
        expect(
          parseSteerOutcome(
            await other.rpc.request('subagent.steer', {
              'session_id': sid,
              'subagent_id': first,
              'text': 'x',
            }),
          ),
          SteerOutcome.rejected,
        );

        // subagent.interrupt: found for a running child, not for an unknown
        // one; the child then completes as interrupted and is gone.
        expect(
          parseStopOutcome(
            await call('subagent.interrupt', {'subagent_id': second}),
          ),
          StopOutcome.stopped,
        );
        expect(
          parseStopOutcome(
            await call('subagent.interrupt', {'subagent_id': 'sa-9-unknown'}),
          ),
          StopOutcome.alreadyEnded,
        );
        await tap.until(
          () => tap
              .eventsOf(sid)
              .any(
                (e) =>
                    e.type == 'subagent.complete' &&
                    e.payload['subagent_id'] == second,
              ),
          'the interrupted child to complete',
        );
        final complete = tap
            .eventsOf(sid)
            .firstWhere(
              (e) =>
                  e.type == 'subagent.complete' &&
                  e.payload['subagent_id'] == second,
            );
        expect(complete.payload['status'], 'interrupted');
        expect(
          parseAgentTail(await call('subagent.tail', {'subagent_id': second}))!
              .available,
          isFalse,
        );
        expect(
          parseStopOutcome(
            await call('subagent.interrupt', {'subagent_id': second}),
          ),
          StopOutcome.alreadyEnded,
        );
        expect(
          parseSteerOutcome(
            await call('subagent.steer', {
              'subagent_id': second,
              'text': 'late',
            }),
          ),
          SteerOutcome.rejected,
        );

        // Stop the other child too, so nothing runs on after the test, and
        // see the interrupted delegations listed once they are recorded.
        expect(
          parseStopOutcome(
            await call('subagent.interrupt', {'subagent_id': first}),
          ),
          StopOutcome.stopped,
        );
        AgentList? after;
        for (var i = 0; i < 100; i++) {
          after = parseAgentList(await call('subagent.list'));
          if (after!.agents.isEmpty && after.delegations.length == 2) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(after!.agents, isEmpty);
        expect(after.delegations, hasLength(2));
        for (final row in after.delegations) {
          expect(row.state, AgentState.stopped);
          expect(row.goal, startsWith('Count the '));
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'a background program is listed, stopped once, and reads as stopped '
      'afterwards (a program of the test itself; process.stop is never sent)',
      () async {
        final tap = await openTap();
        final session = await tap.rpc.request('session.create', {
          'profile': profile,
          'source': 'hermes_app',
        });
        final sid = session['session_id'] as String;
        await tap.rpc.request('prompt.submit', {
          'session_id': sid,
          'text': 'Run background server.',
        });
        await tap.until(
          () => tap.eventsOf(sid).any((e) => e.type == 'message.complete'),
          'the reply',
        );
        Future<Map<String, Object?>> call(
          String method, [
          Map<String, Object?>? p,
        ]) => tap.rpc.request(method, {'session_id': sid, ...?p});

        final running = parseProcessList(await call('process.list'))!;
        final row = running.processes.single;
        expect(row.status, ProgramStatus.running);
        expect(row.command, 'echo ready on demo port; sleep 300');
        expect(row.outputTail, contains('ready on demo port'));
        expect(row.exitCode, isNull);
        expect(row.uptime, isNotNull);

        final killed = parseProcessKill(
          await call('process.kill', {'process_id': row.id}),
        )!;
        expect(killed.outcome, KillOutcome.killed);
        expect(killed.completionReason, 'killed');
        expect(killed.output, contains('ready on demo port'));

        final after = parseProcessList(await call('process.list'))!;
        final ended = after.processes.single;
        expect(ended.id, row.id);
        expect(ended.running, isFalse);
        expect(ended.completionReason, 'killed');
        expect(ended.exitCode, isNegative);
        expect(ended.status, ProgramStatus.stopped);

        final again = parseProcessKill(
          await call('process.kill', {'process_id': row.id}),
        )!;
        expect(again.outcome, KillOutcome.alreadyExited);
        expect(again.completionReason, 'killed');
        expect(again.exitCode, isNegative);

        await expectLater(
          call('process.kill', {'process_id': 'proc_000000000000'}),
          rpcError(4044),
        );
        await expectLater(call('process.kill'), rpcError(4012));
        await expectLater(call('process.nope'), rpcError(-32601));
        await expectLater(
          tap.rpc.request('process.list', {'session_id': 'not-a-session'}),
          rpcError(4001),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'process.list and process.kill answer 5032 at once when the chat\'s '
      'agent could not be built',
      () async {
        final broken = '$profile-broken';
        await client.raw.createProfileEndpointApiProfilesPost(
          profileCreate: ProfileCreate(name: broken, noSkills: true),
        );
        addTearDown(
          () => client.raw.deleteProfileEndpointApiProfilesNameDelete(
            name: broken,
          ),
        );
        await client.raw.updateConfigRawApiConfigRawPut(
          profile: broken,
          rawConfigUpdate: RawConfigUpdate(
            yamlText:
                'model:\n  default: "none"\n  provider: "no-such-provider"\n',
          ),
        );
        final tap = await openTap();
        final session = await tap.rpc.request('session.create', {
          'profile': broken,
          'source': 'hermes_app',
        });
        final sid = session['session_id'] as String;
        await expectLater(
          tap.rpc.request('process.list', {'session_id': sid}),
          rpcError(5032),
        );
        await expectLater(
          tap.rpc.request('process.kill', {
            'session_id': sid,
            'process_id': 'proc_000000000000',
          }),
          rpcError(5032),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'an approval is found by its chat on another connection and answered '
      'there by its id, without resuming the chat',
      () async {
        final doomed = Directory('${scratch.path}/doomed')..createSync();
        final transport = connect();
        final other = connect();
        String? threadId;
        final found = <ApprovalRequest>[];
        final accepted = <bool>[];

        final events = await transport
            .send(profile: profile, text: 'Clean up.')
            .asyncMap((event) async {
              if (event is ThreadBound) threadId = event.threadId;
              if (event is ApprovalRequested) {
                found.addAll(
                  await other.pendingApprovals(
                    threadId: threadId!,
                    profile: profile,
                  ),
                );
                accepted.add(
                  await other.answerOpenRequest(
                    event.request.requestId,
                    const ApprovalChoiceAnswer('once'),
                    threadId: threadId,
                    profile: profile,
                  ),
                );
              }
              return event;
            })
            .toList();

        expect(found.single.command, contains('rm -rf'));
        expect(found.single.choices, containsAll(['once', 'deny']));
        expect(accepted, [isTrue]);
        expect((events.last as ReplyCompleted).failed, isFalse);
        expect(doomed.existsSync(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'a session made in a second profile is listed and resumed only '
      'there',
      () async {
        final active = (await HermesProfilesRepository(
          client.raw,
        ).loadActive()).active;
        final repository = HermesChatRepository(client.raw);
        final transport = connect();

        final first = await transport
            .send(profile: profile, text: 'Say hello.')
            .toList();
        final bound = first.first as ThreadBound;
        expect((first.last as ReplyCompleted).failed, isFalse);

        expect(
          (await repository.loadThreads(profile: profile)).map((t) => t.id),
          contains(bound.threadId),
        );
        expect(
          (await repository.loadThreads(profile: active)).map((t) => t.id),
          isNot(contains(bound.threadId)),
        );

        final second = await transport
            .send(threadId: bound.threadId, profile: profile, text: 'Again.')
            .toList();
        expect(second.whereType<ThreadBound>(), isEmpty);
        expect((second.last as ReplyCompleted).failed, isFalse);
        expect(
          await repository.loadMessages(bound.threadId, profile: profile),
          hasLength(4),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'a chat branches from an earlier reply into a new chat without the '
      'turns after it, and keeps its own',
      () async {
        final repository = HermesChatRepository(client.raw);
        final transport = connect();
        List<String> prompts(List<ChatMessage> messages) => [
          for (final m in messages)
            if (m.role == ChatRole.user) m.content,
        ];

        final first = await transport
            .send(profile: profile, text: 'First question.')
            .toList();
        final parent = (first.first as ThreadBound).threadId;
        addTearDown(() => repository.deleteThread(parent, profile: profile));
        await transport
            .send(threadId: parent, profile: profile, text: 'Second question.')
            .drain<void>();

        final branch = await transport.branchThread(
          parent,
          profile: profile,
          dropTurns: 1,
        );
        expect(branch, isNotNull);
        addTearDown(
          () => repository.deleteThread(branch!.id, profile: profile),
        );

        expect(branch!.id, isNot(parent));
        expect(
          prompts(await repository.loadMessages(branch.id, profile: profile)),
          ['First question.'],
        );
        expect(
          prompts(await repository.loadMessages(parent, profile: profile)),
          ['First question.', 'Second question.'],
        );

        final whole = await transport.branchThread(parent, profile: profile);
        addTearDown(() => repository.deleteThread(whole!.id, profile: profile));
        expect(
          prompts(await repository.loadMessages(whole!.id, profile: profile)),
          ['First question.', 'Second question.'],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );

    test(
      'checkpoints and the context breakdown answer in the shapes the app '
      'reads (reads only: nothing is restored or compressed)',
      () async {
        final repository = HermesChatRepository(client.raw);
        final transport = connect();
        final events = await transport
            .send(profile: profile, text: 'Contract check.')
            .toList();
        final thread = (events.first as ThreadBound).threadId;
        addTearDown(() => repository.deleteThread(thread, profile: profile));
        final binding = transport.ownedSessionFor(thread, profile: profile)!;

        // Checkpoints are off unless the backend turned them on; an old
        // backend has no `rollback.*`. Neither is a failure.
        final list = await transport.listCheckpoints(binding);
        expect(list, isNot(isA<CheckpointsFailed>()));
        if (list is CheckpointsOn && list.checkpoints.isNotEmpty) {
          expect(list.checkpoints.first.hash, hasLength(greaterThan(6)));
          expect(
            await transport.checkpointChanges(
              binding,
              list.checkpoints.first.hash,
            ),
            isNot(isA<ChangesFailed>()),
          );
        }

        final breakdown = await transport.contextBreakdown(binding);
        expect(breakdown, isNot(isA<BreakdownFailed>()));
        if (breakdown is Breakdown) {
          final percent = breakdown.percent;
          if (percent != null) expect(percent, inInclusiveRange(0, 100));
          expect(
            breakdown.categories.map((c) => c.tokens),
            orderedEquals(
              breakdown.categories.map((c) => c.tokens).toList()
                ..sort((a, b) => b.compareTo(a)),
            ),
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: skip,
    );
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

/// An OpenAI-compatible model that answers a prompt containing "Clean up"
/// with one terminal call running [command], and anything else, including the
/// call's result and Hermes' own side calls, with a plain line.
///
/// Two more prompts script the agent-control checks: "Delegate" answers with
/// a `delegate_task` call holding two goals, and "Run background" with a
/// background `terminal` call (`sleep 300`). A delegated child, told apart by
/// its system prompt ("focused subagent"), runs `terminal` `sleep 30` on its
/// first turn and answers plainly after the tool's result.
Future<HttpServer> _serveScriptedModel({required String command}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    if (request.uri.path.endsWith('/models')) {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'object': 'list',
          'data': [
            {'id': 'scripted', 'object': 'model', 'context_length': 131072},
          ],
        }),
      );
      await response.close();
      return;
    }
    final body = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, dynamic>;
    final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
    final last = messages.last;
    final userTurn = last['role'] == 'user';
    final lastText = jsonEncode(last['content']);
    final isChild = jsonEncode(messages.first['content'])
        .contains('focused subagent');
    final childFirstTurn = isChild && !messages.any((m) => m['role'] == 'tool');
    final canCall = body['tools'] != null;
    final cleanUp = canCall && userTurn && lastText.contains('Clean up');
    final delegate =
        canCall && !isChild && userTurn && lastText.contains('Delegate');
    final background =
        canCall && !isChild && userTurn && lastText.contains('Run background');
    final callTool =
        cleanUp || delegate || background || (canCall && childFirstTurn);
    Map<String, Object?> call(String id, String name, Object arguments) => {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': jsonEncode(arguments)},
    };
    final calls = [
      if (cleanUp) call('call_scripted', 'terminal', {'command': command}),
      if (delegate)
        call('call_delegate', 'delegate_task', {
          'tasks': [
            {'goal': 'Count the apples in the demo crate'},
            {'goal': 'Count the pears in the demo crate'},
          ],
        }),
      if (background)
        call('call_background', 'terminal', {
          'command': 'echo ready on demo port; sleep 300',
          'background': true,
        }),
      if (canCall && childFirstTurn)
        call('call_child', 'terminal', {'command': 'sleep 30'}),
    ];
    final content = callTool ? null : 'Done.';
    final finish = callTool ? 'tool_calls' : 'stop';
    const usage = {
      'prompt_tokens': 10,
      'completion_tokens': 10,
      'total_tokens': 20,
    };
    if (body['stream'] != true) {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'id': 'chatcmpl-scripted',
          'object': 'chat.completion',
          'model': 'scripted',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': content,
                if (callTool) 'tool_calls': calls,
              },
              'finish_reason': finish,
            },
          ],
          'usage': usage,
        }),
      );
      await response.close();
      return;
    }
    response.headers.contentType = ContentType('text', 'event-stream');
    void chunk(Map<String, Object?> payload) => response.write(
      'data: ${jsonEncode({'id': 'chatcmpl-scripted', 'object': 'chat.completion.chunk', 'model': 'scripted', ...payload})}\n\n',
    );
    chunk({
      'choices': [
        {
          'index': 0,
          'delta': {
            'role': 'assistant',
            'content': content ?? '',
            if (callTool)
              'tool_calls': [
                for (final (i, call) in calls.indexed) {'index': i, ...call},
              ],
          },
          'finish_reason': null,
        },
      ],
    });
    chunk({
      'choices': [
        {'index': 0, 'delta': <String, Object?>{}, 'finish_reason': finish},
      ],
    });
    chunk({'choices': <Object?>[], 'usage': usage});
    response.write('data: [DONE]\n\n');
    await response.close();
  });
  return server;
}

/// A raw gateway connection that keeps the events it receives.
class _GatewayTap {
  _GatewayTap(this.rpc) {
    _subscription = rpc.events.listen(_events.add);
  }

  final GatewayRpcClient rpc;
  final _events = <GatewayEvent>[];
  late final StreamSubscription<GatewayEvent> _subscription;

  List<GatewayEvent> eventsOf(String sessionId) => [
    for (final event in _events)
      if (event.sessionId == sessionId) event,
  ];

  List<String> types(String sessionId) => [
    for (final event in eventsOf(sessionId)) event.type,
  ];

  /// Whether [sessionId] reported that it stopped running after its last
  /// `message.complete`.
  bool idleAfterComplete(String sessionId) {
    final events = eventsOf(sessionId);
    final completed = events.lastIndexWhere(
      (e) => e.type == 'message.complete',
    );
    return completed >= 0 &&
        events
            .skip(completed + 1)
            .any(
              (e) => e.type == 'session.info' && e.payload['running'] == false,
            );
  }

  /// Waits until [condition] holds, and fails naming [what] when it does not
  /// within two minutes.
  Future<void> until(bool Function() condition, String what) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('timed out waiting for $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await rpc.close();
  }
}
