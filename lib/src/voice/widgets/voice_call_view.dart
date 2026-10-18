import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';
import '../calls/call_phase.dart';

/// Foreground presentation of an ongoing call. Leaving this view keeps the
/// call alive; ending it always uses the explicit end-call action.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ended = phase == CallPhase.ended || phase == CallPhase.failed;
    final status = switch (phase) {
      CallPhase.connecting => 'Connecting…',
      CallPhase.listening => muted ? 'Microphone muted' : 'Listening',
      CallPhase.transcribing => 'Understanding…',
      CallPhase.thinking => 'Hermes is thinking…',
      CallPhase.speaking => 'Hermes is speaking',
      CallPhase.attention => 'Hermes needs your input in chat',
      CallPhase.ended => 'Call ended',
      CallPhase.failed => 'Call interrupted',
    };
    final time =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onShowChat,
                    icon: Icon(AppIcons.expandMore.of(context)),
                    label: const Text('Show chat'),
                  ),
                ),
                const SizedBox(height: 44),
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    AppIcons.mic.of(context),
                    size: 44,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Hermes', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      error ?? caption,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Control(
                        label: muted ? 'Unmute' : 'Mute',
                        icon: muted ? AppIcons.micOff : AppIcons.mic,
                        selected: muted,
                        onPressed: phase == CallPhase.connecting
                            ? null
                            : onMute,
                      ),
                      _Control(
                        label: 'Speaker',
                        icon: AppIcons.speaker,
                        selected: speaker,
                        onPressed: phase == CallPhase.connecting
                            ? null
                            : onSpeaker,
                      ),
                      _Control(
                        label: 'End call',
                        icon: AppIcons.endCall,
                        destructive: true,
                        onPressed: onEnd,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Speak naturally. Pause to send. You can interrupt Hermes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  if (error != null && onAskHermes != null)
                    FilledButton(
                      onPressed: helpBusy ? null : onAskHermes,
                      child: const Text('Ask Hermes for help'),
                    ),
                  TextButton(
                    onPressed: onShowChat,
                    child: const Text('Back to chat'),
                  ),
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
    this.destructive = false,
  });
  final String label;
  final AppIconSet icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: destructive
                  ? colors.error
                  : selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
            ),
            child: NamedIconButton(
              label: label,
              icon: icon,
              onPressed: onPressed,
              isSelected: destructive ? null : selected,
              color: destructive
                  ? colors.onError
                  : selected
                  ? colors.onPrimaryContainer
                  : colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
