import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../dictation_controller.dart';

/// The line above the composer that says how a dictation ended, when it did
/// not end with text: nothing heard, a failure (with [onRetry] when the
/// recording was kept), no microphone access, or the device's speech model
/// gone.
class DictationNotice extends StatelessWidget {
  const DictationNotice({
    super.key,
    required this.phase,
    required this.onDismiss,
    this.onRetry,
  });

  final DictationPhase phase;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  /// Whether [phase] has a notice at all.
  static bool shows(DictationPhase phase) => switch (phase) {
    DictationPhase.failed ||
    DictationPhase.noSpeech ||
    DictationPhase.denied ||
    DictationPhase.modelMissing => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final failed = phase == DictationPhase.failed;
    final message = switch (phase) {
      DictationPhase.failed => 'Couldn’t transcribe the recording.',
      DictationPhase.noSpeech => 'No speech detected.',
      DictationPhase.denied =>
        'Microphone access is off. Allow it for Hermes in your device’s '
            'privacy settings.',
      DictationPhase.modelMissing =>
        'The speech model for your language isn’t on this device anymore. '
            'Download it again in the Dictation settings.',
      _ => '',
    };
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: failed ? scheme.error : context.hermesColors.subtleText,
              ),
            ),
          ),
          if (onRetry case final retry?)
            TextButton(onPressed: retry, child: const Text('Retry')),
          NamedIconButton(
            label: 'Dismiss',
            icon: AppIcons.close,
            iconSize: 18,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
