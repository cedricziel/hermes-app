import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/voice/calls/voice_model_route.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/call_speech_probe.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesChatRepository repository;
  late HermesModelsRepository models;
  var active = true, allowed = true, device = true, installed = true;
  var probes = 0;
  void config({String? sttReason, String? ttsReason, int status = 200}) {
    server.on('GET', '/api/audio/voice-config', {
      'stt': {'mode': 'relay', 'reason': sttReason},
      'tts': {
        'mode': 'direct',
        'reason': ttsReason,
        'api_key': 'fixture-secret-never-keep',
      },
    }, status: status);
  }

  void auxiliary(Map<String, Object?> row, {String? mainModel = 'gpt-main'}) {
    server.on('GET', '/api/model/auxiliary', {
      'tasks': [
        {'task': 'vision', 'provider': 'auto', 'model': '', 'base_url': ''},
        {'task': 'voice_chat', 'base_url': '', ...row},
      ],
      'main': {'provider': 'openai', 'model': ?mainModel},
    });
  }

  CallReadinessChecker checker({
    Future<bool> Function()? microphone,
    Future<void> Function()? connection,
  }) => CallReadinessChecker(
    voiceModel: () => models.loadVoiceRoute(profile: 'work'),
    gptLive: () => repository.voiceLiveIsGptLive(profile: 'work'),
    microphone: microphone ?? () async => allowed,
    input: () async => CallInput(useDevice: device, installed: installed),
    configuration: () => repository.voiceConfiguration(profile: 'work'),
    connection:
        connection ??
        () async {
          probes++;
        },
    isCurrent: () => active,
  );

  setUp(() {
    server = FakeHermesServer();
    repository = HermesChatRepository(server.client().raw);
    models = HermesModelsRepository(server.client().raw);
    active = allowed = device = installed = true;
    probes = 0;
    config();
    auxiliary({'provider': 'openai', 'model': 'gpt-voice'});
    server.on('GET', '/api/audio/voice-live/status', {'mode': 'chained'});
  });

  test(
    'checks profile settings and connection without using server STT for Apple',
    () async {
      config(sttReason: 'stt disabled');
      final progress = <CallReadiness>[];
      final report = await checker().check(onUpdate: progress.add);
      expect(report.ready, isTrue);
      expect(report.useDeviceSpeech, isTrue);
      expect(probes, 1);
      expect(
        server.requests.map((r) => r.queryParameters['profile']),
        everyElement('work'),
      );
      expect(progress.first.isChecking, isTrue);
      expect(report.setupPrompt, isNot(contains('fixture-secret')));
    },
  );

  test(
    'server transcription and speech output have separate setup diagnostics',
    () async {
      device = false;
      config(sttReason: 'stt disabled', ttsReason: 'no credentials');
      final report = await checker().check();
      expect(report.ready, isFalse);
      expect(report.canAskHermes, isTrue);
      expect(
        report.checks
            .where((c) => c.status == CallCheckStatus.needsSetup)
            .map((c) => c.id),
        [CallCheckId.input, CallCheckId.output],
      );
      expect(report.setupPrompt, contains('/api/audio/transcribe'));
      expect(report.setupPrompt, contains('ask me before installing packages'));
      expect(report.setupPrompt, isNot(contains('fixture-secret')));
    },
  );

  test(
    'missing microphone and model stay local, not an agent setup request',
    () async {
      allowed = installed = false;
      final report = await checker().check();
      expect(report.ready, isFalse);
      expect(report.canAskHermes, isFalse);
      expect(report.checks[0].action, CallSetupAction.microphone);
      expect(report.checks[1].action, CallSetupAction.dictation);
    },
  );

  test(
    'an older backend is distinct from missing provider credentials',
    () async {
      config(status: 404);
      final report = await checker().check();
      expect(report.checks[2].detail, 'Update Hermes to enable voice calls.');
      expect(report.canAskHermes, isTrue);
      expect(probes, 0);
      expect(await repository.voiceSupport(), VoiceSupport.none);
    },
  );

  for (final status in [401, 403]) {
    test(
      'auth failure $status asks for sign-in, not backend configuration',
      () async {
        config(status: status);
        final report = await checker().check();
        expect(report.checks[2].detail, contains('Sign in'));
        expect(report.canAskHermes, isFalse);
        expect(probes, 0);
      },
    );
  }

  test('malformed and unresolved settings are not marked ready', () async {
    for (final body in [
      <String, Object?>{},
      {
        'stt': {'reason': 'resolution failed'},
        'tts': {'reason': 'resolution error'},
      },
    ]) {
      server.on('GET', '/api/audio/voice-config', body);
      final report = await checker().check();
      expect(report.ready, isFalse);
      expect(report.checks[2].status, CallCheckStatus.unavailable);
      expect(probes, 0);
    }
  });

  test(
    'blocked speech socket is actionable without inventing a provider error',
    () async {
      final report = await checker(
        connection: () async => throw StateError('private backend detail'),
      ).check();
      expect(report.checks[2].status, CallCheckStatus.ready);
      expect(report.checks[4].status, CallCheckStatus.unavailable);
      expect(report.canAskHermes, isTrue);
      expect(report.setupPrompt, isNot(contains('private backend detail')));
    },
  );

  test('a hung device permission check is bounded and other checks finish', () {
    fakeAsync((clock) {
      CallReadiness? report;
      unawaited(
        checker(microphone: () => Completer<bool>().future)
            .check()
            .then((value) => report = value),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 7));
      expect(report, isNull);
      clock.elapse(const Duration(seconds: 1));
      expect(report, isNotNull);
      expect(report!.checks[0].status, CallCheckStatus.unavailable);
      expect(report!.checks[4].status, CallCheckStatus.ready);
      expect(report!.ready, isFalse);
    });
  });

  test('retired context does not continue into backend checks', () async {
    final permission = Completer<bool>();
    final pending = checker(microphone: () => permission.future).check();
    active = false;
    permission.complete(true);
    await pending;
    expect(server.requests, isEmpty);
    expect(probes, 0);
  });

  group('voice model row', () {
    CallCheck row(CallReadiness r) => r.checks[CallCheckId.voiceModel.index];

    test('a named model resolves', () async {
      final report = await checker().check();
      expect(row(report).status, CallCheckStatus.ready);
      expect(report.ready, isTrue);
      expect(
        server.requests.map((r) => r.path),
        contains('/api/model/auxiliary'),
      );
      final read = server.requests.firstWhere(
        (r) => r.path == '/api/model/auxiliary',
      );
      expect(read.queryParameters['profile'], 'work');
    });

    test(
      'a slot that follows the main model resolves while one is set',
      () async {
        auxiliary({'provider': 'auto', 'model': ''});
        expect(row(await checker().check()).status, CallCheckStatus.ready);
        auxiliary({'provider': 'main', 'model': ''});
        expect(row(await checker().check()).status, CallCheckStatus.ready);
      },
    );

    test(
      'following a main model that is not set warns and still starts',
      () async {
        auxiliary({'provider': 'auto', 'model': ''}, mainModel: null);
        final report = await checker().check();
        expect(row(report).status, CallCheckStatus.warning);
        expect(row(report).detail, contains('can still start'));
        expect(report.ready, isTrue);
      },
    );

    test('a base URL without a model does not resolve', () async {
      auxiliary({'provider': 'auto', 'model': '', 'base_url': 'http://x'});
      expect(row(await checker().check()).status, CallCheckStatus.warning);
    });

    test('a provider pinned without a model resolves', () async {
      auxiliary({'provider': 'openrouter', 'model': ''});
      final report = await checker().check();
      expect(row(report).status, CallCheckStatus.ready);
      expect(row(report).detail, contains('fast model'));
    });

    test('an inheriting row is read by its effective route', () async {
      auxiliary({
        'provider': 'auto',
        'model': '',
        'inherit_from': 'compression',
        'effective': {'provider': 'openai', 'model': 'gpt-small'},
      }, mainModel: null);
      expect(row(await checker().check()).status, CallCheckStatus.ready);
    });

    for (final status in [404, 500]) {
      test('a $status read is a warning, not a block', () async {
        server.on('GET', '/api/model/auxiliary', {}, status: status);
        final report = await checker().check();
        expect(row(report).status, CallCheckStatus.warning);
        expect(row(report).detail, contains("Couldn't check"));
        expect(report.ready, isTrue);
        expect(report.canAskHermes, isFalse);
        expect(probes, 1, reason: 'the other checks still ran');
      });
    }

    test('an older server without the slot says it cannot check', () async {
      server.on('GET', '/api/model/auxiliary', {
        'tasks': [
          {'task': 'vision', 'provider': 'auto'},
        ],
        'main': {'model': 'm'},
      });
      expect(row(await checker().check()).status, CallCheckStatus.warning);
    });

    test('a failed voice model read does not hide a speech problem', () async {
      server.on('GET', '/api/model/auxiliary', {}, status: 404);
      config(ttsReason: 'no credentials');
      final report = await checker().check();
      expect(report.ready, isFalse);
      expect(
        report.checks[CallCheckId.output.index].status,
        CallCheckStatus.needsSetup,
      );
    });

    test('the row is in the telemetry as a fixed word', () async {
      final logged = <Map<String, Object>>[];
      final report = await CallReadinessChecker(
        microphone: () async => true,
        input: () async => const CallInput(useDevice: true),
        configuration: () => repository.voiceConfiguration(profile: 'work'),
        connection: () async {},
        voiceModel: () async => throw StateError('private'),
        gptLive: () async => false,
        isCurrent: () => true,
        events: (name, [a = const {}]) => logged.add(a),
      ).check();
      expect(report.ready, isTrue);
      expect(logged.single, containsPair('voiceModel', 'warning'));
      expect(logged.single, containsPair('voiceModel_error', 'state'));
    });

    test('pure parsing handles odd bodies', () {
      expect(VoiceModelRoute.fromJson(null), VoiceModelRoute.unknown);
      expect(VoiceModelRoute.fromJson({'tasks': 'x'}), VoiceModelRoute.unknown);
      expect(
        VoiceModelRoute.fromJson({
          'tasks': [
            {'task': 'voice_chat', 'provider': 7, 'model': null},
          ],
          'main': 'x',
        }),
        VoiceModelRoute.unresolved,
      );
    });
  });

  group('GPT-Live note', () {
    test(
      'a gpt-live profile gets the note and the call is still ready',
      () async {
        server.on('GET', '/api/audio/voice-live/status', {
          'mode': 'gpt-live',
          'can_start': true,
        });
        final report = await checker().check();
        expect(report.gptLive, isTrue);
        expect(report.ready, isTrue);
        final read = server.requests.firstWhere(
          (r) => r.path == '/api/audio/voice-live/status',
        );
        expect(read.queryParameters['profile'], 'work');
      },
    );

    test('chained, an older server and a failed read give no note', () async {
      expect((await checker().check()).gptLive, isFalse);
      server.on('GET', '/api/audio/voice-live/status', {}, status: 404);
      final report = await checker().check();
      expect(report.gptLive, isFalse);
      expect(report.ready, isTrue);
    });
  });

  test('a warning lets the call start, a missing row does not', () {
    const all = [
      CallCheck(CallCheckId.microphone, CallCheckStatus.ready, ''),
      CallCheck(CallCheckId.input, CallCheckStatus.ready, ''),
      CallCheck(CallCheckId.output, CallCheckStatus.ready, ''),
      CallCheck(CallCheckId.voiceModel, CallCheckStatus.warning, ''),
      CallCheck(CallCheckId.connection, CallCheckStatus.ready, ''),
    ];
    expect(const CallReadiness(all).ready, isTrue);
    expect(CallReadiness(all.sublist(0, 4)).ready, isFalse);
    expect(
      CallReadiness([
        for (final c in all)
          c.id == CallCheckId.connection
              ? const CallCheck(
                  CallCheckId.connection,
                  CallCheckStatus.warning,
                  '',
                )
              : c,
      ]).ready,
      isTrue,
    );
  });

  test('an empty or partial report cannot start a call', () {
    expect(const CallReadiness([]).ready, isFalse);
    expect(
      const CallReadiness([
        CallCheck(CallCheckId.microphone, CallCheckStatus.ready, 'Ready'),
      ]).ready,
      isFalse,
    );
  });

  for (final late in [false, true]) {
    test(
      'probe closes ${late ? 'a timed-out late socket' : 'the socket'} without sending speech',
      () async {
        final socket = StreamChannelController<Object?>();
        final sent = <Object?>[];
        final closed = Completer<void>();
        socket.foreign.stream.listen(sent.add, onDone: closed.complete);
        final opening = Completer<StreamChannel<Object?>>();
        final probe = probeCallSpeech(
          ([query = const {}]) {
            expect(query, {'profile': 'work'});
            return opening.future;
          },
          'work',
          isCurrent: () => true,
          timeout: const Duration(milliseconds: 10),
        );
        if (late) {
          await expectLater(probe, throwsA(isA<TimeoutException>()));
          opening.complete(socket.local);
        } else {
          opening.complete(socket.local);
          await probe;
        }
        await closed.future.timeout(const Duration(seconds: 1));
        expect(sent, isEmpty);
        await socket.foreign.sink.close();
      },
    );
  }
}
