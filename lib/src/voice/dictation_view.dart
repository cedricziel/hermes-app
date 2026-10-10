import 'package:flutter/foundation.dart';

import 'dictation_controller.dart';
import 'dictation_settings.dart';

/// What the composer shows of a dictation, and what its controls do.
class DictationView {
  const DictationView({
    required this.phase,
    this.levels = const [],
    this.elapsed = Duration.zero,
    this.canRetry = false,
    this.engine = DictationEngine.hermes,
    this.onSend,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onRetry,
    required this.onDismiss,
  });

  /// The view of [controller]'s current state; [onSend] ends the dictation
  /// and sends the draft.
  factory DictationView.of(
    DictationController controller, {
    VoidCallback? onSend,
  }) => DictationView(
    phase: controller.phase,
    levels: controller.levels,
    elapsed: controller.elapsed,
    canRetry: controller.canRetry,
    engine: controller.engine,
    onSend: onSend,
    onStart: controller.start,
    onStop: controller.stop,
    onCancel: controller.cancel,
    onRetry: controller.retry,
    onDismiss: controller.dismiss,
  );

  final DictationPhase phase;

  /// Recent input levels, oldest first, from 0 to 1.
  final List<double> levels;
  final Duration elapsed;
  final bool canRetry;
  final DictationEngine engine;

  /// Sends while dictating: stops the recording, then sends the draft with
  /// the transcript once it lands.
  final VoidCallback? onSend;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  /// Whether the waveform stands in for the text field.
  bool get active =>
      phase == DictationPhase.recording || phase == DictationPhase.settling;
}
