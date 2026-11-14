import 'package:flutter/material.dart';

/// Shows an adaptive dialog with stationary, restrained motion on macOS.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  if (Theme.of(context).platform != TargetPlatform.macOS) {
    // The dialog sits under the root navigator: carry the caller's theme
    // (and its platform) into it, so it is drawn as the caller would.
    return showAdaptiveDialog<T>(
      context: context,
      builder: (dialog) => themes.wrap(Builder(builder: builder)),
    );
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
          SafeArea(child: themes.wrap(Builder(builder: builder))),
      transitionBuilder: (dialog, animation, secondaryAnimation, child) =>
          MediaQuery.disableAnimationsOf(dialog)
          ? child
          : FadeTransition(opacity: animation, child: child),
    ),
  );
}
