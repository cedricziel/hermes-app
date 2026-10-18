import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../voice_recording_view.dart';

class VoiceRecordingStatus extends StatelessWidget {
  const VoiceRecordingStatus({super.key, required this.recording});
  final VoiceRecordingView recording;

  @override
  Widget build(BuildContext context) {
    final elapsed = recording.elapsed;
    final time =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final label = switch (recording.phase) {
      VoiceRecordingPhase.preparing => 'Preparing microphone…',
      VoiceRecordingPhase.attaching => 'Attaching recording…',
      _ => 'Release to attach · $time',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        maxLines: 2,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: recording.phase == VoiceRecordingPhase.recording
              ? Theme.of(context).colorScheme.error
              : context.hermesColors.subtleText,
        ),
      ),
    );
  }
}

/// Keep the same gesture recognizer mounted through recording state changes.
/// A long press wins the button's tap recognizer, so release never sends.
class HoldToRecordSend extends StatefulWidget {
  const HoldToRecordSend({
    super.key,
    required this.recording,
    required this.onSend,
  });
  final VoiceRecordingView? recording;
  final VoidCallback? onSend;

  @override
  State<HoldToRecordSend> createState() => _HoldToRecordSendState();
}

class _HoldToRecordSendState extends State<HoldToRecordSend> {
  bool _holding = false;

  @override
  void dispose() {
    if (_holding) widget.recording?.onCancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;
    final onSend = widget.onSend;
    final scheme = Theme.of(context).colorScheme;
    final active = recording?.active == true;
    final finishing = recording?.phase == VoiceRecordingPhase.attaching;
    final onPressed = finishing
        ? null
        : active
        ? recording!.onFinish
        : onSend ?? (recording == null ? null : () {});
    return Semantics(
      label: active ? 'Attach voice message' : 'Send',
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      onTap: onPressed,
      hint: recording == null
          ? null
          : 'Touch and hold to record a voice message. Release to attach.',
      onLongPress: recording == null || active ? null : recording.onStart,
      child: GestureDetector(
        excludeFromSemantics: true,
        onLongPressStart: recording == null
            ? null
            : (_) {
                if (!active) {
                  _holding = true;
                  recording.onStart();
                }
              },
        onLongPressEnd: recording == null
            ? null
            : (_) {
                if (_holding) {
                  _holding = false;
                  recording.onFinish();
                }
              },
        onLongPressCancel: () {
          if (_holding) {
            _holding = false;
            recording?.onCancel();
          }
        },
        child: TooltipTheme(
          // The send button owns the long press; a touch tooltip must not
          // win the gesture arena and swallow recording.
          data: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
          child: NamedIconButton(
            label: active ? 'Attach voice message' : 'Send',
            tooltip: recording == null
                ? null
                : active
                ? 'Release to attach'
                : 'Send · Hold to record',
            icon: active ? AppIcons.mic : AppIcons.sendArrow,
            filled: true,
            style: IconButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              disabledForegroundColor: context.hermesColors.subtleText,
            ),
            // A screen reader can start with the long-press action, then tap
            // to finish. Empty short taps keep the draft untouched.
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
