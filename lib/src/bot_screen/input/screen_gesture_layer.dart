import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../rfb/rfb_input_sink.dart';
import 'screen_geometry.dart';

/// How a finger drives the remote pointer.
enum ScreenGestureMode {
  /// The finger is the pointer: a position on the picture is a position on
  /// the screen.
  touch,

  /// The finger moves a virtual pointer relative to where it was, as on a
  /// laptop trackpad.
  trackpad,
}

/// Turns touch, mouse and trackpad input on a zoomed picture into pointer
/// calls on an [RfbInputSink].
///
/// It draws nothing and sits over an `InteractiveViewer` whose
/// [transformation] it reads at every event. It reads pointer events directly
/// instead of joining the gesture arena, so it never competes with the
/// viewer: two-finger gestures, a pinch included, are left to the viewer, and
/// the layer sends nothing for them. A second finger landing during a drag
/// releases the button first.
///
/// The picture is taken to fill the layer with `BoxFit.contain`, the way a
/// `RawImage` fills the viewer's child. [enabled] is false by default; while
/// it is, the layer sends nothing.
class ScreenGestureLayer extends StatefulWidget {
  const ScreenGestureLayer({
    super.key,
    required this.sink,
    required this.framebuffer,
    this.transformation,
    this.virtualPointer,
    this.enabled = false,
    this.mode = ScreenGestureMode.touch,
  });

  final RfbInputSink sink;

  /// The remote screen in pixels.
  final Size framebuffer;

  /// The viewer's zoom and pan; null shows the picture at fit.
  final TransformationController? transformation;

  /// Where the virtual pointer of [ScreenGestureMode.trackpad] is, in screen
  /// pixels. The layer moves it; show a cursor from it. Without one the
  /// layer keeps its own, starting at the centre.
  final ValueNotifier<Offset>? virtualPointer;

  final bool enabled;
  final ScreenGestureMode mode;

  @override
  State<ScreenGestureLayer> createState() => _ScreenGestureLayerState();
}

enum _Touch { idle, pending, dragging, panning, longPressed }

class _ScreenGestureLayerState extends State<ScreenGestureLayer> {
  ValueNotifier<Offset>? _ownPointer;
  final _scrollX = ScrollAccumulator();
  final _scrollY = ScrollAccumulator();

  final _touches = <int>{};
  bool _multiTouch = false;
  int _touchId = 0;
  _Touch _touch = _Touch.idle;
  Offset _touchStart = Offset.zero;
  Timer? _longPress;

  /// Where the primary button is held, in screen pixels, while a drag runs.
  ({int x, int y})? _held;

  ValueNotifier<Offset> get _pointer =>
      widget.virtualPointer ??
      (_ownPointer ??= ValueNotifier(
        Offset(widget.framebuffer.width / 2, widget.framebuffer.height / 2),
      ));

  ScreenGeometry get _geometry => ScreenGeometry.fitted(
    framebuffer: widget.framebuffer,
    viewport: context.size!,
    transform: widget.transformation?.value,
  );

  @override
  void didUpdateWidget(ScreenGestureLayer old) {
    super.didUpdateWidget(old);
    if (old.enabled && !widget.enabled ||
        old.mode != widget.mode ||
        old.sink != widget.sink) {
      _touches.clear();
      _multiTouch = false;
      _stopGesture(sink: old.sink);
    }
  }

  @override
  void dispose() {
    _stopGesture();
    _ownPointer?.dispose();
    super.dispose();
  }

  /// Ends a touch in progress, letting go of the button if a drag holds it.
  void _stopGesture({RfbInputSink? sink}) {
    _longPress?.cancel();
    _touch = _Touch.idle;
    final held = _held;
    _held = null;
    if (held != null) _pointerTo(held.x, held.y, 0, sink: sink);
  }

  // Touch ---------------------------------------------------------------------

