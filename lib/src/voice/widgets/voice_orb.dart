import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';

/// What a call is doing, as the orb shows it. Each state has its own icon, so
/// no state depends on colour.
enum VoiceOrbState {
  connecting,
  listening,
  muted,
  sending,
  thinking,
  speaking,
  waiting,
  stopped,
}

/// The call's one round indicator: a 112 pt circle with a 2 pt ring and a 48 pt
/// icon for the state, and, once [amplitude] is given, two level rings behind
/// it that follow it (the input level while listening, the output level while
/// speaking).
///
/// It is a button only while [VoiceOrbState.speaking] and [onTap] is set; in
/// every other state it is not a target and carries no semantics, since the
/// state word beside it says the same thing.
class VoiceOrb extends StatelessWidget {
  const VoiceOrb({
    super.key,
    required this.state,
    this.amplitude,
    this.reduceMotion = false,
    this.onTap,
    this.stoppedCheck = false,
  });

  final VoiceOrbState state;

  /// The current level, 0 (silence) to 1 (loudest). Null draws no rings.
  final double? amplitude;

  /// Keeps the rings and the spinner still. The system's own setting is
  /// honoured as well.
  final bool reduceMotion;

  /// Interrupts the reply; only used while [state] is speaking.
  final VoidCallback? onTap;

  /// Shows a check instead of the stop square once the user ended the call.
  final bool stoppedCheck;

  static const diameter = 112.0;
  static const _iconSize = 48.0;
  static const _area = 168.0;

  bool get _tappable => state == VoiceOrbState.speaking && onTap != null;
  bool get _hasLevel =>
      amplitude != null &&
      (state == VoiceOrbState.listening || state == VoiceOrbState.speaking);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    final level = (amplitude ?? 0).clamp(0.0, 1.0);
    final disc = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.onSurface, width: 2),
      ),
      child: SizedBox.square(
        dimension: diameter,
        child: Center(child: _icon(context, colors, still)),
      ),
    );
    Widget orb = disc;
    if (_tappable) {
      orb = Semantics(
        button: true,
        label: context.l10n.voiceOrbInterrupt,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkResponse(
            onTap: onTap,
            customBorder: const CircleBorder(),
            radius: diameter / 2,
            child: disc,
          ),
        ),
      );
    } else {
      orb = ExcludeSemantics(child: disc);
    }
    return SizedBox.square(
      dimension: _area,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_hasLevel) ...[
            _Ring(
              scale: 1.28 + (still ? 0 : 0.22 * level),
              color: colors.onSurface.withValues(alpha: 0.06),
              animated: !still,
            ),
            _Ring(
              scale: 1.12 + (still ? 0 : 0.14 * level),
              color: colors.onSurface.withValues(alpha: 0.12),
              animated: !still,
            ),
          ],
          orb,
        ],
      ),
    );
  }

  Widget _icon(BuildContext context, ColorScheme colors, bool still) {
    final color = colors.onSurface;
    if (state == VoiceOrbState.connecting) {
      return ExcludeSemantics(
        child: CupertinoTheme(
          data: CupertinoThemeData(brightness: Theme.of(context).brightness),
          child: CupertinoActivityIndicator(
            radius: _iconSize / 2.4,
            color: color,
            animating: !still,
          ),
        ),
      );
    }
    final icon = switch (state) {
      VoiceOrbState.listening => AppIcons.mic,
      VoiceOrbState.muted => AppIcons.micOff,
      VoiceOrbState.sending => AppIcons.sendArrow,
      VoiceOrbState.thinking => AppIcons.more,
      VoiceOrbState.speaking => AppIcons.speaker,
      VoiceOrbState.waiting => AppIcons.chat,
      VoiceOrbState.stopped =>
        stoppedCheck ? AppIcons.check : AppIcons.stopRecording,
      VoiceOrbState.connecting => AppIcons.mic,
    };
    return Icon(icon.of(context), size: _iconSize, color: color);
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.scale,
    required this.color,
    required this.animated,
  });
  final double scale;
  final Color color;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final size = VoiceOrb.diameter * scale;
    final circle = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    if (!animated) return SizedBox.square(dimension: size, child: circle);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: size,
      height: size,
      child: circle,
    );
  }
}
