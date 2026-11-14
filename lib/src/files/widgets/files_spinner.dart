import 'package:flutter/material.dart';

import '../../widgets/busy_bar.dart';

/// A progress spinner that stands still under reduced motion: a part of the
/// ring is drawn and nothing turns. Always sized to [size].
class FilesSpinner extends StatelessWidget {
  const FilesSpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: size > 24 ? 3 : 2,
      value: reduceMotionOf(context) ? 0.7 : null,
    ),
  );
}
