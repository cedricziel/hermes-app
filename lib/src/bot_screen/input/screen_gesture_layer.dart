import 'dart:async';
import 'dart:math' as math;

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
/// [transformation] it reads at every event. While [enabled] it wins every
/// single-pointer gesture against the viewer's pan: a finger or mouse drag
/// goes to the screen, and so does a trackpad scroll (pan/zoom events whose
/// scale stays near 1). Two-pointer gestures stay with the viewer: a second
/// finger that lands before the first has moved past the touch slop, and a
/// trackpad pinch, leave the arena to the viewer and send nothing. A finger
/// that already moved past the slop owns the gesture, so a second finger then
/// only ends its drag.
///
/// In [ScreenGestureMode.trackpad] a tap followed within
/// [kDoubleTapTimeout] by a press that moves holds the primary button for the
/// drag, as on a laptop trackpad (tap and drag); a second tap that does not
/// move is a second click.
///
/// An `InteractiveViewer` also zooms on the mouse wheel by itself, which this
/// layer cannot prevent; whoever places the layer decides its `scaleEnabled`.
///
/// The picture is taken to fill the layer with `BoxFit.contain`, the way a
/// `RawImage` fills the viewer's child. [enabled] is false by default; while
/// it is, the layer sends nothing and takes no part in the gesture arena.
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
  /// pixels. The layer moves it, also to where a mouse points, and keeps it on
  /// the screen; show a cursor from it. Without one the layer keeps its own,
  /// starting at the centre.
  final ValueNotifier<Offset>? virtualPointer;

  final bool enabled;
  final ScreenGestureMode mode;

  @override
  State<ScreenGestureLayer> createState() => _ScreenGestureLayerState();
}

enum _Touch { idle, pending, dragging, panning, longPressed }

/// What a trackpad's pan/zoom gesture turned out to be.
enum _PanZoom { undecided, scroll, pinch }

/// A scale this far from 1 makes a trackpad gesture a pinch (the viewer's own
/// scale slop).
const _pinchScale = 0.05;

bool _isPinch(PointerPanZoomUpdateEvent event) =>
    (event.scale - 1).abs() > _pinchScale;

/// A wheel event this large is one click of a notched wheel, which scrolls at
/// least one notch; smaller ones come from smooth wheels and gather.
const _discreteWheel = 30.0;

/// Logical pixels of a wheel click, or of smooth scrolling, that make one
/// notch.
const _wheelPixelsPerNotch = 120.0;

class _ScreenGestureLayerState extends State<ScreenGestureLayer> {
  ValueNotifier<Offset>? _ownPointer;
  final _scrollX = ScrollAccumulator();
  final _scrollY = ScrollAccumulator();
  final _wheelX = ScrollAccumulator(pixelsPerNotch: _wheelPixelsPerNotch);
  final _wheelY = ScrollAccumulator(pixelsPerNotch: _wheelPixelsPerNotch);
  _PanZoom _panZoom = _PanZoom.undecided;

  final _touches = <int>{};
  bool _multiTouch = false;
  int _touchId = 0;
  _Touch _touch = _Touch.idle;
  Offset _touchStart = Offset.zero;
  Timer? _longPress;

  /// Whether a tap just ended, so that a press now may be a tap and drag.
  bool _tapped = false;
  Timer? _tapWindow;

  /// Whether the finger that is down began as the second half of a tap and
  /// drag, and whether it holds the button now.
  bool _dragArmed = false;

  /// The latest pointer message sent, to skip a repeat and to release a button
  /// that is still held when the layer stops.
  ({int x, int y, int mask})? _sent;

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

  /// The virtual pointer in screen pixels, kept on the screen.
  ({int x, int y}) get _virtual {
    final at = _onScreen(_pointer.value);
    return (x: at.dx.floor(), y: at.dy.floor());
  }

