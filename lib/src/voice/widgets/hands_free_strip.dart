import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';

/// What the microphone is doing while a hands-free call runs.
enum HandsFreeMicrophone {
  open,
  paused,
  muted,
  opening,

  /// The call ended without confirming that the microphone closed. The strip
  /// says so in one phrase in place of "Hands-free on".
  mayBeOpen,
}

/// The pill that keeps a running microphone in sight: a dot, "Hands-free on"
/// and, after a middle dot, what the microphone is doing. The words carry the
/// state; the dot only backs them up (a filled recording dot when open, a pause mark
/// while paused, a slashed microphone when muted, a hollow ring while opening).
///
/// [onEnd] is the End action; null hides it, for a place where the call
/// screen already has End. At large text sizes the second half is dropped so
/// the pill stays on one line.
class HandsFreeStrip extends StatelessWidget {
  const HandsFreeStrip({
    super.key,
    required this.microphone,
    this.onEnd,
    this.onDismiss,
  });

  final HandsFreeMicrophone microphone;
  final VoidCallback? onEnd;

  /// Closes the strip's "may still be open" warning; the same 44 pt place as
  /// End, for the state that has no call left to end.
  final VoidCallback? onDismiss;

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
      HandsFreeMicrophone.mayBeOpen => l10n.voiceStripMicMayBeOpen,
    };
    final unconfirmed = microphone == HandsFreeMicrophone.mayBeOpen;
    final large = MediaQuery.textScalerOf(context).scale(1) >= _largeText;
    final spoken = unconfirmed ? second : '${l10n.voiceStripOn}, $second';
    final style = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
    );
    final onEnd = this.onEnd ?? onDismiss;
    final endLabel = this.onEnd == null
        ? l10n.voiceStripDismiss
        : l10n.voiceStripEnd;
    final endSemantics = this.onEnd == null
        ? l10n.voiceStripDismiss
        : l10n.voiceCallEnd;
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
                              TextSpan(
                                text: unconfirmed ? second : l10n.voiceStripOn,
                              ),
                              if (!large && !unconfirmed)
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
                    child: Text(endLabel, semanticsLabel: endSemantics),
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

/// The glyph before the words. Its shape differs by state, so the state
/// survives when the second half of the pill is dropped: a filled recording
/// dot when open, a pause mark while paused, a slashed microphone when muted
/// and a hollow ring while opening.
class _Dot extends StatelessWidget {
  const _Dot(this.microphone, this.colors);
  final HandsFreeMicrophone microphone;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    const size = 14.0;
    return SizedBox.square(
      dimension: size,
      child: switch (microphone) {
        HandsFreeMicrophone.open => Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.error,
            ),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
        HandsFreeMicrophone.muted => Icon(
          AppIcons.micOff.of(context),
          size: size,
          color: colors.onSurfaceVariant,
        ),
        HandsFreeMicrophone.paused => Icon(
          AppIcons.pause.of(context),
          size: size,
          color: colors.onSurfaceVariant,
        ),
        HandsFreeMicrophone.mayBeOpen => Icon(
          AppIcons.warning.of(context),
          size: size,
          color: colors.error,
        ),
        HandsFreeMicrophone.opening => Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.onSurfaceVariant, width: 2),
            ),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
      },
    );
  }
}
