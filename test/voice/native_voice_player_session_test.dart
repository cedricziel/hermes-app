import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_audio_focus.dart';
import 'package:hermes_app/src/voice/voice_audio_session.dart';
import 'package:hermes_app/src/voice/voice_player.dart';
import 'package:media_kit/media_kit.dart';

class _Port implements AudioSessionPort {
  final calls = <String>[];

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async =>
      calls.add('configure:${configuration.avAudioSessionCategory?.name}');

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? options,
  }) async {
    calls.add(
      active
          ? 'activate'
          : options == AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation
          ? 'deactivate+notify'
          : 'deactivate',
    );
    return true;
  }
}

// Uses the real libmpv decoder with silent output, like
// native_voice_player_test.dart; see test/fixtures/voice/README.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('HERMES_NATIVE_AUDIO_TEST');

  late _Port port;
  late VoiceAudioSession session;
  late NativeVoicePlayer player;

  Future<void> setUpPlayer(Duration delay) async {
    MediaKit.ensureInitialized(libmpv: Platform.environment['HERMES_LIBMPV']);
    port = _Port();
    session = VoiceAudioSession(port: port, deactivationDelay: delay);
    addTearDown(session.dispose);
    final backend = Player(
      configuration: const PlayerConfiguration(protocolWhitelist: ['file']),
    );
    await (backend.platform as NativePlayer).setProperty('ao', 'null');
    player = NativeVoicePlayer(player: backend, audioSession: session);
    addTearDown(player.dispose);
    await player.load(File('test/fixtures/voice/voice.wav').absolute.path);
  }

  // The whole group is skipped without libmpv, setup included.
  group('NativeVoicePlayer and the audio session', () {
    test('pause gives the session back, telling other apps', () async {
      await setUpPlayer(Duration.zero);
      await player.play();
      expect(session.held, isTrue);
      await player.pause();

      expect(session.held, isFalse);
      expect(port.calls, [
        'configure:playback',
        'activate',
        'deactivate+notify',
      ]);
    });

    for (final delay in [Duration.zero, const Duration(milliseconds: 60)]) {
      test('a call starting under a playing player ($delay)', () async {
        await setUpPlayer(delay);
        await player.play();
        final call = Object();
        VoiceAudioFocus.shared.register(player.pause);
        addTearDown(() => VoiceAudioFocus.shared.unregister(player.pause));
        await VoiceAudioFocus.shared.acquire(call);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Nothing deactivates while the call has the session.
        expect(session.held, isFalse);
        expect(port.calls, ['configure:playback', 'activate']);

        // A recording after the call starts from a free session.
        VoiceAudioFocus.shared.release(call);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        port.calls.clear();
        final recorder = Object();
        await session.acquire(
          recorder,
          voiceRecordingSession,
          reconfigure: true,
        );
        await session.release(recorder);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(port.calls, [
          'configure:playAndRecord',
          'activate',
          'deactivate+notify',
        ]);
      });
    }
  }, skip: !enabled);
}
