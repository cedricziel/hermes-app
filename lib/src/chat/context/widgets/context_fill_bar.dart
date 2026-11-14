import 'package:flutter/material.dart';

import '../../../widgets/busy_bar.dart';

/// A rounded fill bar. It is decorative: the text beside it carries the
/// meaning, so a screen reader skips it. It fills without animation under
/// reduced motion.
class ContextFillBar extends StatelessWidget {
  const ContextFillBar({
    super.key,
    required this.fraction,
    required this.height,
    required this.color,
    this.animate = true,
  });

  /// 0 to 1; anything else is clamped.
  final double fraction;
  final double height;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    final value = fraction.clamp(0.0, 1.0);
    final duration = animate && !reduceMotionOf(context)
        ? const Duration(milliseconds: 300)
        : Duration.zero;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: track,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: duration,
              builder: (context, shown, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: shown,
                  child: ColoredBox(
                    color: color,
                    child: SizedBox(height: height),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
