import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_audio_session.dart';
import 'package:hermes_app/src/voice/voice_player.dart';
import 'package:hermes_app/src/voice/voice_recorder.dart';

/// Records what reaches the platform session, in order.
class _Port implements AudioSessionPort {
  final calls = <String>[];
  AVAudioSessionSetActiveOptions? lastDeactivation;
  bool grant = true;
  bool failConfigure = false;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
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
    session = VoiceAudioSession(port: port);
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
