import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Sends a screen reader to [child] once, when it first appears (a banner that
/// says a start was refused, an apply was lost and the like). The event carries
/// no text and only Android and iOS act on it.
class FocusOnAppear extends StatefulWidget {
  const FocusOnAppear({super.key, required this.child});

  final Widget child;

  @override
  State<FocusOnAppear> createState() => _FocusOnAppearState();
}

class _FocusOnAppearState extends State<FocusOnAppear> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.findRenderObject()?.sendSemanticsEvent(
          const FocusSemanticEvent(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
