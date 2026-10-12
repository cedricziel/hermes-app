import 'package:flutter/material.dart';

/// Shows an adaptive dialog with stationary, restrained motion on macOS.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (Theme.of(context).platform != TargetPlatform.macOS) {
    return showAdaptiveDialog<T>(context: context, builder: builder);
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
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
