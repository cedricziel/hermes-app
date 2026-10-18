import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/calls/call_readiness.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/call_speech_probe.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesChatRepository repository;
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

  CallReadinessChecker checker({
    Future<bool> Function()? microphone,
    Future<void> Function()? connection,
  }) => CallReadinessChecker(
    microphone: microphone ?? () async => allowed,
    input: () async => CallInput(useDevice: device, installed: installed),
    configuration: () => repository.voiceConfiguration(profile: 'work'),
    connection:
        connection ??
        () async {
          probes++;
        },
    isCurrent: () => active,
    timeout: const Duration(milliseconds: 30),
  );

  setUp(() {
    server = FakeHermesServer();
    repository = HermesChatRepository(server.client().raw);
    active = allowed = device = installed = true;
    probes = 0;
    config();
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
      expect(server.requests.single.queryParameters['profile'], 'work');
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
      expect(report.checks[3].status, CallCheckStatus.unavailable);
      expect(report.canAskHermes, isTrue);
      expect(report.setupPrompt, isNot(contains('private backend detail')));
    },
  );

  test(
    'a hung device permission check is bounded and other checks finish',
    () async {
      final report = await checker(microphone: () => Completer<bool>().future)
          .check();
      expect(report.checks[0].status, CallCheckStatus.unavailable);
      expect(report.checks[3].status, CallCheckStatus.ready);
      expect(report.ready, isFalse);
    },
  );

  test('retired context does not continue into backend checks', () async {
    final permission = Completer<bool>();
    final pending = checker(microphone: () => permission.future).check();
    active = false;
    permission.complete(true);
    await pending;
    expect(server.requests, isEmpty);
    expect(probes, 0);
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
