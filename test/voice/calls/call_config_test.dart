import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/calls/call_config.dart';

import '../../support/fake_hermes_server.dart';

VoiceCallConfig parse(Object? voice) =>
    VoiceCallConfig.fromJson(voice == null ? {} : {'voice': voice});

void main() {
  group('silence_duration', () {
    test('is 0.9 s when absent or not a number', () {
      expect(parse(null).silence, const Duration(milliseconds: 900));
      expect(parse({}).silence, const Duration(milliseconds: 900));
      expect(
        parse({'silence_duration': 'long'}).silence,
        const Duration(milliseconds: 900),
      );
      expect(
        VoiceCallConfig.fromJson('nonsense').silence,
        const Duration(milliseconds: 900),
      );
    });
    test('is used when set and clamped to 0.5 to 3 s', () {
      expect(
        parse({'silence_duration': 1.5}).silence,
        const Duration(milliseconds: 1500),
      );
      expect(
        parse({'silence_duration': 2}).silence,
        const Duration(seconds: 2),
      );
      expect(
        parse({'silence_duration': 0.1}).silence,
        const Duration(milliseconds: 500),
      );
      expect(
        parse({'silence_duration': 0}).silence,
        const Duration(milliseconds: 500),
      );
      expect(
        parse({'silence_duration': 30}).silence,
        const Duration(seconds: 3),
      );
    });
  });

  group('barge_in', () {
    test('is carried as a value, null when absent or malformed', () {
      expect(parse(null).bargeIn, isNull);
      expect(parse({'barge_in': false}).bargeIn, isFalse);
      expect(parse({'barge_in': true}).bargeIn, isTrue);
      expect(parse({'barge_in': 'no'}).bargeIn, isNull);
    });
  });

  group('stop phrases', () {
    test('the built-in list applies when the key is absent', () {
      final config = parse({});
      for (final phrase in [
        'stop',
        'end the call',
        'hang up',
        'end call',
        'goodbye',
        'never mind',
        'that is all',
      ]) {
        expect(config.isStopPhrase(phrase), isTrue, reason: phrase);
      }
      expect(config.isStopPhrase('bye'), isFalse);
      expect(config.isStopPhrase('stop the music and play jazz'), isFalse);
    });

    test('lowercases, trims punctuation and a leading address', () {
      final config = parse({});
      expect(config.isStopPhrase('Hang up.'), isTrue);
      expect(config.isStopPhrase('  "End the call!"  '), isTrue);
      expect(config.isStopPhrase('Hey Hermes, goodbye.'), isTrue);
      expect(config.isStopPhrase('Hermes, stop'), isTrue);
      expect(config.isStopPhrase('OK stop.'), isTrue);
      expect(config.isStopPhrase('hey stop'), isTrue);
      expect(config.isStopPhrase('heyday stop'), isFalse);
      expect(config.isStopPhrase('okay stop'), isFalse);
      expect(config.isStopPhrase('hermes'), isFalse);
    });

    test('a profile list replaces the built-in list, ["stop"] included', () {
      final config = parse({
        'stop_phrases': ['Enough', 'that will do.'],
      });
      expect(config.isStopPhrase('enough'), isTrue);
      expect(config.isStopPhrase('That will do'), isTrue);
      expect(config.isStopPhrase('hang up'), isFalse);
      expect(config.isStopPhrase('goodbye'), isFalse);
      final stopOnly = parse({
        'stop_phrases': ['stop'],
      });
      expect(stopOnly.isStopPhrase('stop'), isTrue);
      expect(stopOnly.isStopPhrase('hang up'), isFalse);
      expect(stopOnly.isStopPhrase('goodbye'), isFalse);
    });

    test('a string is one phrase', () {
      final config = parse({'stop_phrases': 'Over and out'});
      expect(config.isStopPhrase('over and out!'), isTrue);
      expect(config.isStopPhrase('stop'), isFalse);
    });

    test('a malformed value gives the built-in list', () {
      for (final bad in [
        42,
        true,
        {'a': 1},
        [1, 2],
        [null],
        [''],
        ['   '],
      ]) {
        final config = parse({'stop_phrases': bad});
        expect(config.isStopPhrase('hang up'), isTrue, reason: '$bad');
        expect(config.isStopPhrase('goodbye'), isTrue, reason: '$bad');
      }
    });

    test('only an explicit empty list turns phrases off', () {
      final config = parse({'stop_phrases': <Object?>[]});
      expect(config.isStopPhrase('stop'), isFalse);
      expect(config.isStopPhrase('hang up'), isFalse);
    });

    test('a list with usable strings ignores the unusable entries', () {
      final config = parse({
        'stop_phrases': ['enough', 3, null, ''],
      });
      expect(config.isStopPhrase('enough'), isTrue);
      expect(config.isStopPhrase('stop'), isFalse);
    });

    test('the defaults are the built-in list with the shipped phrases', () {
      expect(const VoiceCallConfig().isStopPhrase('end the call'), isTrue);
      expect(
        const VoiceCallConfig().silence,
        const Duration(milliseconds: 900),
      );
    });
  });

  test('the repository reads the profile config without defaults', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/config', {
        'voice': {
          'silence_duration': 1.2,
          'stop_phrases': ['enough'],
          'barge_in': false,
        },
      });
    final config = await HermesChatRepository(server.client().raw)
        .voiceCallConfig(profile: 'work');
    expect(server.requests.single.queryParameters, {
      'profile': 'work',
      'include_defaults': false,
    });
    expect(config.silence, const Duration(milliseconds: 1200));
    expect(config.isStopPhrase('enough'), isTrue);
    expect(config.bargeIn, isFalse);
  });
}
