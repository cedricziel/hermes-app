/// Which voice features a profile's speech providers allow, read from
/// `GET /api/audio/voice-config`.
///
/// Hermes has no "available" flag, so this goes by the reason it gives for
/// relaying: a turned-off provider (`stt disabled`) or a cloud provider without
/// a key (`no credentials`) cannot work, and every other answer can. The
/// route may also hand out provider keys for client-direct use; only the flags
/// below are kept.
class VoiceSupport {
  const VoiceSupport({
    this.speechToText = false,
    this.liveTranscription = false,
    this.textToSpeech = false,
    this.configurationKnown = true,
  });

  static const none = VoiceSupport(configurationKnown: false);

  factory VoiceSupport.fromJson(Object? body) {
    final json = body is Map ? body : const {};
    final stt = json['stt'];
    final tts = json['tts'];
    return VoiceSupport(
      speechToText: _usable(stt),
      liveTranscription: stt is Map && stt['streaming'] == true,
      textToSpeech: _usable(tts),
      configurationKnown:
          stt is Map &&
          tts is Map &&
          ![stt['reason'], tts['reason']].any(
            (reason) =>
                reason == 'resolution error' || reason == 'resolution failed',
          ),
    );
  }

  /// Whether speech can be transcribed, which dictation needs.
  final bool speechToText;

  /// Whether text can be recognized while the user speaks
  /// (`/api/audio/transcribe-stream`), rather than only after.
  final bool liveTranscription;

  /// Whether replies can be spoken.
  final bool textToSpeech;

  /// False when the server could not resolve or report its speech settings.
  final bool configurationKnown;

  static bool _usable(Object? section) =>
      section is Map &&
      !const {
        'stt disabled',
        'tts disabled',
        'no credentials',
      }.contains(section['reason']);

  @override
  String toString() =>
      'VoiceSupport(speechToText: $speechToText, '
      'liveTranscription: $liveTranscription, textToSpeech: $textToSpeech)';
}
