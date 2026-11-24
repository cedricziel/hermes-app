import 'dart:async';

import 'package:flutter/widgets.dart';

/// The first element under [root] (itself included) that [test] accepts.
Element? findElement(Element root, bool Function(Element element) test) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    if (test(element)) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// Shows [child] and, once [pick] finds a callback in it, calls that callback
/// once, as a tap would. For a dialog or menu that only a button inside a real
/// screen opens, so the catalog can look at it without a copy of its code.
///
/// [pick] is asked every 100 ms for up to five seconds, because the screen may
/// still be loading; it returns null while what it looks for is not there.
class PressWhenReady extends StatefulWidget {
  const PressWhenReady({super.key, required this.pick, required this.child});

  /// Looks in the subtree under the given element for the callback to call.
  final VoidCallback? Function(Element root) pick;
  final Widget child;

  @override
  State<PressWhenReady> createState() => _PressWhenReadyState();
}

class _PressWhenReadyState extends State<PressWhenReady> {
  Timer? _timer;
  var _tries = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || ++_tries > 50) {
        timer.cancel();
        return;
      }
      final press = widget.pick(context as Element);
      if (press == null) return;
      timer.cancel();
      press();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
