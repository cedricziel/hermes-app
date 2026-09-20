import 'package:flutter/material.dart';

/// Keeps a page's content to a readable width on a wide window, centered under
/// the app bar, instead of stretching a list row or a form across it.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  static const double maxWidth = 640;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
