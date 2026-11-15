import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The room a popover needs above its anchor before it opens there rather
/// than below.
const double kPopoverMinRoomAbove = 240;

/// The least distance a popover keeps from the window's edge.
const double kPopoverEdgeInset = 8;

/// Where a popover of [size] goes: the left edge on [anchor]'s, [gap] above
/// it (below it when there is under [kPopoverMinRoomAbove] above, or
/// [preferAbove] is off and the room below is enough), kept
/// [kPopoverEdgeInset] inside the window of [window].
///
/// [maxHeight] is the tallest it may be; the room on the chosen side, less
/// 16, caps it further. Returns the child's constraints and its top left.
({BoxConstraints constraints, Offset offset}) layoutPopover({
  required Size window,
  required Rect anchor,
  required double width,
  required double maxHeight,
  required double gap,
  required bool preferAbove,
  TextDirection textDirection = TextDirection.ltr,
  required double Function(BoxConstraints constraints)? measure,
}) {
  const inset = kPopoverEdgeInset;
  final roomAbove = anchor.top - gap - kPopoverEdgeInset;
  final roomBelow = window.height - anchor.bottom - gap - kPopoverEdgeInset;
  final above = preferAbove
      ? roomAbove >= kPopoverMinRoomAbove || roomAbove >= roomBelow
      : roomBelow < kPopoverMinRoomAbove && roomAbove > roomBelow;
  final room = above ? roomAbove : roomBelow;
  final fitted = math.min(width, math.max(0.0, window.width - 2 * inset));
  final limit = math.max(0.0, math.min(maxHeight, room - 16));
  final constraints = BoxConstraints(
    minWidth: fitted,
    maxWidth: fitted,
    maxHeight: limit,
  );
  final height = math.min(measure?.call(constraints) ?? limit, limit);
  final maxLeft = math.max(inset, window.width - fitted - inset);
  final wanted = textDirection == TextDirection.rtl
      ? anchor.right - fitted
      : anchor.left;
  final left = wanted.clamp(inset, maxLeft);
  // The anchor was read when the popover opened and can be stale: keep the
  // popover inside the window whatever it says.
  final maxTop = math.max(inset, window.height - inset - height);
  final top = (above ? anchor.top - gap - height : anchor.bottom + gap).clamp(
    inset,
    maxTop,
  );
  return (constraints: constraints, offset: Offset(left, top));
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout({
    required this.anchor,
    required this.width,
    required this.maxHeight,
    required this.gap,
    required this.preferAbove,
    required this.textDirection,
  });

  final Rect anchor;
  final double width;
  final double maxHeight;
  final double gap;
  final bool preferAbove;
  final TextDirection textDirection;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      layoutPopover(
        window: constraints.biggest,
        anchor: anchor,
        width: width,
        maxHeight: maxHeight,
        gap: gap,
        preferAbove: preferAbove,
        textDirection: textDirection,
        measure: null,
      ).constraints;

  @override
  Offset getPositionForChild(Size size, Size childSize) => layoutPopover(
    window: size,
    anchor: anchor,
    width: width,
    maxHeight: maxHeight,
    gap: gap,
    preferAbove: preferAbove,
    textDirection: textDirection,
    measure: (_) => childSize.height,
  ).offset;

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor ||
      old.width != width ||
      old.maxHeight != maxHeight ||
      old.gap != gap ||
      old.preferAbove != preferAbove ||
      old.textDirection != textDirection;
}

/// Lets the owner of an anchor close its popover from outside, such as a pill
/// that leaves the tree while the popover is open.
class PopoverHandle {
  NavigatorState? _navigator;
  Route<Object?>? _route;

  void _attach(NavigatorState navigator, Route<Object?> route) {
    _navigator = navigator;
    _route = route;
  }

  /// Removes the popover if it is still open. Safe to call at any time.
  void close() {
    final navigator = _navigator;
    final route = _route;
    _navigator = null;
    _route = null;
    if (navigator == null || route == null) return;
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}

/// Shows what [builder] makes as a popover on [anchor], a rectangle in global
/// coordinates read when it opens (never a context, so it cannot go stale
/// across the await). A tap outside or Escape closes it with no result; focus
/// goes back to where it was. No arrow; [semanticLabel] names the route.
///
/// For desktop windows. The surface is the Mac menu's: the page colour, a
/// hairline in the outline colour, a 10 pt radius and a soft shadow.
Future<T?> showAnchoredPopover<T>(
  BuildContext context, {
  required Rect anchor,
  required WidgetBuilder builder,
  required String semanticLabel,
  double width = 360,
  double maxHeight = 480,
  double gap = 6,
  bool preferAbove = true,
  PopoverHandle? handle,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final textScaler = MediaQuery.textScalerOf(context);
  final route = RawDialogRoute<T>(
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    pageBuilder: (popover, animation, secondaryAnimation) => MediaQuery(
      data: MediaQuery.of(popover).copyWith(textScaler: textScaler),
      child: themes.wrap(
        Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return CustomSingleChildLayout(
              delegate: _PopoverLayout(
                anchor: anchor,
                width: width,
                maxHeight: maxHeight,
                gap: gap,
                preferAbove: preferAbove,
                textDirection: Directionality.of(context),
              ),
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: {
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) {
                        Navigator.of(popover).maybePop();
                        return null;
                      },
                    ),
                  },
                  child: _CloseOnResize(
                    child: Semantics(
                      scopesRoute: true,
                      namesRoute: true,
                      label: semanticLabel,
                      explicitChildNodes: true,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Material(
                          color: scheme.surface,
                          elevation: 8,
                          shadowColor: Colors.black54,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: scheme.outline),
                          ),
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    transitionBuilder: (popover, animation, secondaryAnimation, child) =>
        MediaQuery.disableAnimationsOf(popover)
        ? child
        : FadeTransition(opacity: animation, child: child),
  );
  handle?._attach(navigator, route);
  return navigator.push<T>(route);
}

/// Closes the route it sits in when the window's size changes: the anchor was
/// read when the popover opened and no longer says where its pill is.
class _CloseOnResize extends StatefulWidget {
  const _CloseOnResize({required this.child});

  final Widget child;

  @override
  State<_CloseOnResize> createState() => _CloseOnResizeState();
}

class _CloseOnResizeState extends State<_CloseOnResize> {
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final before = _size;
    _size = size;
    if (before != null && before != size) {
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
