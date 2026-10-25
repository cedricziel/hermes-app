import 'package:flutter/widgets.dart';

/// How a position on the zoomed and panned picture maps to a framebuffer
/// pixel.
class ScreenGeometry {
  /// [pictureRect] is where the picture sits in the zoomed content (the
  /// `InteractiveViewer`'s child) and [transform] its controller's value,
  /// which maps that content to the viewer.
  ScreenGeometry({
    required this.framebuffer,
    required this.pictureRect,
    Matrix4? transform,
  }) : _transform = transform ?? Matrix4.identity(),
       _inverse =
           (transform == null ? null : Matrix4.tryInvert(transform)) ??
           Matrix4.identity();

  /// A picture shown with [BoxFit.contain] in a content area of [viewport]'s
  /// size, centred: the way `RawImage` fills an `InteractiveViewer` child.
  factory ScreenGeometry.fitted({
    required Size framebuffer,
    required Size viewport,
    Matrix4? transform,
  }) {
    final shown = applyBoxFit(
      BoxFit.contain,
      framebuffer,
      viewport,
    ).destination;
    return ScreenGeometry(
      framebuffer: framebuffer,
      pictureRect: Alignment.center.inscribe(shown, Offset.zero & viewport),
      transform: transform,
    );
  }

  /// The remote screen in pixels.
  final Size framebuffer;

  final Rect pictureRect;

  final Matrix4 _transform;
  final Matrix4 _inverse;

  /// The zoom: 1 shows the picture at fit.
  double get scale => _transform.getMaxScaleOnAxis();

  /// The framebuffer pixel under [local], a position in the viewer; a
  /// position outside the picture gives the nearest pixel at its edge.
  ({int x, int y}) toFramebuffer(Offset local) {
    final content = MatrixUtils.transformPoint(_inverse, local);
    final x =
        (content.dx - pictureRect.left) * framebuffer.width / pictureRect.width;
    final y =
        (content.dy - pictureRect.top) *
        framebuffer.height /
        pictureRect.height;
    return (
      x: x.floor().clamp(0, framebuffer.width.toInt() - 1),
      y: y.floor().clamp(0, framebuffer.height.toInt() - 1),
    );
  }

  /// Moves [pointer], in framebuffer pixels, by [delta] logical pixels of
  /// finger travel: the further the picture is zoomed in, the less the
  /// pointer travels. The result stays on the screen.
  Offset movePointer(Offset pointer, Offset delta) {
    final moved =
        pointer +
        Offset(
          delta.dx * framebuffer.width / (pictureRect.width * scale),
          delta.dy * framebuffer.height / (pictureRect.height * scale),
        );
    return Offset(
      moved.dx.clamp(0, framebuffer.width - 1),
      moved.dy.clamp(0, framebuffer.height - 1),
    );
  }
}

/// Gathers trackpad scroll distance into wheel notches.
class ScrollAccumulator {
  /// Logical pixels of scrolling that make one wheel notch.
  static const pixelsPerNotch = 40.0;

  double _rest = 0;

  /// Adds [delta] logical pixels (positive: down or right) and returns the
  /// whole notches reached, negative for up or left. The rest is kept.
  int add(double delta) {
    _rest += delta;
    final notches = (_rest / pixelsPerNotch).truncate();
    _rest -= notches * pixelsPerNotch;
    return notches;
  }

  void reset() => _rest = 0;
}
