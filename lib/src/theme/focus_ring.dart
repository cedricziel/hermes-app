import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hermes_theme.dart';

/// Width of the keyboard focus ring, in logical pixels.
const double kFocusRingWidth = 2;

/// Gap between a control and its focus ring.
const double kFocusRingOffset = 2;

/// Whether the last input was the keyboard, which is the only time a focus
/// ring shows. A pointer press focuses a button too and draws nothing.
///
/// Flutter's traditional highlight mode is not enough: on a desktop it stays
/// on through a mouse click (only touch and stylus switch it off), so the
/// last pointer-down and key-down are tracked here as well.
bool get keyboardFocusShows {
  _watchInput();
  return FocusManager.instance.highlightMode ==
          FocusHighlightMode.traditional &&
      !_pointerWasLast;
}

bool _pointerWasLast = false;

/// Tells [FocusRing] and the focused button that the input changed.
class _InputChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _inputChanges = _InputChanges();

GestureBinding? _watchedGestures;
FocusManager? _watchedManager;

void _pointerRoute(PointerEvent event) {
  if (event is PointerDownEvent && !_pointerWasLast) {
    _pointerWasLast = true;
    _inputChanged();
  }
}

void _highlightMode(FocusHighlightMode mode) => _inputChanged();

KeyEventResult _earlyKey(KeyEvent event) {
  if (event is KeyDownEvent && _pointerWasLast) {
    _pointerWasLast = false;
    _inputChanged();
  }
  return KeyEventResult.ignored;
}

/// Starts following pointer presses, key presses and the highlight mode. It
/// runs on every style resolution and for every [FocusRing], also when
/// nothing is focused, so a pointer press that opens a dialog is seen before
/// the dialog's button takes focus.
void _watchInput() {
  final gestures = GestureBinding.instance;
  if (!identical(_watchedGestures, gestures)) {
    _watchedGestures = gestures;
    gestures.pointerRouter.addGlobalRoute(_pointerRoute);
  }
  final manager = FocusManager.instance;
  // A test binding replaces the manager between tests.
  if (!identical(_watchedManager, manager)) {
    _watchedManager = manager;
    manager.addHighlightModeListener(_highlightMode);
    manager.addEarlyKeyEventHandler(_earlyKey);
  }
}

/// Forgets the last pointer press, for a test that starts from the keyboard.
@visibleForTesting
void resetFocusRingInput() => _pointerWasLast = false;

/// Drops what [_watchInput] installed, so a test can start from a screen that
/// has not resolved a style yet.
@visibleForTesting
void forgetFocusRingWatchers() {
  _watchedGestures?.pointerRouter.removeGlobalRoute(_pointerRoute);
  _watchedManager?.removeHighlightModeListener(_highlightMode);
  _watchedManager?.removeEarlyKeyEventHandler(_earlyKey);
  _watchedGestures = null;
  _watchedManager = null;
  _pointerWasLast = false;
}

/// Marks the last input as the keyboard, for a catalog preview that shows the
/// ring on a control it focused itself. Catalog and tests only (the guard
/// `arch.focus-ring-keyboard-override` fails on a call under `lib/`): app code
/// must let real input decide. Real input takes over on the next press.
void markFocusRingKeyboardInput() {
  _watchInput();
  if (!_pointerWasLast) return;
  _pointerWasLast = false;
  _inputChanged();
}

/// A button or a chip does not rebuild when the input changes, so the focused
/// one is marked dirty and its style or shape resolves again. Only the nearest
/// one is marked, and nothing when the focus is not inside one (a text field,
/// a row, a menu item): [FocusRing] listens on its own.
void _inputChanged() {
  _inputChanges.notify();
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element || !context.mounted) return;
  Element? button;
  context.visitAncestorElements((element) {
    if (element.widget is ButtonStyleButton || element.widget is RawChip) {
      button = element;
      return false;
    }
    return true;
  });
  button?.markNeedsBuild();
}

