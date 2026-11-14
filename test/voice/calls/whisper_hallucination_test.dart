import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/whisper_hallucination.dart';

void main() {
  test('known silence inventions are dropped whole', () {
    for (final text in [
      'Thank you.',
      'thank you',
      'Thank you!',
      'Thank you!!',
      'Thanks for watching!',
      'Thank you for watching.',
      'Subscribe to my channel',
      'Like and subscribe.',
      'Bye',
      'Bye.',
      'bye bye',
      'You',
      'The end.',
      'Please subscribe.',
      'Amara.org',
      "Sous-titres réalisés par la communauté d'Amara.org",
      'Продолжение следует...',
      'ご視聴ありがとうございました',
      '  Thank you.  ',
    ]) {
      expect(isWhisperHallucination(text), isTrue, reason: text);
    }
  });

  test('the repeat rule takes only its own words', () {
    for (final text in [
      'Thank you. Thank you. Thank you.',
      'you you you you',
      'Thanks, thanks!',
      'ok',
      'Okay.',
      'OK. Okay. Ok.',
      'bye. bye. thank you',
      '...',
    ]) {
      expect(isWhisperHallucination(text), isTrue, reason: text);
    }
    // Any other phrase, however often repeated, is a real sentence.
    for (final text in [
      'stop stop stop',
      'hello hello hello',
      'thank you very much',
      'bye-bye',
    ]) {
      expect(isWhisperHallucination(text), isFalse, reason: text);
    }
  });

  test('real sentences are never dropped, only whole-transcript matches', () {
    for (final text in [
      'Thank you for the summary, now check my calendar',
      'Bye the way, what is next?',
      'Goodbye',
      'What do you think?',
      'Remind me at five',
      'Stop',
      'thank you very much for your help with the report',
      'Thank you?',
      'Subtitles by the Amara.org community',
    ]) {
      expect(isWhisperHallucination(text), isFalse, reason: text);
    }
  });

  test('empty text is an invention, as in Hermes', () {
    expect(isWhisperHallucination(''), isTrue);
    expect(isWhisperHallucination('   '), isTrue);
  });
}
