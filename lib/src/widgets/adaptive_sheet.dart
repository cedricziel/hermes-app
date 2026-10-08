import 'package:flutter/material.dart';

import '../theme/breakpoints.dart';

/// Shows [builder] as a dialog up to [maxWidth] wide on a wide layout and as
/// a bottom sheet on a compact one (see [isWideLayout]).
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 520,
}) => isWideLayout(context)
    ? showDialog<T>(
        context: context,
        builder: (dialog) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: builder(dialog),
          ),
        ),
      )
    : showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: builder,
      );
