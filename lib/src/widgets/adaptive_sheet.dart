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
              : _sheetConstraints(context, maxSheetHeightFraction),
          builder: builder,
        );
}

/// Caps the sheet's height without dropping its width cap: passing
/// `constraints` replaces the theme's, so the theme's (or Material 3's 640)
/// maximum width is carried over.
BoxConstraints _sheetConstraints(BuildContext context, double heightFraction) {
  final base =
      Theme.of(context).bottomSheetTheme.constraints ??
      const BoxConstraints(maxWidth: 640);
  final height = MediaQuery.sizeOf(context).height * heightFraction;
  return base.copyWith(
    maxHeight: base.maxHeight.isFinite && base.maxHeight < height
        ? base.maxHeight
        : height,
  );
}
