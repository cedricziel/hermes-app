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
  });

  static const none = VoiceSupport();

  factory VoiceSupport.fromJson(Object? body) {
    final json = body is Map ? body : const {};
    final stt = json['stt'];
    final tts = json['tts'];
    return VoiceSupport(
      speechToText: _usable(stt),
      liveTranscription: stt is Map && stt['streaming'] == true,
      textToSpeech: _usable(tts),
    );
  }

  /// Whether speech can be transcribed, which dictation needs.
  final bool speechToText;

  /// Whether text can be recognized while the user speaks
  /// (`/api/audio/transcribe-stream`), rather than only after.
  final bool liveTranscription;

  /// Whether replies can be spoken.
  final bool textToSpeech;

  static bool _usable(Object? section) =>
      section is Map &&
      !const {'stt disabled', 'no credentials'}.contains(section['reason']);

  @override
  String toString() =>
      'VoiceSupport(speechToText: $speechToText, '
      'liveTranscription: $liveTranscription, textToSpeech: $textToSpeech)';
}
