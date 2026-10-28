import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells [onChanged] whether [child] is on screen: inside the viewport of the
/// scrollable it sits in, or (outside any scrollable) simply laid out.
///
/// A list builds children in its cache extent too, so being built says nothing
/// about being seen. The check runs after each frame, which covers scrolling,
/// resizing and the child changing size, and reports only changes. A child with
/// no area counts as on screen when its top edge is inside the viewport, so a
/// widget that draws nothing yet can still be placed and found.
///
/// Whether the page itself is covered by another route is not known here; see
/// `TickerMode`.
class OnScreen extends StatefulWidget {
  const OnScreen({super.key, required this.onChanged, required this.child});

  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<OnScreen> createState() => _OnScreenState();
}

class _OnScreenState extends State<OnScreen> {
  bool? _reported;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// Looks after the next frame, and again after every frame that follows
  /// while mounted. A frame that never comes (nothing changes) costs nothing.
  void _check() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final onScreen = _isOnScreen(context.findRenderObject());
      if (onScreen != _reported) {
        _reported = onScreen;
        widget.onChanged(onScreen);
      }
      _check();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Whether [box] overlaps the viewport that scrolls it. See [OnScreen].
bool _isOnScreen(RenderObject? box) {
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport is! RenderBox || !viewport.hasSize) return true;
  final inViewport = MatrixUtils.transformRect(
    box.getTransformTo(viewport),
    Offset.zero & box.size,
  );
  final bounds = Offset.zero & viewport.size;
  if (inViewport.isEmpty) {
    return inViewport.top >= bounds.top &&
        inViewport.top < bounds.bottom &&
        inViewport.left >= bounds.left &&
        inViewport.left <= bounds.right;
  }
  return inViewport.overlaps(bounds);
}
