import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One line of [text] for a tight spot such as a segment: drawn whole at
/// its size when it fits, otherwise shrunk, but never below [minScale] of
/// it. Past that the end is cut with an ellipsis, so a large text size is
/// not undone. It sits centred in the space it is given.
class ShrinkToFitText extends StatelessWidget {
  const ShrinkToFitText(
    this.text, {
    super.key,
    this.style,
    this.minScale = defaultMinScale,
  });

  /// The smallest share of its size a label is drawn at. Low enough that
  /// the schedule picker's five segments stay whole at 320 points and text
  /// scale 1.3; at larger text a long label is cut instead, still drawn
  /// bigger than at the default text size.
  static const double defaultMinScale = 0.7;

  final String text;
  final TextStyle? style;
  final double minScale;

  @override
  Widget build(BuildContext context) => _ShrinkToFit(
    minScale: minScale,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

class _ShrinkToFit extends SingleChildRenderObjectWidget {
  const _ShrinkToFit({required this.minScale, required super.child});

  final double minScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShrinkToFit(minScale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShrinkToFit renderObject,
  ) => renderObject.minScale = minScale;
}

class _RenderShrinkToFit extends RenderProxyBox {
  _RenderShrinkToFit(this._minScale);

  double _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  /// The scale the label is drawn at, from [_minScale] to 1.
  double _scale = 1;
  Offset _origin = Offset.zero;

  double _scaleFor(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return 1;
    final natural = child!.getMaxIntrinsicWidth(double.infinity);
    if (natural <= constraints.maxWidth || natural == 0) return 1;
    return math.max(_minScale, constraints.maxWidth / natural);
  }

  BoxConstraints _childConstraints(BoxConstraints constraints, double scale) =>
      BoxConstraints(
        maxWidth: constraints.hasBoundedWidth
            ? constraints.maxWidth / scale
            : double.infinity,
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    final scale = _scaleFor(constraints);
    final inner = child!.getDryLayout(_childConstraints(constraints, scale));
    return constraints.constrain(inner * scale);
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    _scale = _scaleFor(constraints);
    child!.layout(_childConstraints(constraints, _scale), parentUsesSize: true);
    final drawn = child!.size * _scale;
    size = constraints.constrain(drawn);
    _origin = Alignment.center.alongOffset(size - drawn as Offset);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height) ?? 0) * _minScale;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform
      ..translateByDouble(_origin.dx, _origin.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) {
      layer = null;
      context.paintChild(child!, offset + _origin);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.identity()
        ..translateByDouble(_origin.dx, _origin.dy, 0, 1)
        ..scaleByDouble(_scale, _scale, 1, 1),
      (context, offset) => context.paintChild(child!, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final transform = Matrix4.identity();
    applyPaintTransform(child, transform);
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
