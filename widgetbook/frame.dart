import 'package:flutter/material.dart';

/// Places a widget the way a chat thread or a board column would: a bounded
/// column at the top left, in a list, so its height is not stretched.
Widget frame(Widget child, {double maxWidth = 480}) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  ),
);

/// Places a screen-sized widget (a sidebar, an empty state) in the space the
/// viewport gives it, since a scrolling frame would leave it unbounded.
Widget fill(Widget child, {double? width}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, child: child),
);