/// [base] with a focus ring painted [offset] outside it: the same shape grown
/// by [offset] and [offset] plus [width], with the control's corner radius
/// plus the same amount. The outline of the shape itself, and so the ink
/// clip, is [base]'s, so only the paint reaches past the bounds.
///
/// Use [focusRingShape] to give a button style one that appears with keyboard
/// focus. A row that a container clips draws its ring inside instead; see
/// [FocusRing].
class FocusRingBorder extends OutlinedBorder {
  FocusRingBorder({
    required this.base,
    required this.color,
    this.width = kFocusRingWidth,
    this.offset = kFocusRingOffset,
  }) : super(side: base.side);

  final OutlinedBorder base;
  final Color color;
  final double width;
  final double offset;

  Path _grown(Rect rect, double by, TextDirection? textDirection) {
    final b = base;
    if (b is RoundedRectangleBorder) {
      final r = b.borderRadius.resolve(textDirection);
      Radius grow(Radius v) => Radius.elliptical(v.x + by, v.y + by);
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          rect.inflate(by),
          topLeft: grow(r.topLeft),
          topRight: grow(r.topRight),
          bottomLeft: grow(r.bottomLeft),
          bottomRight: grow(r.bottomRight),
        ),
      );
    }
    return b.getOuterPath(rect.inflate(by), textDirection: textDirection);
  }

  @override
  EdgeInsetsGeometry get dimensions => base.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      base.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      base.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    base.paint(canvas, rect, textDirection: textDirection);
    canvas.drawPath(
      ringPath(rect, textDirection: textDirection),
      Paint()..color = color,
    );
  }

  /// What [paint] fills for the ring: the band between the shape grown by
  /// [offset] and by [offset] plus [width].
  @visibleForTesting
  Path ringPath(Rect rect, {TextDirection? textDirection}) => Path.combine(
    PathOperation.difference,
    _grown(rect, offset + width, textDirection),
    _grown(rect, offset, textDirection),
  );

  @override
  OutlinedBorder copyWith({BorderSide? side}) => FocusRingBorder(
    base: base.copyWith(side: side),
    color: color,
    width: width,
    offset: offset,
  );

  @override
  ShapeBorder scale(double t) => FocusRingBorder(
    base: base.scale(t) as OutlinedBorder,
    color: color,
    width: width * t,
    offset: offset * t,
  );

  @override
  bool operator ==(Object other) =>
      other is FocusRingBorder &&
      other.base == base &&
      other.color == color &&
      other.width == width &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(base, color, width, offset);
}

/// A button style's `shape`: [base], and with keyboard focus (never after a
/// pointer press) a [FocusRingBorder] in [ring].
///
/// A button does not rebuild when the input changes, so a change marks the
/// focused button dirty (`_inputChanged`); the ring then goes with a pointer
/// press and returns with the next key, not only with the next focus move.
WidgetStateProperty<OutlinedBorder?> focusRingShape(
  OutlinedBorder base,
  Color ring,
) => WidgetStateProperty.resolveWith((states) {
  _watchInput();
  return states.contains(WidgetState.focused) && keyboardFocusShows
      ? FocusRingBorder(base: base, color: ring)
      : base;
});

/// [focusRingShape] in the link colour of [context]'s theme, for a button
/// style that sets its own shape (a style's `shape` replaces the theme's, and
/// with it the ring).
WidgetStateProperty<OutlinedBorder?> focusRingShapeOf(
  BuildContext context,
  OutlinedBorder base,
) => focusRingShape(base, context.hermesColors.link);

/// [focusRingShape] as a shape, for a theme field that takes a
/// [WidgetStateOutlinedBorder] and resolves it per state (`ChipThemeData.shape`).
/// A chip resolves it on every build, so the ring follows keyboard focus; used
/// anywhere else it is [base].
class FocusRingStateBorder extends WidgetStateOutlinedBorder {
  const FocusRingStateBorder({required this.base, required this.color});

  final OutlinedBorder base;
  final Color color;

  @override
  OutlinedBorder? resolve(Set<WidgetState> states) =>
      focusRingShape(base, color).resolve(states);

  @override
  BorderSide get side => base.side;

