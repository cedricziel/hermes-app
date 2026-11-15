import 'package:flutter/material.dart';

import '../../../widgets/grouped_list.dart';
import '../../../widgets/motion_spinner.dart';

/// The size and spacing the note and status lines under the editor share.
///
/// The icon (or spinner) is as tall as the line's text plus a little and
/// scales with the text size, so it does not shrink next to large text; the
/// gap to the text is fixed.
abstract final class SoulLineMetrics {
  /// The gap between the icon and the text.
  static const double gap = 6;

  /// The icon's side, scaled with the text size.
  static double iconExtent(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .scale(GroupedMetrics.of(context).footerSize + 3);

  /// A [MotionSpinner] drawn as large as [iconExtent].
  static Widget spinner(BuildContext context) {
    final extent = iconExtent(context);
    return SizedBox.square(
      dimension: extent,
      child: const FittedBox(child: MotionSpinner()),
    );
  }
}
