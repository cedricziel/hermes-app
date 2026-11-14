/// Text a speech recognizer invents for silence or room noise. A call that
/// sent these would act on words nobody said, so such a transcript is dropped
/// without a notice.
///
/// A port of `is_whisper_hallucination` in Hermes' `voice_mode_transcript.py`:
/// the whole transcript has to match, never a part of a longer sentence.
bool isWhisperHallucination(String transcript) {
  final text = trimTranscriptPunctuation(transcript.toLowerCase());
  if (text.isEmpty) return false;
  if (_known.contains(text)) return true;
  return _patterns.any((pattern) => pattern.hasMatch(text));
}

/// Trims the punctuation Hermes' own matchers trim: `.,!?;: "'`.
String trimTranscriptPunctuation(String text) => text.replaceAll(_edges, '');

final _edges = RegExp('^[.,!?;: "\']+|[.,!?;: "\']+\$');

const _known = {
  'thank you',
  'thank you very much',
  'thank you so much',
  'thanks',
  'thanks for watching',
  'thank you for watching',
  'thank you so much for watching',
  'thanks for listening',
  'thank you for listening',
  'thank you for your time',
  'please subscribe',
  'subscribe',
  'like and subscribe',
  'subscribe to my channel',
  'bye',
  'bye bye',
  'bye-bye',
  'you',
  'the end',
  'see you next time',
  'see you in the next video',
  'see you later',
};

final _patterns = [
  // Subtitle credits Whisper learned from video captions.
  RegExp(r'^(?:subtitles?|captions?|transcribed|translated) by\b'),
  RegExp(r'\bamara\.org\b'),
  // The same short phrase over and over, three times or more.
  RegExp(r'^(.{1,30}?)(?:[\s.,!?]+\1){2,}$'),
];