  Offset _onScreen(Offset position) => Offset(
    position.dx.clamp(0, math.max(0, widget.framebuffer.width - 1)).toDouble(),
    position.dy.clamp(0, math.max(0, widget.framebuffer.height - 1)).toDouble(),
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
    if (old.framebuffer != widget.framebuffer) {
      // A notifier's listeners may rebuild, which they cannot do mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pointer.value = _onScreen(_pointer.value);
      });
    }
  }

  @override
  void dispose() {
    _stopGesture();
    _ownPointer?.dispose();
    super.dispose();
  }

  /// Ends a touch in progress, letting go of any button still held.
  void _stopGesture({RfbInputSink? sink}) {
    _longPress?.cancel();
    _tapWindow?.cancel();
    _tapped = _dragArmed = false;
    _touch = _Touch.idle;
    final sent = _sent;
    if (sent != null && sent.mask != 0) {
      _pointerTo(sent.x, sent.y, 0, sink: sink);
    }
    _sent = null;
  }

  /// Pointer events of a gesture that began before the layer was disabled or
  /// removed still reach its handlers; they are dropped.
  bool get _live => mounted && widget.enabled;

  // Touch ---------------------------------------------------------------------

  void _onDown(PointerDownEvent event) {
    if (!_live) return;
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
    _dragArmed = _tapped && widget.mode == ScreenGestureMode.trackpad;
    _tapWindow?.cancel();
    _tapped = false;
    _touch = _Touch.pending;
    _longPress = Timer(kLongPressTimeout, _onLongPress);
  }

  void _onMove(PointerMoveEvent event) {
    if (!_live) return;
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
          _sendAt(event.localPosition, RfbButtons.primary);
        } else {
          _touch = _Touch.panning;
          if (_dragArmed) {
            // Tap and drag: the button goes down where the pointer is.
            final at = _virtual;
            _pointerTo(at.x, at.y, RfbButtons.primary);
          }
          // The travel up to the slop counts.
          _movePointer(event.localPosition - _touchStart);
        }
      case _Touch.dragging:
        _sendAt(event.localPosition, RfbButtons.primary);
      case _Touch.panning:
        _movePointer(event.localDelta);
      case _Touch.idle || _Touch.longPressed:
        break;
    }
  }

  void _onUp(PointerUpEvent event) {
    if (!_live) return;
    if (event.kind == PointerDeviceKind.mouse) return _sendMouse(event);
    if (!_isTouch(event) || _fingerLifted(event.pointer)) return;
    if (event.pointer != _touchId) return;
    _longPress?.cancel();
    switch (_touch) {
      case _Touch.pending:
        _click(RfbButtons.primary);
        if (widget.mode == ScreenGestureMode.trackpad) _openTapWindow();
      case _Touch.dragging:
        _sendAt(event.localPosition, 0);
      case _Touch.panning when _dragArmed:
        final at = _virtual;
        _pointerTo(at.x, at.y, 0);
      case _Touch.idle || _Touch.panning || _Touch.longPressed:
        break;
    }
    _dragArmed = false;
    _touch = _Touch.idle;
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_live) return;
    if (event.kind == PointerDeviceKind.mouse) return _stopGesture();
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
        : _virtual;
    _pointerTo(at.x, at.y, 0);
    _pointerTo(at.x, at.y, button);
    _pointerTo(at.x, at.y, 0);
  }

  /// A tap just ended: for [kDoubleTapTimeout] a press may begin a drag.
  void _openTapWindow() {
    _tapped = true;
    _tapWindow?.cancel();
    _tapWindow = Timer(kDoubleTapTimeout, () => _tapped = false);
  }

  void _movePointer(Offset delta) {
    final moved = _geometry.movePointer(_onScreen(_pointer.value), delta);
    _pointer.value = moved;
    _pointerTo(
      moved.dx.floor(),
      moved.dy.floor(),
      _dragArmed ? RfbButtons.primary : 0,
    );
  }

  // Mouse and wheel -----------------------------------------------------------

  /// Sends the pixel under [local] with [mask] and returns it.
  ({int x, int y}) _sendAt(Offset local, int mask) {
    final at = _geometry.toFramebuffer(local);
    _pointerTo(at.x, at.y, mask);
    return at;
  }

  /// A mouse points at the screen itself, in trackpad mode too, where it also
  /// moves the virtual pointer.
  void _sendMouse(PointerEvent event) {
    final at = _sendAt(event.localPosition, _rfbButtons(event.buttons));
    if (widget.mode == ScreenGestureMode.trackpad) {
      _pointer.value = Offset(at.x.toDouble(), at.y.toDouble());
    }
  }

  void _pointerTo(int x, int y, int mask, {RfbInputSink? sink}) {
    final next = (x: x, y: y, mask: mask);
    if (sink == null && next == _sent) return;
    _guarded(() => (sink ?? widget.sink).pointer(x, y, mask));
    _sent = next;
  }

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
    if (!_live || event.kind != PointerDeviceKind.mouse) return;
    _sendMouse(event);
  }

  void _onSignal(PointerSignalEvent event) {
    if (!_live) return;
    if (event is! PointerScrollEvent) return;
    // Claim the wheel, so a scrollable around the layer does not scroll with
    // it.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final delta = event.scrollDelta;
      final mouse = event.kind == PointerDeviceKind.mouse;
      _scrollAt(
        event,
        mouse ? _wheelNotches(delta.dx, _wheelX) : _scrollX.add(delta.dx),
        mouse ? _wheelNotches(delta.dy, _wheelY) : _scrollY.add(delta.dy),
      );
    });
  }

  /// A click of a notched wheel is at least one notch; the small deltas of a
  /// smooth wheel gather until they make one.
  int _wheelNotches(double delta, ScrollAccumulator smooth) {
    if (delta.abs() < _discreteWheel) return smooth.add(delta);
    smooth.reset();
    final notches = math.max(1, (delta.abs() / _wheelPixelsPerNotch).round());
    return delta.isNegative ? -notches : notches;
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    if (!_live) return;
    _resetScroll();
    _panZoom = _PanZoom.undecided;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_live) return;
    if (_panZoom == _PanZoom.pinch) return;
    if (_isPinch(event)) {
      _panZoom = _PanZoom.pinch;
      return;
    }
    var delta = event.panDelta;
    if (_panZoom == _PanZoom.undecided) {
      if (event.pan.distance <= kPrecisePointerPanSlop) return;
      _panZoom = _PanZoom.scroll;
      delta = event.pan;
    }
    // Fingers moving up move the content up, which is a scroll down.
    _scrollAt(event, _scrollX.add(-delta.dx), _scrollY.add(-delta.dy));
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    if (!_live) return;
    _resetScroll();
  }

  void _resetScroll() {
    _scrollX.reset();
    _scrollY.reset();
  }

  /// Scrolls at the virtual pointer in trackpad mode and under the pointer
  /// otherwise.
  void _scrollAt(PointerEvent event, int dx, int dy) {
    if (dx == 0 && dy == 0) return;
    final at = widget.mode == ScreenGestureMode.trackpad
        ? _virtual
        : _geometry.toFramebuffer(event.localPosition);
    _guarded(() => widget.sink.scroll(at.x, at.y, dx: dx, dy: dy));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.expand();
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: _claimGestures,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        onPointerHover: _onHover,
        onPointerSignal: _onSignal,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        onPointerPanZoomEnd: _onPanZoomEnd,
        child: const SizedBox.expand(),
      ),
    );
  }
}

