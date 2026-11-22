import 'package:flutter/material.dart';

import 'grouped_list.dart';

/// Whether a bordered text button at the end of a [GroupedRow] no longer fits
/// beside the row's title, so the row sets it on a line of its own
/// (`trailingBelow`). Where the button fits, the row stays as it is: this
/// answers false at the default text size on any width, and above it on a
/// width where the button fits.
///
/// [width] is the row's full width (a `LayoutBuilder` above the row gives it)
/// and [leading] the width the row's leading widget takes with its gap. The
/// button's width is its label in [buttonStyle] plus that style's horizontal
/// padding (the border is drawn inside it and adds no width), so it follows
/// the button the row draws. The title keeps at least its own width or a quarter
/// of the row.
///
/// The row cannot ask its own trailing widget for its width before it lays
/// out, which is why the caller passes the label and style.
bool trailingActionStacks(
  BuildContext context, {
  required double width,
  required String title,
  required String actionLabel,
  required ButtonStyle buttonStyle,
  double leading = 0,
}) {
  final metrics = GroupedMetrics.of(context);
  // At the default text size the row is as it always was.
  if (MediaQuery.textScalerOf(context).scale(metrics.titleSize) <=
      metrics.titleSize) {
    return false;
  }
  final theme = Theme.of(context);
  final body = theme.textTheme.bodyMedium ?? const TextStyle();
  final titleNeeds = measureRowText(
    context,
    title,
    body.copyWith(fontSize: metrics.titleSize),
  );
  final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle()).merge(
    buttonStyle.textStyle?.resolve({}),
  );
  final padding = buttonStyle.padding?.resolve({}) ?? EdgeInsets.zero;
  final actionNeeds =
      measureRowText(context, actionLabel, labelStyle) + padding.horizontal;
  // The row's padding on both sides and the gap before the button.
  final room = width - 2 * metrics.rowPadding - 8 - leading;
  final titleMin = titleNeeds < width / 4 ? titleNeeds : width / 4;
  return room - actionNeeds < titleMin;
}
