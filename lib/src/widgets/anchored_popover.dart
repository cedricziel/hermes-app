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
  required double Function(BoxConstraints constraints)? measure,
}) {
  final roomAbove = anchor.top - gap - kPopoverEdgeInset;
  final roomBelow = window.height - anchor.bottom - gap - kPopoverEdgeInset;
  final above = preferAbove
      ? roomAbove >= kPopoverMinRoomAbove || roomAbove >= roomBelow
      : roomBelow < kPopoverMinRoomAbove && roomAbove > roomBelow;
  final room = above ? roomAbove : roomBelow;
  final fitted = width.clamp(0, window.width - 2 * kPopoverEdgeInset);
  final limit = (room - 16).clamp(0, maxHeight).toDouble();
  final constraints = BoxConstraints(
    minWidth: fitted.toDouble(),
    maxWidth: fitted.toDouble(),
    maxHeight: limit,
  );
  final height = measure?.call(constraints) ?? limit;
  final maxLeft = window.width - fitted - kPopoverEdgeInset;
  final left = anchor.left.clamp(
    kPopoverEdgeInset,
    maxLeft < kPopoverEdgeInset ? kPopoverEdgeInset : maxLeft,
  );
  final top = above ? anchor.top - gap - height : anchor.bottom + gap;
  return (constraints: constraints, offset: Offset(left.toDouble(), top));
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout({
    required this.anchor,
    required this.width,
    required this.maxHeight,
    required this.gap,
    required this.preferAbove,
  });

  final Rect anchor;
  final double width;
  final double maxHeight;
  final double gap;
  final bool preferAbove;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      layoutPopover(
        window: constraints.biggest,
        anchor: anchor,
        width: width,
        maxHeight: maxHeight,
        gap: gap,
        preferAbove: preferAbove,
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
    measure: (_) => childSize.height,
  ).offset;

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor ||
      old.width != width ||
      old.maxHeight != maxHeight ||
      old.gap != gap ||
      old.preferAbove != preferAbove;
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
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final textScaler = MediaQuery.textScalerOf(context);
  return navigator.push<T>(
    RawDialogRoute<T>(
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
              );
            },
          ),
        ),
      ),
      transitionBuilder: (popover, animation, secondaryAnimation, child) =>
          MediaQuery.disableAnimationsOf(popover)
          ? child
          : FadeTransition(opacity: animation, child: child),
    ),
  );
}
