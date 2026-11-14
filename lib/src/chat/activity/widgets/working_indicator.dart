import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/platform_chrome.dart';
import '../../../widgets/busy_bar.dart';

/// A small spinner for "Hermes is working", [size] points square. It stops
/// turning when the system asks for less motion and is decorative: the words
/// next to it carry the status.
class WorkingIndicator extends StatelessWidget {
  const WorkingIndicator({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotionOf(context);
    final apple = platformChromeOf(context).isApple;
    final Widget indicator = apple
        ? (still
              ? CupertinoActivityIndicator.partiallyRevealed(
                  radius: size / 2,
                  progress: 1,
                )
              : CupertinoActivityIndicator(radius: size / 2))
        : CircularProgressIndicator(
            strokeWidth: size > 14 ? 2 : 1.5,
            value: still ? 0.75 : null,
          );
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('working-indicator'),
        width: size,
        height: size,
        child: Center(child: indicator),
      ),
    );
  }
}
