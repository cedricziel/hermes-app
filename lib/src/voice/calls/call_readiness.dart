enum CallCheckId { microphone, input, output, connection }

enum CallCheckStatus { checking, ready, needsSetup, unavailable }

enum CallSetupAction { microphone, dictation, hermes }

class CallCheck {
  const CallCheck(this.id, this.status, this.detail, {this.action});
  final CallCheckId id;
  final CallCheckStatus status;
  final String detail;
  final CallSetupAction? action;

  String get title => switch (id) {
    CallCheckId.microphone => 'Microphone',
    CallCheckId.input => 'Speech recognition',
    CallCheckId.output => 'Spoken replies',
    CallCheckId.connection => 'Voice connection',
  };
}

class CallReadiness {
  const CallReadiness(this.checks, {this.useDeviceSpeech = false});
  static const checking = CallReadiness([
    CallCheck(
      CallCheckId.microphone,
      CallCheckStatus.checking,
      'Checking access…',
    ),
    CallCheck(
      CallCheckId.input,
      CallCheckStatus.checking,
      'Checking speech recognition…',
    ),
    CallCheck(
      CallCheckId.output,
      CallCheckStatus.checking,
      'Checking Hermes speech settings…',
    ),
    CallCheck(
      CallCheckId.connection,
      CallCheckStatus.checking,
      'Checking the voice connection…',
    ),
  ]);

  final List<CallCheck> checks;
  final bool useDeviceSpeech;
  bool get isChecking =>
      checks.any((c) => c.status == CallCheckStatus.checking);
  bool get ready =>
      checks.length == CallCheckId.values.length &&
      checks.every((c) => c.status == CallCheckStatus.ready);
  bool get canAskHermes =>
      checks.any((c) => c.action == CallSetupAction.hermes);

  /// Curated diagnostics only: never provider keys, URLs or raw server errors.
  String get setupPrompt =>
      '''Help me set up voice calls for this chat's Hermes profile.

The app's readiness checks found:
${checks.where((c) => c.status != CallCheckStatus.ready).map((c) => '- ${c.title}: ${c.detail}').join('\n')}

Check that this Hermes server supports GET /api/audio/voice-config and the authenticated /api/audio/speak-stream WebSocket. Verify a working text-to-speech provider for this profile. ${useDeviceSpeech ? 'Speech recognition uses Apple on this device.' : 'If speech recognition uses Hermes, also verify a speech-to-text provider for /api/audio/transcribe.'} Check any required server dependencies, including ffmpeg for decoding synthesized audio. Test the speech configuration and explain what is missing.

Explain proposed changes and ask me before installing packages, updating Hermes, changing providers or making paid test requests. Use secure credential setup when needed; do not ask me to paste secrets into this chat or print credentials. Device microphone permissions and Apple speech-language downloads must be handled on my device.''';
}
