import 'dart:math' as math;
import 'dart:typed_data';

/// Whether a transcript is the call's own reply heard back through the
/// microphone. No platform cancels all of it, so the first transcript after a
/// reply is compared with that reply; later ones never are.
///
/// A transcript is an echo when both hold for the same stretch of the reply
/// (all of it, or, for a transcript of ten characters or more that is shorter
/// than the reply, any run of the same number of words, because the
/// microphone often hears only part of it):
///
/// 1. It is at least [threshold] alike: one minus the edit distance over the
///    longer length, on the words only, lowercased.
/// 2. It brings nothing new: at most one word in [wordsPerNewWord] is missing
///    from that stretch. A word is in it when it is the same word, or, from
///    four letters, at least [threshold] alike (a transposed letter, "Hannah"
///    for "Anna"); a shorter word has to be the same. The reply read back has
///    no new words, so "yes, goodbye" after a reply ending "Goodbye." is an
///    answer however alike the two are, and so is "Yes, send the email to
///    Anna" after "Shall I send the email to Anna?". A recognizer's filler
///    word in a long echo is within the allowance.
class EchoGuard {
  /// How alike a transcript and the reply must be.
  static const threshold = 0.6;

  /// The shortest transcript compared with a stretch of the reply.
  static const minWindowLength = 10;

  /// One word of a transcript may be new for each this many words in it.
  static const wordsPerNewWord = 8;

  /// The shortest word that matches another by likeness rather than exactly.
  static const _minFuzzyWord = 4;

  // A window compare is quadratic in the transcript, so a long one is compared
  // whole, and a long reply only by its end.
  static const _maxWindowTranscript = 200;
  static const _maxReply = 4000;

  String? _reply;

  /// The reply the call is speaking or just spoke. It replaces any earlier
  /// one and arms the guard for the next transcript.
  void spoken(String reply) => _reply = _words(reply);

  /// Whether [transcript], the first since [spoken], is the reply heard back.
  /// Spends the guard whatever the answer.
  bool isEcho(String transcript) {
    final reply = _reply;
    _reply = null;
    if (reply == null || reply.isEmpty) return false;
    final heard = _words(transcript);
    if (heard.isEmpty) return false;
    if (_matches(heard, reply)) return true;
    if (transcript.trim().length < minWindowLength ||
        heard.length >= reply.length ||
        heard.length > _maxWindowTranscript) {
      return false;
    }
    return _anyWindow(heard, reply);
  }

  bool _anyWindow(String heard, String reply) {
    final words = reply.split(' ');
    final count = heard.split(' ').length;
    if (count >= words.length) return false;
    for (var start = 0; start + count <= words.length; start++) {
      final window = words.sublist(start, start + count).join(' ');
      if (_matches(heard, window)) return true;
    }
    return false;
  }

  static bool _matches(String heard, String stretch) =>
      _similarity(heard, stretch) >= threshold && _addsNothing(heard, stretch);

  static bool _addsNothing(String heard, String stretch) {
    final known = stretch.split(' ');
    final words = heard.split(' ');
    var allowed = words.length ~/ wordsPerNewWord;
    for (final word in words) {
      if (known.any((other) => _sameWord(word, other))) continue;
      if (allowed-- == 0) return false;
    }
    return true;
  }

  static bool _sameWord(String a, String b) =>
      a == b ||
      (a.length >= _minFuzzyWord &&
          b.length >= _minFuzzyWord &&
          _similarity(a, b) >= threshold);

  static final _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static String _words(String text) {
    final words = text.toLowerCase().replaceAll(_notWord, ' ').trim();
    return words.length > _maxReply
        ? words.substring(words.length - _maxReply)
        : words;
  }

  static double _similarity(String a, String b) {
    final longer = math.max(a.length, b.length);
    if (longer == 0) return 0;
    // The distance is at least the difference in length.
    if ((a.length - b.length).abs() / longer > 1 - threshold) return 0;
    return 1 - _distance(a, b) / longer;
  }

  /// Levenshtein distance by code unit, two rows.
  static int _distance(String a, String b) {
    var previous = Uint32List(b.length + 1);
    var current = Uint32List(b.length + 1);
    for (var j = 0; j <= b.length; j++) {
      previous[j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= b.length; j++) {
        final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      (previous, current) = (current, previous);
    }
    return previous[b.length];
  }
}
