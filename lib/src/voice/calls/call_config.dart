import 'whisper_hallucination.dart' show trimTranscriptPunctuation;

/// What a call reads from the profile's `voice` config section, read once per
/// call with `include_defaults=false`, so a key the profile never set is
/// absent and the app's own default applies.
class VoiceCallConfig {
  const VoiceCallConfig({
    this.silence = defaultSilence,
    this.stopPhrases = defaultStopPhrases,
    this.bargeIn,
  });

  /// Reads [config], the body of `GET /api/config`. Anything that does not
  /// fit leaves the default for that key.
  factory VoiceCallConfig.fromJson(Object? config) {
    final voice = config is Map ? config['voice'] : null;
    if (voice is! Map) return const VoiceCallConfig();
    final silence = voice['silence_duration'];
    final barge = voice['barge_in'];
    return VoiceCallConfig(
      silence: silence is num && silence.isFinite
          ? Duration(
              milliseconds: (silence * 1000).round().clamp(
                minSilence.inMilliseconds,
                maxSilence.inMilliseconds,
              ),
            )
          : defaultSilence,
      stopPhrases: _phrases(voice['stop_phrases']),
      bargeIn: barge is bool ? barge : null,
    );
  }

  static const defaultSilence = Duration(milliseconds: 900);
  static const minSilence = Duration(milliseconds: 500);
  static const maxSilence = Duration(seconds: 3);

  /// Used while the profile sets no list, or a malformed one. Keeps the
  /// phrases the first version of the call knew ("hang up", "end call").
  static const defaultStopPhrases = [
    'stop',
    'stop listening',
    'stop it',
    'please stop',
    'that is all',
    'never mind',
    'end conversation',
    'end the call',
    'goodbye',
    'cancel',
    'hang up',
    'end call',
  ];

  /// How long a pause ends the utterance.
  final Duration silence;

  /// Lowercase and trimmed. Empty turns stop phrases off.
  final List<String> stopPhrases;

  /// The profile's `voice.barge_in`; null while it sets none.
  final bool? bargeIn;

  /// Whether [transcript] is a stop phrase: after lowercasing, trimming
  /// surrounding punctuation and one leading "hey hermes", "hermes", "ok" or
  /// "hey". No Unicode normalisation, as in Hermes.
  bool isStopPhrase(String transcript) {
    if (stopPhrases.isEmpty) return false;
    var text = _clean(transcript);
    // "Hey, Hermes, stop." takes two addresses off.
    for (var previous = ''; previous != text;) {
      previous = text;
      text = _withoutAddress(text);
    }
    return stopPhrases.contains(text);
  }
}

String _clean(String text) => trimTranscriptPunctuation(text.toLowerCase());

String _withoutAddress(String text) {
  for (final address in const ['hey hermes', 'hermes', 'ok', 'hey']) {
    if (text.length > address.length &&
        text.startsWith(address) &&
        !_isWordCharacter(text.codeUnitAt(address.length))) {
      return trimTranscriptPunctuation(text.substring(address.length));
    }
  }
  return text;
}

bool _isWordCharacter(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x61 && unit <= 0x7a) ||
    unit == 0x27 ||
    unit > 0x7f;

/// A profile list replaces the built-in one, a string is one phrase, and a
/// value of any other kind, or a list with nothing usable in it, is malformed
/// and leaves the built-in list. Only an explicit empty list is off.
List<String> _phrases(Object? value) {
  List<String>? clean(Iterable<Object?> items) => [
    for (final item in items)
      if (item is String && _clean(item).isNotEmpty) _clean(item),
  ];
  switch (value) {
    case null:
      return VoiceCallConfig.defaultStopPhrases;
    case String():
      final phrases = clean([value]);
      return phrases!.isEmpty ? VoiceCallConfig.defaultStopPhrases : phrases;
    case List() when value.isEmpty:
      return const [];
    case List():
      final phrases = clean(value)!;
      return phrases.isEmpty ? VoiceCallConfig.defaultStopPhrases : phrases;
    default:
      return VoiceCallConfig.defaultStopPhrases;
  }
}
