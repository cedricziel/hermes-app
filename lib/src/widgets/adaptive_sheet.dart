import 'package:flutter/material.dart';

import '../theme/breakpoints.dart';
import 'dialog_presentation.dart';

/// Shows [builder] as a dialog on macOS and wide layouts, up to [maxWidth]
/// wide. Other compact layouts use a bottom sheet, with a drag handle when
/// [showDragHandle] is set and at most [maxSheetHeightFraction] of the screen
/// tall when that is set.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 520,
  bool showDragHandle = false,
  double? maxSheetHeightFraction,
}) {
  Widget dialogBuilder(BuildContext dialog) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: builder(dialog),
    ),
  );
  if (Theme.of(context).platform == TargetPlatform.macOS) {
    return showAppDialog<T>(context: context, builder: dialogBuilder);
  }
  return isWideLayout(context)
      ? showDialog<T>(context: context, builder: dialogBuilder)
      : showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: showDragHandle,
          constraints: maxSheetHeightFraction == null
              ? null
              : BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      maxSheetHeightFraction,
                ),
          builder: builder,
        );
}
