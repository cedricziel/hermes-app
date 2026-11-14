import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/whisper_hallucination.dart';

void main() {
  test('known silence inventions are dropped whole', () {
    for (final text in [
      'Thank you.',
      'thank you',
      'Thank you!',
      'Thanks for watching!',
      'Thank you for watching.',
      'Bye',
      'Bye.',
      'bye bye',
      'You',
      'The end.',
      'Please subscribe.',
      'Subtitles by the Amara.org community',
      'Thank you. Thank you. Thank you.',
      'you you you you',
      '  Thank you.  ',
    ]) {
      expect(isWhisperHallucination(text), isTrue, reason: text);
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
    ]) {
      expect(isWhisperHallucination(text), isFalse, reason: text);
    }
  });

  test('empty text is not a hallucination, it is dropped earlier', () {
    expect(isWhisperHallucination(''), isFalse);
    expect(isWhisperHallucination('...'), isFalse);
  });
}
