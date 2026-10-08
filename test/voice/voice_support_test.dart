import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:hermes_app/src/voice/wav.dart';

import '../support/fake_hermes_server.dart';

void main() {
  group('wavFromPcm16', () {
    test('wraps mono 16-bit PCM in a RIFF/WAVE header', () {
      final pcm = Uint8List.fromList(List.filled(8, 7));

      final wav = wavFromPcm16(pcm, sampleRate: 16000);
      final header = ByteData.sublistView(wav);

      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(header.getUint32(4, Endian.little), 36 + 8);
      expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(header.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(28, Endian.little), 32000, reason: 'byte rate');
      expect(header.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(header.getUint16(34, Endian.little), 16);
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(header.getUint32(40, Endian.little), 8);
      expect(wav.sublist(44), pcm);
    });
  });

  group('VoiceSupport', () {
    Map<String, Object?> config({
      Map<String, Object?> stt = const {'mode': 'relay'},
      Map<String, Object?> tts = const {'mode': 'relay'},
    }) => {'ok': true, 'stt': stt, 'tts': tts};

    test('a local provider relays through Hermes and is usable', () {
      final support = VoiceSupport.fromJson(
        config(stt: {'mode': 'relay', 'reason': 'local provider'}),
      );

      expect(support.speechToText, isTrue);
      expect(support.liveTranscription, isFalse);
    });

    test('reads live transcription from stt.streaming', () {
      final support = VoiceSupport.fromJson(
        config(stt: {'mode': 'relay', 'streaming': true}),
      );

      expect(support.liveTranscription, isTrue);
    });

    test('turned-off speech-to-text and missing credentials are unusable', () {
      for (final reason in ['stt disabled', 'no credentials']) {
        final support = VoiceSupport.fromJson(
          config(stt: {'mode': 'relay', 'reason': reason}),
        );
        expect(support.speechToText, isFalse, reason: reason);
      }
    });

    test('text-to-speech without credentials is unusable', () {
      final support = VoiceSupport.fromJson(
        config(tts: {'mode': 'relay', 'reason': 'no credentials'}),
      );

      expect(support.speechToText, isTrue);
      expect(support.textToSpeech, isFalse);
    });

    test('client-direct answers count, but their keys are not kept', () {
      final support = VoiceSupport.fromJson(
        config(
          stt: {'mode': 'direct', 'api_key': 'sk-secret', 'streaming': true},
        ),
      );

      expect(support.speechToText, isTrue);
      expect(support.toString(), isNot(contains('sk-secret')));
    });

    test('a body without an stt section is unusable', () {
      expect(VoiceSupport.fromJson({'ok': true}).speechToText, isFalse);
      expect(VoiceSupport.fromJson('nope').speechToText, isFalse);
    });

    group('fetch', () {
      late FakeHermesServer server;

      setUp(() => server = FakeHermesServer());

      test('asks for the profile\'s voice config', () async {
        server.on(
          'GET',
          '/api/audio/voice-config',
          config(stt: {'mode': 'relay', 'streaming': true}),
          query: {'profile': 'work'},
        );

        final support = await HermesChatRepository(server.client().raw)
            .voiceSupport(profile: 'work');

        expect(support.speechToText, isTrue);
        expect(support.liveTranscription, isTrue);
      });

      test('an older server without the route offers no voice', () async {
        server.on('GET', '/api/audio/voice-config', {
          'detail': 'Not Found',
        }, status: 404);

        final support = await HermesChatRepository(server.client().raw)
            .voiceSupport();

        expect(support.speechToText, isFalse);
        expect(support.textToSpeech, isFalse);
      });
    });
  });
}
