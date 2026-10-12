import 'package:flutter/material.dart';

class MacosPageTransitionsBuilder extends PageTransitionsBuilder {
  const MacosPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}
