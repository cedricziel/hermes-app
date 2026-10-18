import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/busy_bar.dart' show reduceMotionOf;

/// A quiet sweep through the thinking label, respecting system Reduce Motion.
class ThinkingShimmer extends StatefulWidget {
  const ThinkingShimmer({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<ThinkingShimmer> createState() => _ThinkingShimmerState();
}

class _ThinkingShimmerState extends State<ThinkingShimmer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    if (widget.active &&
        !reduceMotionOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(_sync);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active ||
        reduceMotionOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return widget.child;
    }
    final muted = context.hermesColors.subtleText;
    final highlight = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-3 + _animation.value * 6, 0),
          end: Alignment(-1 + _animation.value * 6, 0),
          colors: [muted, highlight, muted],
          stops: const [0.2, 0.5, 0.8],
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}