  void _onDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return _sendMouse(event);
    if (!_isTouch(event)) return;
    _touches.add(event.pointer);
    if (_touches.length > 1) {
      _multiTouch = true;
      _stopGesture();
      return;
    }
    _multiTouch = false;
    _touchId = event.pointer;
    _touchStart = event.localPosition;
    _touch = _Touch.pending;
    _longPress = Timer(kLongPressTimeout, _onLongPress);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return _sendMouse(event);
    if (!_isTouch(event) || _multiTouch || event.pointer != _touchId) return;
    switch (_touch) {
      case _Touch.pending:
        if ((event.localPosition - _touchStart).distance <= kTouchSlop) return;
        _longPress?.cancel();
        if (widget.mode == ScreenGestureMode.touch) {
          _touch = _Touch.dragging;
          _sendAt(_touchStart, 0);
          _sendAt(_touchStart, RfbButtons.primary);
          _held = _sendAt(event.localPosition, RfbButtons.primary);
        } else {
          _touch = _Touch.panning;
          _movePointer(event.localDelta);
        }
      case _Touch.dragging:
        _held = _sendAt(event.localPosition, RfbButtons.primary);
      case _Touch.panning:
        _movePointer(event.localDelta);
      case _Touch.idle || _Touch.longPressed:
        break;
    }
  }

  void _onUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return _sendMouse(event);
    if (!_isTouch(event) || _fingerLifted(event.pointer)) return;
    if (event.pointer != _touchId) return;
    _longPress?.cancel();
    switch (_touch) {
      case _Touch.pending:
        _click(RfbButtons.primary);
      case _Touch.dragging:
        _sendAt(event.localPosition, 0);
        _held = null;
      case _Touch.idle || _Touch.panning || _Touch.longPressed:
        break;
    }
    _touch = _Touch.idle;
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_isTouch(event) || _fingerLifted(event.pointer)) return;
    if (event.pointer == _touchId) _stopGesture();
  }

  /// Whether [event] comes from a finger or a stylus, as opposed to a mouse
  /// or a trackpad.
  bool _isTouch(PointerEvent event) =>
      event.kind != PointerDeviceKind.mouse &&
      event.kind != PointerDeviceKind.trackpad;

  /// Forgets a finger that went up or was cancelled. True while a multi-touch
  /// gesture is going on, which the layer ignores until every finger is up.
  bool _fingerLifted(int pointer) {
    _touches.remove(pointer);
    if (_multiTouch && _touches.isEmpty) {
      _multiTouch = false;
      return true;
    }
    return _multiTouch;
  }

  void _onLongPress() {
    if (_touch != _Touch.pending) return;
    _touch = _Touch.longPressed;
    _click(RfbButtons.secondary);
  }

  /// A move, press and release of [button] at the touch (touch mode) or at
  /// the virtual pointer (trackpad mode).
  void _click(int button) {
    final at = widget.mode == ScreenGestureMode.touch
        ? _geometry.toFramebuffer(_touchStart)
        : (x: _pointer.value.dx.floor(), y: _pointer.value.dy.floor());
    _pointerTo(at.x, at.y, 0);
    _pointerTo(at.x, at.y, button);
    _pointerTo(at.x, at.y, 0);
  }

  void _movePointer(Offset delta) {
    final moved = _geometry.movePointer(_pointer.value, delta);
    _pointer.value = moved;
    _pointerTo(moved.dx.floor(), moved.dy.floor(), 0);
  }

  // Mouse and wheel -----------------------------------------------------------

  /// Sends the pixel under [local] with [mask] and returns it.
  ({int x, int y}) _sendAt(Offset local, int mask) {
    final at = _geometry.toFramebuffer(local);
    _pointerTo(at.x, at.y, mask);
    return at;
  }

  void _sendMouse(PointerEvent event) =>
      _sendAt(event.localPosition, _rfbButtons(event.buttons));

  void _pointerTo(int x, int y, int mask, {RfbInputSink? sink}) =>
      _guarded(() => (sink ?? widget.sink).pointer(x, y, mask));

  /// A sink that has closed throws [StateError]; input that arrives after the
  /// stream ended is dropped, the server let go of any button with it.
  void _guarded(void Function() send) {
    try {
      send();
    } on StateError {
      // See above.
    }
  }

  void _onHover(PointerHoverEvent event) {
    if (event.kind == PointerDeviceKind.mouse) _sendMouse(event);
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Claim the wheel, so a scrollable around the layer does not scroll with
    // it. An InteractiveViewer reads the wheel itself and zooms regardless.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final delta = event.scrollDelta;
      final mouse = event.kind == PointerDeviceKind.mouse;
      _scroll(
        event.localPosition,
        mouse ? delta.dx.sign.toInt() : _scrollX.add(delta.dx),
        mouse ? delta.dy.sign.toInt() : _scrollY.add(delta.dy),
      );
    });
  }

  void _resetScroll(PointerEvent _) {
    _scrollX.reset();
    _scrollY.reset();
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // Fingers moving up move the content up, which is a scroll down.
    _scroll(
      event.localPosition,
      _scrollX.add(-event.panDelta.dx),
      _scrollY.add(-event.panDelta.dy),
    );
  }

  void _scroll(Offset local, int dx, int dy) {
    if (dx == 0 && dy == 0) return;
    final at = _geometry.toFramebuffer(local);
    _guarded(() => widget.sink.scroll(at.x, at.y, dx: dx, dy: dy));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.expand();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      onPointerHover: _onHover,
      onPointerSignal: _onSignal,
      onPointerPanZoomStart: _resetScroll,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _resetScroll,
      child: const SizedBox.expand(),
    );
  }
}

/// Flutter's button bits as an RFB button mask.
int _rfbButtons(int buttons) =>
    (buttons & kPrimaryMouseButton != 0 ? RfbButtons.primary : 0) |
    (buttons & kMiddleMouseButton != 0 ? RfbButtons.middle : 0) |
    (buttons & kSecondaryMouseButton != 0 ? RfbButtons.secondary : 0);
