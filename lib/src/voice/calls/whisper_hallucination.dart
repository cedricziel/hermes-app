/// Text a speech recognizer invents for silence or room noise. A call that
/// sent these would act on words nobody said, so such a transcript is dropped
/// without a notice.
///
/// A port of `is_whisper_hallucination` in Hermes' `tools/voice_mode_transcript.py`
/// (revision `d923a5e`, the one `openapi/HERMES_REF` pins): the whole
/// transcript has to match, never a part of a longer sentence, and trailing
/// `.` and `!` are ignored. Like Hermes it takes an empty transcript, a
/// transcript of dots and commas and a lone "ok" or "okay" for inventions.
bool isWhisperHallucination(String transcript) {
  final cleaned = transcript.trim().toLowerCase();
  if (cleaned.isEmpty) return true;
  return _known.contains(cleaned.replaceAll(_trailingMarks, '')) ||
      _repeat.hasMatch(cleaned);
}

/// Trims the punctuation Hermes' own matchers trim: `.,!?;: "'`.
String trimTranscriptPunctuation(String text) => text.replaceAll(_edges, '');

final _edges = RegExp('^[.,!?;: "\']+|[.,!?;: "\']+\$');

final _trailingMarks = RegExp(r'[.!]+$');

/// Hermes' `WHISPER_HALLUCINATIONS`, in its order.
const _known = {
  'thank you',
  'thanks for watching',
  'subscribe to my channel',
  'like and subscribe',
  'please subscribe',
  'thank you for watching',
  'bye',
  'you',
  'the end',
  // Non-English inventions on silence.
  'продолжение следует',
  'sous-titres',
  "sous-titres réalisés par la communauté d'amara.org",
  'sottotitoli creati dalla comunità amara.org',
  'untertitel von stephanie geiges',
  'amara.org',
  'www.mooji.org',
  'ご視聴ありがとうございました',
};

/// Hermes' `_HALLUCINATION_REPEAT_RE`: a transcript made only of these words,
/// dots, commas, exclamation marks and spaces ("Thank you. Thank you.").
final _repeat = RegExp(
  r'^(?:thank you|thanks|bye|you|ok|okay|the end|\.|\s|,|!)+$',
  caseSensitive: false,
);
