import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_toggled.dart';
import '../../widgets/named_icon_button.dart';

/// A compact inline audio player. A matching TTS input can be revealed as a
/// transcript; it stays collapsed without adding another row to the player.
class VoiceMessageView extends StatefulWidget {
  const VoiceMessageView({
    super.key,
    required this.name,
    required this.onToggle,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.onSeek,
    this.onSave,
    this.transcript,
    this.initiallyExpanded = false,
  });

  final String name;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final String? error;
  final VoidCallback? onToggle;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onSave;
  final String? transcript;
  final bool initiallyExpanded;

  @override
  State<VoiceMessageView> createState() => _VoiceMessageViewState();
}

class _VoiceMessageViewState extends State<VoiceMessageView> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.duration.inMilliseconds;
    final at = widget.position.inMilliseconds.clamp(0, total);
    final hasTranscript = widget.transcript?.trim().isNotEmpty == true;
    final action = widget.error != null
        ? 'Retry voice message'
        : widget.playing
        ? 'Pause voice message'
        : 'Play voice message';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.name,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(kHermesRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.loading)
                  const SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          semanticsLabel: 'Loading voice message',
                        ),
                      ),
                    ),
                  )
                else
                  NamedIconButton(
                    label: action,
                    icon: widget.error != null
                        ? AppIcons.refresh
                        : widget.playing
                        ? AppIcons.pause
                        : AppIcons.play,
                    color: scheme.primary,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    onPressed: widget.onToggle,
                  ),
                Expanded(
                  child: widget.error != null || widget.loading || total == 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            widget.error ??
                                (widget.loading
                                    ? 'Loading audio…'
                                    : 'Voice message'),
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.error != null
                                  ? scheme.error
                                  : context.hermesColors.subtleText,
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 44,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            child: Semantics(
                              label: 'Voice message position',
                              child: Slider(
                                value: at.toDouble(),
                                max: total.toDouble(),
                                semanticFormatterCallback: (value) =>
                                    '${formatVoiceTime(Duration(milliseconds: value.round()))} of ${formatVoiceTime(widget.duration)}',
                                onChanged: widget.onSeek == null
                                    ? null
                                    : (value) => widget.onSeek!(
                                        Duration(milliseconds: value.round()),
                                      ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (total > 0 && widget.error == null && !widget.loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${formatVoiceTime(widget.position)} / ${formatVoiceTime(widget.duration)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.hermesColors.subtleText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if (hasTranscript)
                  Semantics(
                    expanded: _expanded,
                    child: NamedIconButton(
                      label: 'Transcript',
                      tooltip: _expanded
                          ? 'Hide transcript'
                          : 'Show transcript',
                      icon: AppIcons.transcript,
                      iconSize: 18,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      onPressed: () {
                        DisclosureToggledNotification.send(context);
                        setState(() => _expanded = !_expanded);
                      },
                    ),
                  ),
                if (widget.onSave != null)
                  NamedIconButton(
                    label: 'Save voice message',
                    icon: AppIcons.download,
                    iconSize: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    onPressed: widget.onSave,
                  ),
              ],
            ),
            if (hasTranscript && _expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.transcript!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.hermesColors.subtleText,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String formatVoiceTime(Duration time) {
  final seconds = time.inSeconds.clamp(0, 1 << 31);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
