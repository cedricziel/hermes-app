import 'dart:math' as math;
import 'dart:typed_data';

/// Whether a transcript is the call's own reply heard back through the
/// microphone. No platform cancels all of it, so the first transcript after a
/// reply is compared with that reply; later ones never are.
///
/// A transcript matches when its similarity to the reply is at least
/// [threshold] (one minus the edit distance over the longer length, on the
/// words only, lowercased). A transcript of ten characters or more that is
/// shorter than the reply also matches when it resembles any stretch of the
/// reply of the same number of words, because the microphone often hears only
/// part of it. A shorter one is compared with the whole reply only, so a
/// spoken "Goodbye." is never taken for part of a long sentence that happens
/// to contain it.
class EchoGuard {
  /// How alike a transcript and the reply must be.
  static const threshold = 0.6;

  /// The shortest transcript compared with a stretch of the reply.
  static const minWindowLength = 10;

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
    if (_similarity(heard, reply) >= threshold) return true;
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
      if (_similarity(heard, window) >= threshold) return true;
    }
    return false;
  }

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
