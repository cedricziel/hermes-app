import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';
import '../calls/call_phase.dart';
import 'voice_call_footer.dart';
import 'voice_orb.dart';

/// Which hint Speaking shows: where speaking over the reply interrupts it, the
/// tap alone does, or (desktop) the microphone is paused meanwhile.
enum VoiceSpeakingHint { tapOrTalk, tapOnly, micPaused }

/// Foreground presentation of an ongoing call. Leaving this view keeps the
/// call alive; ending it always uses the explicit end-call action.
///
/// The orb and the state word under it say what the call is doing; the hint
/// says what the user can do. Controls are round, with a label under each, and
/// End is a filled neutral circle, never red.
class VoiceCallView extends StatelessWidget {
  const VoiceCallView({
    super.key,
    required this.phase,
    required this.elapsed,
    required this.muted,
    required this.speaker,
    required this.route,
    required this.onMute,
    required this.onSpeaker,
    required this.onEnd,
    required this.onShowChat,
    this.caption = '',
    this.error,
    this.onAskHermes,
    this.helpBusy = false,
    this.sending = false,
    this.amplitude = 0,
    this.reduceMotion = false,
    this.showSpeaker = true,
    this.speakingHint = VoiceSpeakingHint.tapOrTalk,
    this.onInterrupt,
    this.notice,
    this.endedByUser = false,
    this.onStartNew,
    this.footer = VoiceCallFooter.none,
    this.capturePaused = false,
    this.stoppedWord = false,
  });
  final CallPhase phase;
  final Duration elapsed;
  final bool muted;
  final bool speaker;
  final String route;
  final String caption;
  final String? error;
  final VoidCallback? onAskHermes;
  final bool helpBusy;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onEnd;
  final VoidCallback onShowChat;

  /// Shows Sending whatever the phase says. [CallPhase.sending] does already.
  final bool sending;

  /// The input level while listening, the output level while speaking.
  final double amplitude;
  final bool reduceMotion;

  /// Speaker routing exists on iOS and Android only.
  final bool showSpeaker;
  final VoiceSpeakingHint speakingHint;

  /// Taps the orb while Hermes speaks; null leaves the orb inert.
  final VoidCallback? onInterrupt;

  /// A [VoiceCallNotice] for what just happened, above the controls.
  final Widget? notice;

  /// The call stopped because the user ended it: a check and "Call ended"
  /// instead of the stop square and "Stopped".
  final bool endedByUser;

  /// Offers "Start a new call" once stopped.
  final VoidCallback? onStartNew;
  final VoiceCallFooter footer;

  /// Waiting for you pauses the microphone, so speaking does nothing. Only a
  /// call that really pauses capture sets this; otherwise the hint stays
  /// neutral.
  final bool capturePaused;

  /// Says "Stopped" instead of "Call ended" or "Call interrupted", as the
  /// design does for the new stop reasons.
  final bool stoppedWord;

