import 'package:flutter/material.dart';

import 'busy_bar.dart';

/// Line-shaped blocks standing in for rows that are loading. The whole thing
/// is one node for screen readers, named [label]; the blocks are decorative.
/// The blocks scale with the text size. Under reduced motion they do not
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
        widget.color ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    // Bars and gaps grow with the text size, like the rows they stand in for.
    final scaler = MediaQuery.textScalerOf(context);
    final barHeight = scaler.scale(16);
    final gap = scaler.scale(8);
    return Semantics(
      container: true,
      liveRegion: widget.liveRegion,
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Opacity(
            opacity: 1 - 0.4 * _pulse.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.lines; i++)
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
        ),
      ),
    );
  }
}
