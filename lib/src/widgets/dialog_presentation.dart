import 'package:flutter/material.dart';

/// Shows an adaptive dialog with stationary, restrained motion on macOS.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  // The text size is the caller's too: a dialog under the root navigator would
  // otherwise read the window's.
  final textScaler = MediaQuery.textScalerOf(context);
  Widget content(BuildContext dialog) => MediaQuery(
    data: MediaQuery.of(dialog).copyWith(textScaler: textScaler),
    child: themes.wrap(Builder(builder: builder)),
  );
  if (Theme.of(context).platform != TargetPlatform.macOS) {
    // The dialog sits under the root navigator: carry the caller's theme
    // (and its platform) into it, so it is drawn as the caller would.
    return showAdaptiveDialog<T>(context: context, builder: content);
  }
  return navigator.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      pageBuilder: (dialog, animation, secondaryAnimation) =>
          SafeArea(child: content(dialog)),
      transitionBuilder: (dialog, animation, secondaryAnimation, child) =>
          MediaQuery.disableAnimationsOf(dialog)
          ? child
          : FadeTransition(opacity: animation, child: child),
    ),
  );
}
