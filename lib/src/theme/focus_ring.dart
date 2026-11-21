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

/// A button does not rebuild when the input changes, so the focused button is
/// marked dirty and its style resolves again. Only the nearest button is
/// marked, and nothing when the focus is not inside one (a text field, a
/// row, a menu item): [FocusRing] listens on its own.
void _inputChanged() {
  _inputChanges.notify();
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element || !context.mounted) return;
  Element? button;
  context.visitAncestorElements((element) {
    if (element.widget is ButtonStyleButton) {
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
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.radius = 8,
    this.inset = kFocusRingOffset,
    this.fill,
  });

  final Widget child;
  final double radius;

  /// How far inside the child's edge the ring sits.
  final double inset;
  final Color? fill;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;
  bool _keyboard = keyboardFocusShows;

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
    // Only a focused ring paints differently.
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
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
