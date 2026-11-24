import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard zoom and pan for the [InteractiveViewer] it wraps: [zoomStep]
/// zoom about the middle of the viewport with Cmd (Apple) or Ctrl (the other
/// platforms) plus `=` / `+` and `-`, reset to fit with Cmd or Ctrl plus `0`
/// and the arrow keys pan while zoomed in. It draws nothing and takes keyboard
/// focus when it opens and on a click or tap.
///
/// The Mac menu bar owns Cmd+0 (Window, Hermes), so on macOS reset is
/// Cmd+Option+0. Cmd+= and Cmd+- are free there.
///
/// The viewer's child must be as large as its viewport (the case for a child
/// given tight constraints), so the content's edge is the viewport's edge at
/// scale 1. Arrows at fit are not consumed.
class ZoomKeyboardShortcuts extends StatefulWidget {
  const ZoomKeyboardShortcuts({
    super.key,
    required this.controller,
    required this.maxScale,
    required this.child,
    this.autofocus = true,
  });

  /// The viewer's controller.
  final TransformationController controller;

  /// The viewer's `maxScale`. Fit (scale 1) is the smallest keyboard zoom.
  final double maxScale;

  final bool autofocus;

  final Widget child;

  /// One zoom key press multiplies the scale by this.
  static const zoomStep = 1.5;

  /// One arrow press moves the picture by this many logical pixels.
  static const panStep = 80.0;

  /// Past this the picture counts as zoomed in, as for double tap.
  static const zoomedAbove = 1.01;

  @override
  State<ZoomKeyboardShortcuts> createState() => _ZoomKeyboardShortcutsState();
}

enum _Action { zoomIn, zoomOut, reset }

class _ZoomKeyboardShortcutsState extends State<ZoomKeyboardShortcuts> {
  final _focus = FocusNode(debugLabel: 'ZoomKeyboardShortcuts');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The keyboard zoom action for [key] with the modifiers held now, or null.
  _Action? _actionFor(LogicalKeyboardKey key, TargetPlatform platform) {
    final keys = HardwareKeyboard.instance;
    final apple =
        platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    final held = apple ? keys.isMetaPressed : keys.isControlPressed;
    final wrong = apple ? keys.isControlPressed : keys.isMetaPressed;
    if (!held || wrong) return null;
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      final macOS = platform == TargetPlatform.macOS;
      return keys.isAltPressed == macOS ? _Action.reset : null;
    }
    if (keys.isAltPressed) return null;
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.numpadEqual) {
      return _Action.zoomIn;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      return _Action.zoomOut;
    }
    return null;
  }

  Offset? _arrow(LogicalKeyboardKey key) {
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed ||
        keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isShiftPressed) {
      return null;
    }
    const step = ZoomKeyboardShortcuts.panStep;
    // The picture moves against the arrow: Right shows what is to the right.
    if (key == LogicalKeyboardKey.arrowLeft) return const Offset(step, 0);
    if (key == LogicalKeyboardKey.arrowRight) return const Offset(-step, 0);
    if (key == LogicalKeyboardKey.arrowUp) return const Offset(0, step);
    if (key == LogicalKeyboardKey.arrowDown) return const Offset(0, -step);
    return null;
  }

  KeyEventResult _onKey(Size viewport, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final controller = widget.controller;
    final platform = Theme.of(context).platform;
    final action = _actionFor(event.logicalKey, platform);
    if (action == _Action.reset) {
      controller.value = Matrix4.identity();
      return KeyEventResult.handled;
    }
    if (action != null) {
      final current = controller.value.getMaxScaleOnAxis();
      final target =
          (action == _Action.zoomIn
                  ? current * ZoomKeyboardShortcuts.zoomStep
                  : current / ZoomKeyboardShortcuts.zoomStep)
              .clamp(1.0, widget.maxScale);
      final factor = target / current;
      final centre = viewport.center(Offset.zero);
      final next = Matrix4.identity()
        ..translateByDouble(centre.dx, centre.dy, 0, 1)
        ..scaleByDouble(factor, factor, 1, 1)
        ..translateByDouble(-centre.dx, -centre.dy, 0, 1)
        ..multiply(controller.value);
      controller.value = _within(next, viewport);
      return KeyEventResult.handled;
    }
    final pan = _arrow(event.logicalKey);
    if (pan == null ||
        controller.value.getMaxScaleOnAxis() <=
            ZoomKeyboardShortcuts.zoomedAbove) {
      return KeyEventResult.ignored;
    }
    final next = controller.value.clone()
      ..leftTranslateByDouble(pan.dx, pan.dy, 0, 1);
    controller.value = _within(next, viewport);
    return KeyEventResult.handled;
  }

  /// [m] moved so the content still covers the viewport, as a drag leaves it.
  Matrix4 _within(Matrix4 m, Size viewport) {
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final x = t.x.clamp(viewport.width * (1 - scale), 0.0);
    final y = t.y.clamp(viewport.height * (1 - scale), 0.0);
    return m.clone()..setTranslationRaw(x, y, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final viewport = box.biggest;
        return Focus(
          focusNode: _focus,
          autofocus: widget.autofocus,
          onKeyEvent: (_, event) => _onKey(viewport, event),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _focus.requestFocus(),
            child: widget.child,
          ),
        );
      },
    );
  }
}
