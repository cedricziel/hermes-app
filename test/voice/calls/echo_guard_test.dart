import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/echo_guard.dart';

void main() {
  const reply =
      'The weather in Berlin is cloudy today with a chance of rain in the evening.';

  test('nothing spoken yet: nothing is an echo', () {
    expect(EchoGuard().isEcho(reply), isFalse);
  });

  test('the reply heard back is an echo, whatever the case or punctuation', () {
    final guard = EchoGuard()..spoken(reply);
    expect(
      guard.isEcho(
        'the weather in berlin is cloudy today, with a chance '
        'of rain in the evening',
      ),
      isTrue,
    );
  });

  test('only the first transcript after the reply is checked', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('Remind me at five'), isFalse);
    expect(guard.isEcho(reply), isFalse, reason: 'the guard is spent');
    guard.spoken(reply);
    expect(guard.isEcho(reply), isTrue, reason: 'a new reply arms it again');
  });

  test(
    'a transcript that is the reply is dropped even when it is "Goodbye."',
    () {
      final guard = EchoGuard()..spoken('Goodbye.');
      expect(guard.isEcho('Goodbye.'), isTrue);
    },
  );

  test('a short transcript is not matched inside a longer reply', () {
    final guard = EchoGuard()..spoken('Okay, goodbye. Talk to you later.');
    expect(guard.isEcho('Goodbye.'), isFalse);
  });

  test('a stretch of a longer reply, ten characters or more, is an echo', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('weather in Berlin is cloudy today'), isTrue);
  });

  test('the end of the reply is an echo too', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('a chance of rain in the evening'), isTrue);
  });

  test('one misheard word still matches', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('weather in Berlin is cloudy toady'), isTrue);
  });

  test('something else of the same length is not an echo', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('please turn on the kitchen lights now'), isFalse);
  });

  test('a stretch shorter than ten characters is not matched', () {
    final guard = EchoGuard()..spoken(reply);
    expect(guard.isEcho('is cloudy'), isFalse);
  });

  test('similarity of 0.6 counts, 0.5 does not', () {
    // Equal lengths compare as a whole: four of ten characters differ.
    expect((EchoGuard()..spoken('abcdefghij')).isEcho('abcdefwxyz'), isTrue);
    expect((EchoGuard()..spoken('abcdefghij')).isEcho('abcdewxyzq'), isFalse);
  });

  test('a long transcript is compared with the whole reply only', () {
    // The window compare is quadratic, so it stops at 200 characters.
    final words = [for (var i = 0; i < 100; i++) 'word${i}x'];
    final slice = words.sublist(10, 45).join(' ');
    expect(slice.length, greaterThan(200));
    final guard = EchoGuard()..spoken(words.join(' '));
    expect(guard.isEcho(slice), isFalse);
    final shorter = words.sublist(10, 25).join(' ');
    expect(shorter.length, lessThan(200));
    expect((EchoGuard()..spoken(words.join(' '))).isEcho(shorter), isTrue);
  });

  test('an empty transcript or reply is no echo', () {
    expect((EchoGuard()..spoken('')).isEcho(''), isFalse);
    expect((EchoGuard()..spoken(reply)).isEcho('...'), isFalse);
  });

  test('works on text that is not Latin', () {
    final guard = EchoGuard()
      ..spoken('Das Wetter in Berlin ist heute wolkig, später regnet es.');
    expect(guard.isEcho('das wetter in berlin ist heute wolkig'), isTrue);
  });

  group('the boundary between an echo and an answer', () {
    // (name, reply, transcript, swallowed)
    const table = <(String, String, String, bool)>[
      // Heard back: dropped.
      (
        'the whole reply',
        'The weather in Berlin is cloudy today with a chance of rain.',
        'the weather in berlin is cloudy today with a chance of rain',
        true,
      ),
      (
        'the last sentence',
        'It is cloudy. I will remind you at five. Talk to you later.',
        'I will remind you at five. Talk to you later',
        true,
      ),
      (
        'a tail fragment with a transposed letter',
        'The weather in Berlin is cloudy today.',
        'weather in Berlin is cloudy toady',
        true,
      ),
      (
        'a name the recognizer heard differently',
        'Shall I send the email to Anna?',
        'shall I send the email to Hannah',
        true,
      ),
      ('a reply of one word, heard alone', 'Goodbye.', 'Goodbye.', true),
      (
        'nine words with one filler word in them',
        'I have turned the living room lights off now.',
        'I have turned the uh living room lights off',
        true,
      ),
      // An answer that shares the reply's last words: kept.
      (
        'yes, goodbye after a reply that ends in Goodbye.',
        'The reminder is set for five. Goodbye.',
        'Yes, goodbye.',
        false,
      ),
      (
        'yes, goodbye after a reply of just Goodbye.',
        'Goodbye.',
        'Yes, goodbye.',
        false,
      ),
      (
        'a yes that repeats the question',
        'Shall I send the email to Anna?',
        'Yes, send the email to Anna',
        false,
      ),
      (
        'the question repeated with a word added',
        'Shall I send the email to Anna?',
        'send the email to Anna please',
        false,
      ),
      (
        'a correction that keeps most of the wording',
        'Shall I send the email to Anna?',
        'No, send the email to Anna',
        false,
      ),
      (
        'ten words with two new ones',
        'I have turned the living room lights off now.',
        'I have turned the uh um living room lights off',
        false,
      ),
      (
        'unrelated words',
        'The weather in Berlin is cloudy today.',
        'please turn on the kitchen lights now',
        false,
      ),
    ];
    for (final (name, reply, transcript, swallowed) in table) {
      test('$name: ${swallowed ? 'dropped' : 'kept'}', () {
        expect((EchoGuard()..spoken(reply)).isEcho(transcript), swallowed);
      });
    }
  });
}
