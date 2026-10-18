import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_player.dart';
import 'package:media_kit/media_kit.dart';

// Uses the real libmpv/FFmpeg decoder with silent output. Opt in on a host
// with libmpv installed; see test/fixtures/voice/README.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('HERMES_NATIVE_AUDIO_TEST');

  for (final name in [
    'opus.ogg',
    'vorbis.ogg',
    'voice.mp3',
    'voice.m4a',
    'voice.wav',
    'voice.flac',
  ]) {
    test('native decoder plays $name through completion', () async {
      MediaKit.ensureInitialized(libmpv: Platform.environment['HERMES_LIBMPV']);
      final backend = Player(
        configuration: const PlayerConfiguration(protocolWhitelist: ['file']),
      );
      await (backend.platform as NativePlayer).setProperty('ao', 'null');
      final player = NativeVoicePlayer(player: backend);
      addTearDown(player.dispose);
      Future<void> until(bool Function() done) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!done() && !player.failed && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(player.failed, isFalse);
        expect(done(), isTrue);
      }

      await player.load(File('test/fixtures/voice/$name').absolute.path);
      await until(() => player.duration > Duration.zero);
      await player.play();
      await until(() => player.completed);
      expect(player.playing, isFalse);
    }, skip: !enabled);
  }
}
