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

  setUp(() async {
    MediaKit.ensureInitialized(libmpv: Platform.environment['HERMES_LIBMPV']);
    port = _Port();
    session = VoiceAudioSession(port: port, deactivationDelay: Duration.zero);
    final backend = Player(
      configuration: const PlayerConfiguration(protocolWhitelist: ['file']),
    );
    await (backend.platform as NativePlayer).setProperty('ao', 'null');
    player = NativeVoicePlayer(player: backend, audioSession: session);
    addTearDown(player.dispose);
    await player.load(File('test/fixtures/voice/voice.wav').absolute.path);
  });

  test('pause gives the session back, telling other apps', () async {
    await player.play();
    expect(session.held, isTrue);
    await player.pause();

    expect(session.held, isFalse);
    expect(port.calls, ['configure:playback', 'activate', 'deactivate+notify']);
  }, skip: !enabled);

  test(
    'a call starting under a playing player leaves the session free',
    () async {
      await player.play();
      final call = Object();
      VoiceAudioFocus.shared.register(player.pause);
      addTearDown(() => VoiceAudioFocus.shared.unregister(player.pause));
      await VoiceAudioFocus.shared.acquire(call);
      VoiceAudioFocus.shared.release(call);

      expect(session.held, isFalse);
      port.calls.clear();
      final recorder = Object();
      await session.acquire(recorder, voiceRecordingSession, reconfigure: true);
      await session.release(recorder);

      expect(port.calls, [
        'configure:playAndRecord',
        'activate',
        'deactivate+notify',
      ]);
    },
  );
}
