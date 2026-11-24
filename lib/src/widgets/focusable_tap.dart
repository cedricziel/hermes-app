import 'package:flutter/material.dart';

/// Makes a tap box that a bare `GestureDetector` builds a keyboard control:
/// it takes a tab stop, Enter and Space run [onActivate] (the same callback
/// the tap runs), and a mouse over it shows the click cursor. It draws
/// nothing: wrap it in a `FocusRing` (inside it, so the ring sees the focus)
/// for the ring, and use `InkWell` instead where the control has no clipping
/// decoration that would hide a splash.
///
/// [onFocusChange] reports the focus, for a control that shows more while it
/// has it (a hover-only chevron). With a null [onActivate] the control is not
/// focusable at all.
class FocusableTap extends StatelessWidget {
  const FocusableTap({
    super.key,
    required this.onActivate,
    required this.child,
    this.focusNode,
    this.onFocusChange,
    this.mouseCursor = SystemMouseCursors.click,
  });

  final VoidCallback? onActivate;
  final Widget child;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: onActivate != null,
    focusNode: focusNode,
    mouseCursor: mouseCursor,
    onFocusChange: onFocusChange,
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onActivate?.call();
          return null;
        },
      ),
    },
    child: child,
  );
}
