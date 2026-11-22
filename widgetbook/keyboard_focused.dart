import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';

/// Shows [child] as it looks after a Tab press has put the keyboard focus on
/// the focusable control that holds [target] (a key anywhere inside that
/// control's focus scope below it): the highlight mode is forced to
/// traditional and the last input marked as the keyboard, and both go back
/// when the use case goes away. Catalog only.
class KeyboardFocused extends StatefulWidget {
  const KeyboardFocused({super.key, required this.target, required this.child});

  final Key target;
  final Widget child;

  @override
  State<KeyboardFocused> createState() => _KeyboardFocusedState();
}

class _KeyboardFocusedState extends State<KeyboardFocused> {
  /// The next use case builds before the last one is disposed, so the
  /// strategy goes back only when none is left.
  static var _live = 0;

  @override
  void initState() {
    super.initState();
    _live++;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      markFocusRingKeyboardInput();
      for (final node in FocusScope.of(context).traversalDescendants) {
        if (_holds(node.context, widget.target)) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    if (--_live == 0) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Whether [context] is, or has below it, a widget keyed [key].
bool _holds(BuildContext? context, Key key) {
  if (context == null) return false;
  var found = false;
  void walk(Element element) {
    if (found) return;
    if (element.widget.key == key) {
      found = true;
      return;
    }
    element.visitChildren(walk);
  }

  (context as Element).visitChildren(walk);
  return found || (context.widget.key == key);
}
