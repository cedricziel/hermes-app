import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_audio_focus.dart';
import 'package:hermes_app/src/voice/voice_audio_session.dart';
import 'package:hermes_app/src/voice/voice_player.dart';
import 'package:hermes_app/src/voice/voice_recorder.dart';

/// Records what reaches the platform session, in order.
class _Port implements AudioSessionPort {
  final calls = <String>[];
  AVAudioSessionSetActiveOptions? lastDeactivation;
  bool grant = true;
  bool failConfigure = false;
  bool hang = false;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    if (hang) await Completer<void>().future;
    if (failConfigure) throw PlatformException(code: 'configure');
    calls.add('configure:${configuration.avAudioSessionCategory?.name ?? '-'}');
  }

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? options,
  }) async {
    calls.add(active ? 'activate' : 'deactivate');
    if (!active) lastDeactivation = options;
    return active ? grant : true;
  }
}

const _deactivate = 'deactivate';

void main() {
  late _Port port;
  late VoiceAudioSession session;
  final recording = <String>[];
  var recorderFails = false;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    port = _Port();
    session = VoiceAudioSession(port: port, deactivationDelay: Duration.zero);
    recording.clear();
    recorderFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async {
            recording.add(call.method);
            if (call.method == 'startStream' && recorderFails) {
              throw PlatformException(code: 'start');
            }
            return call.method == 'isRecording' ? true : null;
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            null,
          ),
    );
  });

  group('VoiceAudioSession', () {
    test('configures, activates, then deactivates telling others', () async {
      expect(await session.acquire('a', voicePlaybackSession), isTrue);
      await session.release('a');

      expect(port.calls, ['configure:playback', 'activate', _deactivate]);
      expect(
        port.lastDeactivation,
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    });

    test('deactivates once, when the last owner leaves', () async {
      await session.acquire('a', voicePlaybackSession);
      await session.acquire('b', voiceRecordingSession);
      await session.release('a');
      expect(port.calls.where((c) => c == _deactivate), isEmpty);
      await session.release('b');
      await session.release('b');

      expect(port.calls, ['configure:playback', 'activate', _deactivate]);
    });

    test('a refused session stays inactive and owned by nobody', () async {
      port.grant = false;

      expect(await session.acquire('a', voiceRecordingSession), isFalse);

      expect(session.held, isFalse);
      expect(port.calls.last, _deactivate);
    });

    test('a configuration that throws also ends deactivated', () async {
      port.failConfigure = true;

      expect(await session.acquire('a', voiceRecordingSession), isFalse);

      expect(port.calls, [_deactivate]);
      expect(session.held, isFalse);
    });

    test('a release without an acquire sends nothing', () async {
      await session.release('a');

      expect(port.calls, isEmpty);
    });
  });

  group('VoiceAudioSession handover', () {
    test('a recording joining a playback reconfigures the session', () async {
      await session.acquire('play', voicePlaybackSession);
      await session.acquire('rec', voiceRecordingSession, reconfigure: true);

      expect(port.calls, [
        'configure:playback',
        'activate',
        'configure:playAndRecord',
        'activate',
      ]);
    });

    test(
      'an owner forgotten for a call leaves no deactivation behind',
      () async {
        await session.acquire('play', voicePlaybackSession);
        await session.forget('play');
        await session.acquire('rec', voiceRecordingSession, reconfigure: true);
        port.calls.clear();
        await session.release('rec');

        expect(port.calls, [_deactivate]);
        expect(
          port.lastDeactivation,
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        );
      },
    );

    test('a refused recording still deactivates when it ends', () async {
      port.grant = false;
      expect(
        await session.acquire('rec', voiceRecordingSession, reconfigure: true),
        isFalse,
      );
      port.calls.clear();
      await session.release('rec');

      expect(port.calls, [_deactivate]);
    });

    test(
      'a platform call that never answers does not block the next',
      () async {
        final slow = VoiceAudioSession(
          port: port,
          deactivationDelay: Duration.zero,
          callTimeout: const Duration(milliseconds: 50),
        );
        port.hang = true;
        expect(await slow.acquire('a', voicePlaybackSession), isFalse);
        port.hang = false;

        expect(await slow.acquire('b', voicePlaybackSession), isTrue);
      },
    );

    test('an owner replaced within the grace never deactivates', () async {
      final graceful = VoiceAudioSession(
        port: port,
        deactivationDelay: const Duration(milliseconds: 80),
      );
      await graceful.acquire('play', voicePlaybackSession);
      await graceful.release('play');
      await graceful.acquire('rec', voiceRecordingSession, reconfigure: true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(port.calls.where((c) => c == _deactivate), isEmpty);

      await graceful.release('rec');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(port.calls.where((c) => c == _deactivate), hasLength(1));
    });

    test(
      'a call that starts within the grace is not deactivated under',
      () async {
        final graceful = VoiceAudioSession(
          port: port,
          deactivationDelay: const Duration(milliseconds: 50),
        );
        await graceful.acquire('play', voicePlaybackSession);
        await graceful.release('play');
        final call = Object();
        await VoiceAudioFocus.shared.acquire(call);
        addTearDown(() => VoiceAudioFocus.shared.release(call));
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(port.calls.where((c) => c == _deactivate), isEmpty);
      },
    );
  });

  group('RecordVoiceRecorder', () {
    late RecordVoiceRecorder recorder;
    setUp(() => recorder = RecordVoiceRecorder(session: session));

    test('stop gives the session back', () async {
      await recorder.start(sampleRate: 16000);
      expect(port.calls, ['configure:playAndRecord', 'activate']);
      await recorder.stop();

      expect(port.calls.last, _deactivate);
      expect(session.held, isFalse);
      expect(
        port.lastDeactivation,
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    });

    test('a failed start leaves no active session', () async {
      recorderFails = true;

      await expectLater(recorder.start(sampleRate: 16000), throwsA(anything));

      expect(port.calls.last, _deactivate);
      expect(session.held, isFalse);
    });

    test('a recorder disposed mid-recording gives the session back', () async {
      await recorder.start(sampleRate: 16000);
      await recorder.dispose();

      expect(port.calls.last, _deactivate);
      expect(session.held, isFalse);
    });

    test('stopping twice deactivates once', () async {
      await recorder.start(sampleRate: 16000);
      await recorder.stop();
      await recorder.stop();

      expect(port.calls.where((c) => c == _deactivate), hasLength(1));
    });

    test(
      'a recording, then a spoken reply, each from its own category',
      () async {
        await recorder.start(sampleRate: 16000);
        await recorder.stop();
        await session.acquire('reply', voicePlaybackSession);
        await session.release('reply');

        expect(port.calls, [
          'configure:playAndRecord',
          'activate',
          _deactivate,
          'configure:playback',
          'activate',
          _deactivate,
        ]);
      },
    );
  });
}