  @override
  EdgeInsetsGeometry get dimensions => base.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      base.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      base.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      base.paint(canvas, rect, textDirection: textDirection);

  @override
  OutlinedBorder copyWith({BorderSide? side}) => FocusRingStateBorder(
    base: base.copyWith(side: side),
    color: color,
  );

  @override
  ShapeBorder scale(double t) =>
      FocusRingStateBorder(base: base.scale(t) as OutlinedBorder, color: color);
}

/// What [FocusRing] paints, for a test to find.
class FocusRingPainter extends CustomPainter {
  const FocusRingPainter({
    required this.color,
    required this.radius,
    this.inset = kFocusRingOffset,
    this.width = kFocusRingWidth,
  });

  final Color color;
  final double radius;
  final double inset;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset + width / 2);
    if (rect.isEmpty) return;
    // [radius] is the ring's outer edge, as a border's is.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular((radius - width / 2).clamp(0, double.infinity)),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(FocusRingPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.inset != inset ||
      old.width != width;
}

/// The hover tint a focused menu item takes, painted under the child so the
/// text and the ink stay on top of it.
class FocusRingFillPainter extends CustomPainter {
  const FocusRingFillPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(FocusRingFillPainter old) =>
      old.color != color || old.radius != radius;
}

/// A 2 px ring in the link colour drawn [kFocusRingOffset] inside [child]'s
/// edge, while the keyboard has focus on [child] or inside it. For a list row
/// or a menu item, which a container clips, so a ring outside would be cut
/// off; [radius] is the row's own. Nothing is drawn for a pointer, and
/// nothing changes in layout.
///
/// [fill] is painted under the ring while it shows, so a focused menu item
/// takes the hover tint.
///
/// With [ownFocus] the ring follows only the child's own focus node, the
/// nearest one below it (the row's ink well), and not one further down: a
/// button inside the row that draws its own ring does not also light the
/// row's. Use it where [child] holds a focusable control of its own.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.radius = 8,
    this.inset = kFocusRingOffset,
    this.fill,
    this.ownFocus = false,
  });

  /// A ring [kFocusRingOffset] outside [child], the way a button's is, for a
  /// control that nothing clips (a floating button, a standalone tap target):
  /// [radius] is the control's own, and the ring's is that plus the offset and
  /// the width. Nothing changes in layout; the paint reaches past the bounds.
  const FocusRing.outside({
    super.key,
    required this.child,
    required double radius,
    this.ownFocus = false,
  }) : radius = radius + kFocusRingOffset + kFocusRingWidth,
       inset = -(kFocusRingOffset + kFocusRingWidth),
       fill = null;

  final Widget child;
  final double radius;

  /// How far inside the child's edge the ring sits.
  final double inset;
  final Color? fill;

  /// Show the ring only while the nearest focus node below this widget has
  /// primary focus, not while a control further down has it.
  final bool ownFocus;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  final _node = FocusNode(
    debugLabel: 'FocusRing',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _focused = false;
  bool _keyboard = keyboardFocusShows;

  @override
  void initState() {
    super.initState();
    _watchInput();
    _inputChanges.addListener(_onInput);
    if (widget.ownFocus) FocusManager.instance.addListener(_onFocusMoved);
  }

  @override
  void didUpdateWidget(FocusRing old) {
    super.didUpdateWidget(old);
    if (old.ownFocus == widget.ownFocus) return;
    if (widget.ownFocus) {
      FocusManager.instance.addListener(_onFocusMoved);
    } else {
      FocusManager.instance.removeListener(_onFocusMoved);
    }
    _onFocusMoved();
  }

  @override
  void dispose() {
    _inputChanges.removeListener(_onInput);
    if (widget.ownFocus) FocusManager.instance.removeListener(_onFocusMoved);
    _node.dispose();
    super.dispose();
  }

  /// Whether the ring's focus state is "focused" for the mode in force.
  bool _shows(bool hasFocus) {
    if (!widget.ownFocus) return hasFocus;
    return hasFocus && FocusManager.instance.primaryFocus?.parent == _node;
  }

  void _onFocusMoved() {
    if (!mounted) return;
    final next = _shows(_node.hasFocus);
    if (next != _focused) setState(() => _focused = next);
  }

  void _onInput() {
    final next = keyboardFocusShows;
    if (next == _keyboard) return;
    _keyboard = next;
    // Only a focused ring paints differently.
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: (focused) => setState(() => _focused = _shows(focused)),
      child: CustomPaint(
        painter: _focused && _keyboard && widget.fill != null
            ? FocusRingFillPainter(color: widget.fill!, radius: widget.radius)
            : null,
        foregroundPainter: _focused && _keyboard
            ? FocusRingPainter(
                color: context.hermesColors.link,
                radius: widget.radius,
                inset: widget.inset,
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

/// What [HostFocusRing] paints: [FocusRingPainter]'s ring, on the render box of
/// a widget above it rather than on its own.
class HostFocusRingPainter extends FocusRingPainter {
  const HostFocusRingPainter({
    required this.owner,
    required this.host,
    required super.color,
    required super.radius,
    super.inset,
    this.maxHeight,
  });

  /// The ring's height at most, from the host's top, for a host that is taller
  /// than what a container shows of it.
  final double? maxHeight;

  /// The element of the [HostFocusRing] that paints, and of the host it rings.
  final Element owner;
  final Element host;

  @override
  void paint(Canvas canvas, Size size) {
    final own = owner.renderObject;
    final target = host.renderObject;
    if (own is! RenderBox || target is! RenderBox) return;
    if (!own.hasSize || !target.hasSize || !target.attached) return;
    canvas
      ..save()
      ..transform(target.getTransformTo(own).storage);
    final height = maxHeight;
    super.paint(
      canvas,
      height == null
          ? target.size
          : Size(target.size.width, math.min(target.size.height, height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HostFocusRingPainter old) =>
      super.shouldRepaint(old) ||
      old.host != host ||
      old.owner != owner ||
      old.maxHeight != maxHeight;
}

/// A [FocusRing] for a control that Material builds around [child] and does
/// not let a wrapper reach: the ring goes 2 px inside the nearest [H] above
/// this widget (an ink well's `ListTile`, a segment's `TextButton`), drawn by
/// [child]'s own paint, so the control's own shape and ink stay as they are.
///
/// It shows while the nearest focus node above it has focus, so [child] must
/// sit inside the control's own ink well, as a title or a label does.
class HostFocusRing<H extends Widget> extends StatefulWidget {
  const HostFocusRing({
    super.key,
    required this.child,
    this.radius = 8,
    this.maxHeight,
  });

  final Widget child;

  /// How much of the host's height is shown, when a container crops it.
  final double? maxHeight;

  /// The ring's outer radius, the host's own corner radius.
  final double radius;

  @override
  State<HostFocusRing<H>> createState() => _HostFocusRingState<H>();
}

class _HostFocusRingState<H extends Widget> extends State<HostFocusRing<H>> {
  bool _keyboard = keyboardFocusShows;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _watchInput();
    _inputChanges.addListener(_onInput);
  }

  @override
  void dispose() {
    _inputChanges.removeListener(_onInput);
    super.dispose();
  }

  void _onInput() {
    final next = keyboardFocusShows;
    if (next == _keyboard) return;
    _keyboard = next;
    // Only a focused ring paints differently; the rest reads it when focus
    // arrives.
    if (_focused) setState(() {});
  }

  Element? _host() {
    Element? host;
    context.visitAncestorElements((element) {
      if (element.widget is H) {
        host = element;
        return false;
      }
      return true;
    });
    return host;
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focused =
        Focus.maybeOf(context, scopeOk: false)?.hasFocus ?? false;
    final host = focused && _keyboard ? _host() : null;
    return CustomPaint(
      foregroundPainter: host == null
          ? null
          : HostFocusRingPainter(
              owner: context as Element,
              host: host,
              color: context.hermesColors.link,
              radius: widget.radius,
              maxHeight: widget.maxHeight,
            ),
      child: widget.child,
    );
  }
}

/// A ring [kFocusRingOffset] outside [child], shown while the nearest focus
/// node above it that takes focus (and is not a scope) has the primary focus,
/// not a row's inert node in between and not a scope or an outer node that
/// holds the focus while nothing nearer does: for a face drawn inside a control that
/// Material builds around it and that takes the focus itself (the
/// `PopupMenuButton` round a row), so [FocusRing.outside], which follows nodes
/// below it, would never light. [radius] is the face's own.
class AncestorFocusRing extends StatefulWidget {
  const AncestorFocusRing.outside({
    super.key,
    required this.child,
    required this.radius,
  });

  final Widget child;
  final double radius;

  @override
  State<AncestorFocusRing> createState() => _AncestorFocusRingState();
}

class _AncestorFocusRingState extends State<AncestorFocusRing> {
  bool _keyboard = keyboardFocusShows;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _watchInput();
    _inputChanges.addListener(_onInput);
    FocusManager.instance.addListener(_onFocusMoved);
  }

  @override
  void dispose() {
    _inputChanges.removeListener(_onInput);
    FocusManager.instance.removeListener(_onFocusMoved);
    super.dispose();
  }

  /// Whether the primary focus is on the nearest node above this widget that
  /// takes focus and is not a scope: not a row's inert node in between, and
  /// not a scope or a node further up that holds the focus while nothing
  /// nearer does.
  bool _ancestorFocused() {
    for (
      FocusNode? node = Focus.maybeOf(context, scopeOk: true);
      node != null;
      node = node.parent
    ) {
      if (node is FocusScopeNode) return false;
      if (node.canRequestFocus) return node.hasPrimaryFocus;
    }
    return false;
  }

  void _onFocusMoved() {
    if (!mounted) return;
    final next = _ancestorFocused();
    if (next != _focused) setState(() => _focused = next);
  }

  void _onInput() {
    final next = keyboardFocusShows;
    if (next == _keyboard) return;
    _keyboard = next;
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _focused = _ancestorFocused();
    return CustomPaint(
      foregroundPainter: _focused && _keyboard
          ? FocusRingPainter(
              color: context.hermesColors.link,
              radius: widget.radius + kFocusRingOffset + kFocusRingWidth,
              inset: -(kFocusRingOffset + kFocusRingWidth),
            )
          : null,
      child: widget.child,
    );
  }
}

/// Builds with whether the keyboard has the last input ([keyboardFocusShows]),
/// and again when a pointer press or a key press changes it, for a control
/// that draws its own focus state and must hide it after a pointer press. An
/// unfocused control is not rebuilt for it ([focused]).
class KeyboardFocusBuilder extends StatefulWidget {
  const KeyboardFocusBuilder({
    super.key,
    required this.focused,
    required this.builder,
  });

  /// Whether the control has focus. Only then does an input change rebuild.
  final bool focused;

  final Widget Function(BuildContext context, bool keyboard) builder;

  @override
  State<KeyboardFocusBuilder> createState() => _KeyboardFocusBuilderState();
}

class _KeyboardFocusBuilderState extends State<KeyboardFocusBuilder> {
  bool _keyboard = keyboardFocusShows;

  @override
  void initState() {
    super.initState();
    _inputChanges.addListener(_onInput);
  }

  @override
  void dispose() {
    _inputChanges.removeListener(_onInput);
    super.dispose();
  }

  void _onInput() {
    final next = keyboardFocusShows;
    if (next == _keyboard) return;
    _keyboard = next;
    if (widget.focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _keyboard);
}

/// The keyboard focus ring of a mini floating button, a circle 2 px outside
/// the painted 40 dp circle whatever box Material lays round it: with a padded
/// tap target (Android, iOS) the button is laid out 48 dp and the ring's outer
/// edge is that box; with a shrink-wrapped one (macOS, Windows, Linux) the box
/// is the circle itself, so the ring goes outside it. The only wrapper for a
/// mini button (`arch.floating-button-without-focus-ring`).
class MiniFabFocusRing extends StatelessWidget {
  const MiniFabFocusRing({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded
      ? FocusRing(radius: 24, inset: 0, child: child)
      : FocusRing.outside(radius: 20, child: child);
}
