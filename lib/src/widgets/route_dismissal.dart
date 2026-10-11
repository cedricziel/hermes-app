import 'package:flutter/material.dart';

/// Pops [context]'s route with [result] only while that route is current.
/// Late completions cannot dismiss another route during an exit animation.
void popCurrentRoute<T extends Object?>(BuildContext context, [T? result]) {
  if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
    Navigator.of(context).pop<T>(result);
  }
}
