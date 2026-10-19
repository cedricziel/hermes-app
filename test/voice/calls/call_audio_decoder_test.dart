import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_audio_decoder.dart';
import 'package:hermes_app/src/voice/synthesized_speech.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cancelled conversion never initializes a player or writes audio',
    () async {
      final cancellation = CancelToken()..cancel();
      await expectLater(
        decodeCallAudio(
          SynthesizedSpeech(Uint8List(2), 'audio/ogg'),
          cancellation,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    },
  );

  const enabled = bool.fromEnvironment('HERMES_NATIVE_AUDIO_TEST');
  for (final entry in {
    'opus.ogg': 'audio/ogg',
    'vorbis.ogg': 'audio/ogg',
    'voice.mp3': 'audio/mpeg',
    'voice.m4a': 'audio/mp4',
    'voice.wav': 'audio/wav',
    'voice.flac': 'audio/flac',
  }.entries) {
    test('converts ${entry.key} to call PCM without speaker output', () async {
      MediaKit.ensureInitialized(libmpv: Platform.environment['HERMES_LIBMPV']);
      final audio = await File('test/fixtures/voice/${entry.key}')
          .readAsBytes();
      final pcm = await decodeCallAudio(
        SynthesizedSpeech(audio, entry.value),
        CancelToken(),
      );
      // Fixtures are 400 ms at 24 kHz mono. Allow codec padding/resampling.
      expect(pcm.length, inInclusiveRange(18000, 22000));
      final samples = ByteData.sublistView(pcm);
      expect(
        List.generate(
          pcm.length ~/ 2,
          (i) => samples.getInt16(i * 2, Endian.little),
        ).any((s) => s.abs() > 100),
        isTrue,
      );
      expect(pcm.take(4), isNot('RIFF'.codeUnits));
    }, skip: !enabled);
  }
}