  VoiceOrbState _orb(bool ended) {
    if (ended) return VoiceOrbState.stopped;
    if (sending) return VoiceOrbState.sending;
    return switch (phase) {
      CallPhase.connecting => VoiceOrbState.connecting,
      CallPhase.listening =>
        muted ? VoiceOrbState.muted : VoiceOrbState.listening,
      CallPhase.sending => VoiceOrbState.sending,
      CallPhase.thinking => VoiceOrbState.thinking,
      CallPhase.speaking => VoiceOrbState.speaking,
      CallPhase.attention => VoiceOrbState.waiting,
      CallPhase.ended || CallPhase.failed => VoiceOrbState.stopped,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final ended = phase == CallPhase.ended || phase == CallPhase.failed;
    final orb = _orb(ended);
    final word = switch (orb) {
      VoiceOrbState.connecting => l10n.voiceCallStateConnecting,
      VoiceOrbState.listening => l10n.voiceCallStateListening,
      VoiceOrbState.muted => l10n.voiceCallStateMuted,
      VoiceOrbState.sending => l10n.voiceCallStateSending,
      VoiceOrbState.thinking => l10n.voiceCallStateThinking,
      VoiceOrbState.speaking => l10n.voiceCallStateSpeaking,
      VoiceOrbState.waiting => l10n.voiceCallStateWaiting,
      VoiceOrbState.stopped =>
        stoppedWord
            ? l10n.voiceCallStateStopped
            : phase == CallPhase.failed
            ? l10n.voiceCallStateInterrupted
            : l10n.voiceCallStateEnded,
    };
    final hint = switch (orb) {
      VoiceOrbState.connecting || VoiceOrbState.stopped => null,
      VoiceOrbState.listening => l10n.voiceCallHintListening,
      VoiceOrbState.muted => l10n.voiceCallHintMuted,
      VoiceOrbState.sending => l10n.voiceCallHintSending,
      VoiceOrbState.thinking => l10n.voiceCallHintThinking,
      VoiceOrbState.speaking => switch (speakingHint) {
        VoiceSpeakingHint.tapOrTalk =>
          onInterrupt != null
              ? l10n.voiceCallHintSpeakingTalk
              : l10n.voiceCallHintSpeakingTalkOnly,
        VoiceSpeakingHint.tapOnly => l10n.voiceCallHintSpeakingTap,
        VoiceSpeakingHint.micPaused => l10n.voiceCallHintSpeakingPaused,
      },
      VoiceOrbState.waiting =>
        capturePaused
            ? l10n.voiceCallHintWaiting
            : l10n.voiceCallHintWaitingNeutral,
    };
    final time =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final shown = error ?? caption;
    final connecting = phase == CallPhase.connecting;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onShowChat,
                    icon: Icon(AppIcons.expandMore.of(context)),
                    label: Text(l10n.voiceCallShowChat),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: VoiceOrb(
                    state: orb,
                    amplitude: amplitude,
                    reduceMotion: reduceMotion,
                    stoppedCheck: endedByUser,
                    onTap: orb == VoiceOrbState.speaking ? onInterrupt : null,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  time,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    shown,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: orb == VoiceOrbState.sending
                          ? FontStyle.italic
                          : null,
                    ),
                  ),
                ],
                if (notice != null) ...[const SizedBox(height: 16), notice!],
                const SizedBox(height: 24),
                if (!ended) ...[
                  Text(
                    route,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 28,
                    runSpacing: 16,
                    children: [
                      _Control(
                        label: muted
                            ? l10n.voiceCallUnmute
                            : l10n.voiceCallMute,
                        icon: muted ? AppIcons.micOff : AppIcons.mic,
                        selected: muted,
                        onPressed: connecting ? null : onMute,
                      ),
                      if (showSpeaker)
                        _Control(
                          label: l10n.voiceCallSpeaker,
                          icon: AppIcons.speaker,
                          selected: speaker,
                          onPressed: connecting ? null : onSpeaker,
                        ),
                      _Control(
                        label: l10n.voiceCallEnd,
                        icon: AppIcons.endCall,
                        filled: true,
                        onPressed: onEnd,
                      ),
                    ],
                  ),
                  if (footer != VoiceCallFooter.none) ...[
                    const SizedBox(height: 24),
                    VoiceCallFooterText(footer),
                  ],
                ] else ...[
                  FilledButton(
                    onPressed: onShowChat,
                    child: Text(l10n.voiceCallBackToChat),
                  ),
                  if (error != null && onAskHermes != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: helpBusy ? null : onAskHermes,
                      child: Text(l10n.voiceCallAskHermes),
                    ),
                  ],
                  if (onStartNew != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onStartNew,
                      child: Text(l10n.voiceCallStartNew),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.filled = false,
  });
  final String label;
  final AppIconSet icon;
  final VoidCallback? onPressed;
  final bool selected;

  /// The End circle: filled in the neutral inverse colours, never red.
  final bool filled;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = filled
        ? colors.inverseSurface
        : colors.surfaceContainerHighest;
    final foreground = filled ? colors.onInverseSurface : colors.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // A selected toggle is ringed, so End stays the only solid one.
              border: selected && !filled
                  ? Border.all(color: colors.onSurface, width: 2)
                  : null,
              color: onPressed == null
                  ? colors.surfaceContainerHighest
                  : background,
            ),
            child: NamedIconButton(
              label: label,
              icon: icon,
              onPressed: onPressed,
              isSelected: filled ? null : selected,
              visualDensity: VisualDensity.standard,
              color: foreground,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(child: Text(label)),
      ],
    );
  }
}
