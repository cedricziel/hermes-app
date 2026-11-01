import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_readiness_checker.dart';
import 'package:hermes_app/src/voice/calls/call_telemetry.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fakes.dart';

void main() {
  group('callErrorKind', () {
    test('names failures by status, code or class, never by message', () {
      final options = RequestOptions(path: '/api/audio/voice-config');
      expect(
        callErrorKind(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 502),
          ),
        ),
        'http_502',
      );
      expect(
        callErrorKind(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        'dio_connectionTimeout',
      );
      expect(
        callErrorKind(
          WebSocketChannelException.from(
            const WebSocketException('https://secret.example/?ticket=x', 403),
          ),
        ),
        'upgrade_403',
      );
      expect(callErrorKind(TimeoutException('later')), 'timeout');
      expect(
        callErrorKind(PlatformException(code: 'permission', message: 'x')),
        'platform_permission',
      );
      expect(callErrorKind(MissingPluginException('no')), 'missing_plugin');
      expect(callErrorKind(const SocketException('host')), 'socket');
      expect(callErrorKind(StateError('private')), 'state');
      expect(callErrorKind(Exception('private')), 'other');
    });

    test('buckets turns and durations', () {
      expect(callTurnsBucket(0), '0');
      expect(callTurnsBucket(3), '2-5');
      expect(callTurnsBucket(9), '>5');
      expect(callDurationBucket(null), 'none');
      expect(callDurationBucket(const Duration(seconds: 30)), '10-60s');
      expect(callDurationBucket(const Duration(minutes: 9)), '>5m');
    });
  });

  test('readiness logs each check and the kind of a failure', () async {
    final logged = <(String, Map<String, Object>)>[];
    final checker = CallReadinessChecker(
      microphone: () async => true,
      input: () async => const CallInput(useDevice: true),
      configuration: () async => VoiceSupport.fromJson({
        'stt': {'mode': 'relay'},
        'tts': {'mode': 'direct'},
      }),
      connection: () async => throw WebSocketChannelException.from(
        const WebSocketException('wss://host/?ticket=secret', 403),
      ),
      isCurrent: () => true,
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    );
    final report = await checker.check();
    expect(report.ready, isFalse);
    expect(logged, hasLength(1));
    final (name, attributes) = logged.single;
    expect(name, 'voice_call.readiness');
    expect(attributes, {
      'ready': false,
      'device_speech': true,
      'microphone': 'ready',
      'input': 'ready',
      'output': 'ready',
      'connection': 'unavailable',
      'connection_error': 'upgrade_403',
    });
    expect(attributes.values.join(' '), isNot(contains('secret')));
  });

  test('a cancelled readiness check logs nothing', () async {
    final logged = <String>[];
    var current = true;
    final checker = CallReadinessChecker(
      microphone: () async {
        current = false;
        return true;
      },
      input: () async => const CallInput(useDevice: true),
      configuration: () async => throw StateError('unused'),
      connection: () async {},
      isCurrent: () => current,
      events: (name, [_ = const {}]) => logged.add(name),
    );
    await checker.check();
    expect(logged, isEmpty);
  });

  group('VoiceCall', () {
    late FakeCallBridge bridge;
    late FakeCallAgent agent;
    late StreamChannelController<Object?> socket;
    late List<(String, Map<String, Object>)> logged;
    late VoiceCall call;

    VoiceCall build({
      Future<String> Function()? transcribe,
      Future<void> Function()? prepare,
    }) => VoiceCall(
      bridge: bridge,
      agent: agent,
      connect: ([_ = const {}]) async => socket.local,
      prepare: prepare ?? () async {},
      transcribe: (_) => (transcribe ?? () async => 'Hello')(),
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    );

    setUp(() {
      bridge = FakeCallBridge();
      agent = FakeCallAgent();
      socket = StreamChannelController<Object?>();
      socket.foreign.stream.listen((_) {});
      logged = [];
      call = build();
      addTearDown(() async {
        await call.end();
        call.dispose();
        logged.clear();
        await bridge.controller.close();
      });
    });

    void utterance() {
      bridge.emit('pcm', {'data': pcm()});
      for (var i = 0; i < 9; i++) {
        bridge.emit('pcm', {'data': pcm(amplitude: 0)});
      }
    }

    Map<String, Object> ended() =>
        logged.singleWhere((e) => e.$1 == 'voice_call.ended').$2;

    test('a hang-up after one spoken turn logs once', () async {
      await call.start();
      bridge.emit('activated');
      expect(logged.map((e) => e.$1), ['voice_call.connected']);
      utterance();
      await pumpEventQueue();
      agent.text!('Sure.');
      agent.pending!.complete();
      socket.foreign.sink
        ..add(
          jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
        )
        ..add([0, 1, 2, 3])
        ..add(jsonEncode({'type': 'end'}));
      await pumpEventQueue();
      bridge.emit('ended');
      await pumpEventQueue();
      await call.end();
      expect(ended(), {
        'outcome': 'ended',
        'reason': 'hang_up',
        'connected': true,
        'turns': '1',
        'speech_fallbacks': '0',
        'duration': '<10s',
      });
    });

    test('a failed transcription names its step and error kind', () async {
      call.dispose();
      logged.clear();
      call = build(transcribe: () async => throw TimeoutException('slow'));
      await call.start();
      bridge.emit('activated');
      utterance();
      await pumpEventQueue();
      expect(call.phase, CallPhase.failed);
      expect(ended(), containsPair('reason', 'turn'));
      expect(ended(), containsPair('step', 'transcribe'));
      expect(ended(), containsPair('error_type', 'timeout'));
      expect(ended(), containsPair('outcome', 'failed'));
    });

    test('a refused speech socket is logged as the speech step', () async {
      call.dispose();
      logged.clear();
      call = VoiceCall(
        bridge: bridge,
        agent: agent,
        connect: ([_ = const {}]) async => throw WebSocketChannelException.from(
          const WebSocketException('not upgraded', 403),
        ),
        prepare: () async {},
        transcribe: (_) async => 'Hello',
        events: (name, [attributes = const {}]) =>
            logged.add((name, attributes)),
      );
      await call.start();
      bridge.emit('activated');
      utterance();
      await pumpEventQueue();
      expect(call.phase, CallPhase.failed);
      expect(ended(), containsPair('error_type', 'upgrade_403'));
      expect(ended()['reason'], anyOf('speech', 'turn'));
    });

    test(
      'a native start failure is logged before CallKit activation',
      () async {
        call.dispose();
        logged.clear();
        bridge = _RefusingBridge();
        call = build();
        await call.start();
        expect(call.phase, CallPhase.failed);
        expect(ended(), containsPair('reason', 'native_start'));
        expect(ended(), containsPair('error_type', 'platform_start'));
        expect(ended(), containsPair('connected', false));
        expect(
          logged.map((e) => e.$1),
          isNot(contains('voice_call.connected')),
        );
      },
    );
  });
}

class _RefusingBridge extends FakeCallBridge {
  @override
  Future<void> start(String id, String name) async =>
      throw PlatformException(code: 'start', message: 'private detail');
}
