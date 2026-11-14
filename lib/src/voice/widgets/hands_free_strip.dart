import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// What the microphone is doing while a hands-free call runs.
enum HandsFreeMicrophone { open, paused, muted, opening }

/// The pill that keeps a running microphone in sight: a dot, "Hands-free on"
/// and, after a middle dot, what the microphone is doing. The words carry the
/// state; the dot only backs them up (a filled recording dot when open, a grey
/// one when muted, a hollow one while paused or opening).
///
/// [onEnd] is the End action; null hides it, for a place where the call
/// screen already has End. At large text sizes the second half is dropped so
/// the pill stays on one line.
class HandsFreeStrip extends StatelessWidget {
  const HandsFreeStrip({super.key, required this.microphone, this.onEnd});

  final HandsFreeMicrophone microphone;
  final VoidCallback? onEnd;

  static const _largeText = 1.6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final second = switch (microphone) {
      HandsFreeMicrophone.open => l10n.voiceStripMicOpen,
      HandsFreeMicrophone.paused => l10n.voiceStripMicPaused,
      HandsFreeMicrophone.muted => l10n.voiceStripMicMuted,
      HandsFreeMicrophone.opening => l10n.voiceStripMicOpening,
    };
    final large = MediaQuery.textScalerOf(context).scale(1) >= _largeText;
    final spoken = '${l10n.voiceStripOn}, $second';
    final style = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
    );
    final onEnd = this.onEnd;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      child: Padding(
        padding: EdgeInsets.only(left: 14, right: onEnd == null ? 14 : 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  label: spoken,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Dot(microphone, colors),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: l10n.voiceStripOn),
                              if (!large)
                                TextSpan(
                                  text: ' · $second',
                                  style: style?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          style: style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onEnd != null) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: TextButton(
                    onPressed: onEnd,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      l10n.voiceStripEnd,
                      semanticsLabel: l10n.voiceCallEnd,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.microphone, this.colors);
  final HandsFreeMicrophone microphone;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    return switch (microphone) {
      HandsFreeMicrophone.open => DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.error),
        child: const SizedBox.square(dimension: size),
      ),
      HandsFreeMicrophone.muted => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.onSurfaceVariant,
        ),
        child: const SizedBox.square(dimension: size),
      ),
      HandsFreeMicrophone.paused || HandsFreeMicrophone.opening => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.onSurfaceVariant, width: 2),
        ),
        child: const SizedBox.square(dimension: size),
      ),
    };
  }
}
