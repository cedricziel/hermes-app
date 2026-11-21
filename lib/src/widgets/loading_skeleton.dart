import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hermes_theme.dart';
import 'busy_bar.dart';

/// Line-shaped blocks standing in for rows that are loading. The whole thing
/// is one node for screen readers, named [label]; the blocks are decorative.
/// The blocks scale with the text size, and in a box of finite height only the
/// whole lines that fit are drawn (at least one; a box shorter than that clips
/// it), never a cut bar and never a scroll view. The default colour is
/// [skeletonBarColor]. Under reduced motion they do not
/// pulse; otherwise they pulse for as long as the skeleton is on screen.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    required this.label,
    this.lines = 3,
    this.color,
    this.liveRegion = false,
  });

  /// Read by screen readers, for example "Loading logs".
  final String label;
  final int lines;

  /// The bars' colour, for a surface that is the default's own colour.
  final Color? color;

  /// Announces [label] politely once, when the skeleton appears.
  final bool liveRegion;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? skeletonBarColor(Theme.of(context).brightness);
    // Bars and gaps grow with the text size, like the rows they stand in for.
    final scaler = MediaQuery.textScalerOf(context);
    final barHeight = scaler.scale(16);
    final gap = scaler.scale(8);
    return Semantics(
      container: true,
      liveRegion: widget.liveRegion,
      label: widget.label,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Only whole lines that fit, at least one; never a cut bar.
            var lines = widget.lines;
            if (constraints.maxHeight.isFinite) {
              final fit = (constraints.maxHeight / (barHeight + 2 * gap))
                  .floor();
              lines = math.min(lines, math.max(1, fit));
            }
            final bounded = constraints.maxHeight.isFinite;
            final body = AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Opacity(
                opacity: 1 - 0.2 * _pulse.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lines; i++)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: gap),
                        child: FractionallySizedBox(
                          widthFactor: i.isOdd ? 0.7 : 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SizedBox(height: barHeight),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            // A box shorter than one line clips that line instead of
            // overflowing.
            // The box is sized to its lines (OverflowBox alone would take the
            // parent's biggest size, filling a Center or a fixed area).
            return bounded
                ? SizedBox(
                    height: math.min(
                      constraints.maxHeight,
                      lines * (barHeight + 2 * gap),
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: body,
                      ),
                    ),
                  )
                : body;
          },
        ),
      ),
    );
  }
}