final _claimGestures = <Type, GestureRecognizerFactory>{
  _ClaimRecognizer: GestureRecognizerFactoryWithHandlers<_ClaimRecognizer>(
    _ClaimRecognizer.new,
    (_) {},
  ),
};

/// Wins the gesture arena for a single pointer, so the viewer under the layer
/// does not pan with it, and leaves two-pointer gestures to the viewer.
///
/// A mouse button wins at once. A finger wins when it moves past the touch
/// slop, ahead of the viewer's own, and loses as soon as a second finger lands
/// before that. A trackpad's pan/zoom gesture wins when it pans while its
/// scale stays near 1, and loses once the scale moves: a pinch. It sends
/// nothing itself; the layer's pointer events do the work.
class _ClaimRecognizer extends OneSequenceGestureRecognizer {
  final _starts = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    if (event.kind == PointerDeviceKind.mouse) {
      resolve(GestureDisposition.accepted);
      return;
    }
    _starts[event.pointer] = event.position;
    if (_starts.length > 1) resolve(GestureDisposition.rejected);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final start = _starts[event.pointer];
      if (start != null && (event.position - start).distance > kTouchSlop) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerPanZoomUpdateEvent) {
      if (_isPinch(event)) {
        resolve(GestureDisposition.rejected);
      } else if (event.pan.distance > kPrecisePointerPanSlop) {
        resolve(GestureDisposition.accepted);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) => _starts.clear();

  @override
  String get debugDescription => 'claim the screen';
}

/// Flutter's button bits as an RFB button mask.
int _rfbButtons(int buttons) =>
    (buttons & kPrimaryMouseButton != 0 ? RfbButtons.primary : 0) |
    (buttons & kMiddleMouseButton != 0 ? RfbButtons.middle : 0) |
    (buttons & kSecondaryMouseButton != 0 ? RfbButtons.secondary : 0);
