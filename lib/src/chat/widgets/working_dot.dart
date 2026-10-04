import 'package:flutter/material.dart';

/// The sidebar's mark for a thread a turn is running in: a small spinner,
/// announced to screen readers as Working.
class WorkingDot extends StatelessWidget {
  const WorkingDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Working',
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
