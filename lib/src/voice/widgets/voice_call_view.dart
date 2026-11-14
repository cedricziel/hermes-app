import 'dart:math' as math;

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
    this.amplitude,
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

  /// The user's words are being prepared for Hermes. It is not a phase yet, so
  /// the caller says so; until then [CallPhase.transcribing] reads as thinking.
  final bool sending;

  /// The input level while listening, the output level while speaking. Null
  /// draws no level rings: nothing feeds a level yet, and a ring that never
  /// moves would only look like one that does.
  final double? amplitude;
  final bool reduceMotion;

  /// Speaker routing exists on iOS and Android only.
  final bool showSpeaker;
  final VoiceSpeakingHint speakingHint;

  /// Taps the orb while Hermes speaks; null leaves the orb inert.
  final VoidCallback? onInterrupt;

  /// A [VoiceCallNotice] for what just happened. It shares the slot above the
  /// controls with the caption, so it is always in view.
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
      CallPhase.transcribing || CallPhase.thinking => VoiceOrbState.thinking,
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
    final showChat = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onShowChat,
        icon: Icon(AppIcons.expandMore.of(context)),
        label: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Text(l10n.voiceCallShowChat),
        ),
      ),
    );
    Widget stateBlock({required bool withOrb}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withOrb) ...[
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
        ],
        Semantics(
          liveRegion: true,
          // Shrinks rather than breaking a word in a narrow column.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
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
      ],
    );
    final captionText = shown.isEmpty
        ? null
        : Text(
            shown,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: orb == VoiceOrbState.sending ? FontStyle.italic : null,
            ),
          );
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?notice,
        if (notice != null && captionText != null) const SizedBox(height: 12),
        ?captionText,
      ],
    );
    // Right above the controls: the notice first, in full, then the caption,
    // which shows its last lines when it is long. Short content is in view; a
    // longer text scrolls inside the slot. The controls sit below it, so
    // however tall the slot gets they stay where they are.
    Widget slot(double maxHeight) {
      final reserved = math.min(
        MediaQuery.textScalerOf(context).scale(24) * 4,
        maxHeight * 0.18,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: reserved,
          maxHeight: math.max(reserved, maxHeight * 0.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null)
              Flexible(
                flex: 3,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [notice!],
                ),
              ),
            if (notice != null && captionText != null)
              const SizedBox(height: 8),
            if (captionText != null)
              Flexible(
                flex: 2,
                child: ListView(
                  shrinkWrap: true,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  children: [captionText],
                ),
              ),
          ],
        ),
      );
    }

    // The controls sit below the scrolling part, so a caption, a notice or a
    // larger text size never moves End.
    final bottom = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ended) ...[
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Text(
              route,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Fixed-width cells: a longer label (Unmute) never moves End.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Control(
                label: muted ? l10n.voiceCallUnmute : l10n.voiceCallMute,
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
    );
    Widget capped(Widget child, double maxHeight) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(child: child),
    );
    const sideGutter = EdgeInsets.symmetric(horizontal: 24);
    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) {
            // Under a scroll view of its own (the catalog) nothing bounds the
            // height, so everything simply follows the content.
            if (!box.hasBoundedHeight) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      showChat,
                      const SizedBox(height: 16),
                      stateBlock(withOrb: true),
                      const SizedBox(height: 16),
                      words,
                      const SizedBox(height: 24),
                      bottom,
                    ],
                  ),
                ),
              );
            }
            if (box.maxHeight < 600) {
              // Short windows (a phone on its side): the state on the left,
              // what was heard and the controls on the right, so the state
              // word is never below the fold.
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                          child: stateBlock(withOrb: true),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, right: 12),
                            child: showChat,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: Center(child: words),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 24, 12),
                            child: capped(bottom, box.maxHeight * 0.65),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Padding(padding: sideGutter, child: showChat),
                  Expanded(
                    // The orb goes first when the room is short, so the state
                    // word is always the first thing in view.
                    child: LayoutBuilder(
                      builder: (context, top) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: stateBlock(
                          withOrb:
                              top.maxHeight >=
                              VoiceOrb.diameter +
                                  56 +
                                  MediaQuery.textScalerOf(context).scale(150),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: sideGutter, child: slot(box.maxHeight)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: capped(bottom, box.maxHeight * 0.45),
                  ),
                ],
              ),
            );
          },
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
    return SizedBox(
      width: 88,
      child: Column(
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
          // The visible label stops growing at 1.15x so the three controls
          // stay on one row; screen readers use the button's own name.
          ExcludeSemantics(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
