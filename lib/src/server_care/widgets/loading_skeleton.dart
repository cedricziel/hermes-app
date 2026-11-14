import 'package:flutter/material.dart';

import '../../widgets/busy_bar.dart';

/// Line-shaped blocks standing in for rows that are loading. The whole thing
/// is one node for screen readers, named [label]; the blocks are decorative.
/// Under reduced motion the blocks do not pulse.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, required this.label, this.lines = 3});

  /// Read by screen readers, for example "Loading logs".
  final String label;
  final int lines;

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
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      container: true,
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FractionallySizedBox(
                      widthFactor: i.isOdd ? 0.7 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const SizedBox(height: 16),
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
