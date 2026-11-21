import 'package:flutter/material.dart';

import 'grouped_list.dart';

/// Whether a bordered text button at the end of a [GroupedRow] no longer fits
/// beside the row's title, so the row sets it on a line of its own
/// (`trailingBelow`). Where the button fits, the row stays as it is: this
/// answers false at the default text size on any width, and at a large text
/// size on a wide one.
///
/// [width] is the row's full width (a `LayoutBuilder` above the row gives it),
/// [leading] the width the row's leading widget takes with its gap, and
/// [actionChrome] the button's own padding and border on top of its label.
/// The title keeps at least its own width or a
/// quarter of the row.
bool trailingActionStacks(
  BuildContext context, {
  required double width,
  required String title,
  required String actionLabel,
  required TextStyle actionStyle,
  required double actionChrome,
  double leading = 0,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final metrics = GroupedMetrics.of(context);
  // At the default text size the row is as it always was.
  if (scaler.scale(metrics.titleSize) <= metrics.titleSize) return false;
  final theme = Theme.of(context);
  final direction = Directionality.of(context);
  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    try {
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  final body = theme.textTheme.bodyMedium ?? const TextStyle();
  final titleNeeds = measure(title, body.copyWith(fontSize: metrics.titleSize));
  final actionNeeds =
      measure(
        actionLabel,
        (theme.textTheme.labelLarge ?? const TextStyle()).merge(actionStyle),
      ) +
      actionChrome;
  // The row's padding on both sides and the gap before the button.
  final room = width - 2 * metrics.rowPadding - 8 - leading;
  final titleMin = titleNeeds < width / 4 ? titleNeeds : width / 4;
  return room - actionNeeds < titleMin;
}
