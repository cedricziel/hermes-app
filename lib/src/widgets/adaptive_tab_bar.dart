import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/focus_ring.dart';
import '../theme/platform_chrome.dart';
import 'shrink_to_fit_text.dart';

/// The switch between views of the same content, for `AppBar.bottom`: a
/// sliding segmented control on Apple platforms and a [PillSegmentedControl]
/// on Material.
///
/// Both read and drive [controller], or the nearest [DefaultTabController]
/// when it is null, so the [TabBarView] below needs no change.
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveTabBar({super.key, this.controller, required this.labels});

  final TabController? controller;
  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final tabs = controller ?? DefaultTabController.of(context);
    final apple = platformChromeOf(context).isApple;
    return SizedBox(
      height: kTextTabBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        // The bar's height is fixed by [preferredSize], so its labels stop
        // growing past 1.3x instead of overflowing it at large text.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: ListenableBuilder(
            listenable: tabs.animation ?? tabs,
            builder: (context, _) => apple
                ? _CupertinoTabs(tabs: tabs, labels: labels)
                : PillSegmentedControl<int>(
                    value: tabs.index,
                    segments: {for (final (i, l) in labels.indexed) i: l},
                    onChanged: tabs.animateTo,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The tabs of a page in a Mac toolbar: a compact segmented control that
/// drives [controller], or the nearest [DefaultTabController].
class MacToolbarTabs extends StatelessWidget {
  const MacToolbarTabs({super.key, this.controller, required this.labels});

  final TabController? controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tabs = controller ?? DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: tabs.animation ?? tabs,
      builder: (context, _) =>
          _CupertinoTabs(tabs: tabs, labels: labels, compact: true),
    );
  }
}

class _CupertinoTabs extends StatelessWidget {
  const _CupertinoTabs({
    required this.tabs,
    required this.labels,
    this.compact = false,
  });

  final TabController tabs;
  final List<String> labels;

  /// The small control of a Mac toolbar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: tabs.index,
      backgroundColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.surface,
      padding: compact
          ? const EdgeInsets.all(2)
          : const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      children: {
        for (final (i, label) in labels.indexed)
          i: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ShrinkToFitText(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : null,
                color: scheme.onSurface,
              ),
            ),
          ),
      },
      onValueChanged: (value) {
        if (value != null) tabs.animateTo(value);
      },
    );
  }
}

/// Material's segmented control as a pill: the segments share the width of
/// a rounded track and the selected one sits on a raised thumb.
///
/// With [compact] the pill is [kCompactSegmentedHeight] high (or [height]),
/// takes only the width its labels need and sets them at 12; the full size is
/// unchanged. [cornerRadius] makes the track and thumb rounded rectangles
/// instead of stadiums, and [trackColor] and [thumbColor] replace the theme's.
class PillSegmentedControl<T> extends StatelessWidget {
  const PillSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.compact = false,
    this.height,
    this.cornerRadius,
    this.trackColor,
    this.thumbColor,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;
  final bool compact;
  final double? height;
  final double? cornerRadius;
  final Color? trackColor;
  final Color? thumbColor;

  ShapeBorder _shape({BorderSide side = BorderSide.none, double inset = 0}) =>
      cornerRadius == null
      ? StadiumBorder(side: side)
      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius! - inset),
          side: side,
        );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height ?? (compact ? kCompactSegmentedHeight : 36),
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: ShapeDecoration(
        color: trackColor ?? scheme.surfaceContainerHighest,
        shape: _shape(),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final MapEntry(key: segment, value: label) in segments.entries)
            if (compact)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: _PillSegment(
                  label: label,
                  selected: segment == value,
                  onTap: () => onChanged(segment),
                  compact: true,
                  thumbColor: thumbColor,
                  shape: _shape,
                ),
              )
            else
              Expanded(
                child: _PillSegment(
                  label: label,
                  selected: segment == value,
                  onTap: () => onChanged(segment),
                  thumbColor: thumbColor,
                  shape: _shape,
                ),
              ),
        ],
      ),
    );
  }
}

/// The height of a compact segmented control on touch and desktop platforms;
/// a Mac's is [kCompactMacSegmentedHeight].
const double kCompactSegmentedHeight = 28;

/// The height of a compact segmented control on a Mac.
const double kCompactMacSegmentedHeight = 22;

class _PillSegment extends StatelessWidget {
  const _PillSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.shape,
    this.thumbColor,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final Color? thumbColor;
  final ShapeBorder Function({BorderSide side, double inset}) shape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segmentShape = shape(
      side: selected ? BorderSide(color: scheme.outline) : BorderSide.none,
      inset: compact ? 2 : 3,
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? thumbColor ?? scheme.surface : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: segmentShape,
        child: FocusRing(
          radius: segmentShape is RoundedRectangleBorder
              ? (segmentShape.borderRadius as BorderRadius).topLeft.x
              : 999,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 6),
                child: ShrinkToFitText(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
