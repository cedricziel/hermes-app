import 'package:flutter/foundation.dart';

/// Recording an audio attachment is separate from speech-to-text dictation.
enum VoiceRecordingPhase { idle, preparing, recording, attaching }

/// Plain state and actions for the composer's hold-to-record gesture.
class VoiceRecordingView {
  const VoiceRecordingView({
    this.phase = VoiceRecordingPhase.idle,
    this.elapsed = Duration.zero,
    required this.onStart,
    required this.onFinish,
    required this.onCancel,
  });

  final VoiceRecordingPhase phase;
  final Duration elapsed;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  bool get active => phase != VoiceRecordingPhase.idle;
}
