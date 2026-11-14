import 'package:flutter/material.dart';

import '../../widgets/busy_bar.dart';

/// A progress spinner that stands still under reduced motion: a part of the
/// ring is drawn and nothing turns. Always sized to [size].
class FilesSpinner extends StatelessWidget {
  const FilesSpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotionOf(context);
    // A drawn arc of a fixed length would be read out as "70 percent"; the
    // words next to the spinner say what is going on.
    return ExcludeSemantics(
      excluding: still,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: size > 24 ? 3 : 2,
          value: still ? 0.7 : null,
        ),
      ),
    );
  }
}
