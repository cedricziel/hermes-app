import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';
import 'adaptive_tab_bar.dart'
    show
        PillSegmentedControl,
        kCompactMacSegmentedHeight,
        kCompactSegmentedHeight;
import 'shrink_to_fit_text.dart';

/// A choice between a few [segments], in the platform's own control and a
/// compact size:
///
/// - iOS and macOS: a sliding segmented control whose selected segment sits on
///   a raised thumb with a semibold label; in dark mode the thumb is lighter
///   than the track.
/// - Android: Material's segmented button, a check in the selected segment.
/// - Windows and Linux: the [PillSegmentedControl] in its compact size.
///
/// The control looks [visualHeight] high (28 pt, 22 pt on a Mac) but its tap
/// area is [hitHeight] high (44 pt on iOS, 48 dp on Android, Windows and Linux,
/// 28 pt on a Mac) and as wide as the control: a tap above or below it picks
/// the segment it is over. A parent's bounds stop hit testing, so the control
/// takes that height in its layout and centres itself in it; put it in a row
/// with no padding above or below.
///
/// The selected segment is told by its shape (thumb, check, weight), never by
/// colour alone. [semanticLabel] names the group for a screen reader.
class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  const AdaptiveSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.semanticLabel,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  /// How high the control looks on the platform of [context].
  static double visualHeight(BuildContext context) =>
      platformChromeOf(context) == PlatformChrome.macos
      ? kCompactMacSegmentedHeight
      : kCompactSegmentedHeight;

  /// How high its tap area is on the platform of [context].
  static double hitHeight(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.iOS => kAppleMinTapTarget,
        TargetPlatform.macOS => 28,
        _ => kMaterialMinTapTarget,
      };

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final control = switch (platform) {
      TargetPlatform.iOS => _ios(context),
      TargetPlatform.macOS => _mac(context),
      TargetPlatform.android => _material(context),
      _ => PillSegmentedControl<T>(
        value: value,
        segments: segments,
        onChanged: onChanged,
        compact: true,
      ),
    };
    final visual = visualHeight(context);
    final hit = hitHeight(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: _ExtendedHitArea<T>(
        height: hit,
        keys: segments.keys.toList(),
        onPick: onChanged,
        // The control is fixed in height, so its labels stop growing at 1.3x;
        // the row around it wraps at larger text.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(height: visual, child: control),
        ),
      ),
    );
  }

  Color _track(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).brightness == Brightness.dark
        ? scheme.surface
        : scheme.surfaceContainerHighest;
  }

  /// The raised thumb: white on the light track, and in dark mode visibly
  /// lighter than the (darkest) track.
  Color _thumb(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.16),
            scheme.surfaceContainerHighest,
          )
        : scheme.surface;
  }

  /// A Mac's control is 22 pt high, under the 28 pt minimum of Cupertino's
  /// own, so it is the pill with a rounded-rectangle track.
  Widget _mac(BuildContext context) => PillSegmentedControl<T>(
    value: value,
    segments: segments,
    onChanged: onChanged,
    compact: true,
    height: kCompactMacSegmentedHeight,
    cornerRadius: 6,
    trackColor: _track(context),
    thumbColor: _thumb(context),
  );

  Widget _ios(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: _track(context),
      thumbColor: _thumb(context),
      padding: EdgeInsets.zero,
      children: {
        for (final MapEntry(key: segment, value: label) in segments.entries)
          segment: Semantics(
            button: true,
            selected: segment == value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ShrinkToFitText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: segment == value
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
      },
      onValueChanged: (segment) {
        if (segment != null) onChanged(segment);
      },
    );
  }

  Widget _material(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: true,
    selected: {value},
    onSelectionChanged: (selected) => onChanged(selected.first),
    style: SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(0, kCompactSegmentedHeight),
      maximumSize: const Size(double.infinity, kCompactSegmentedHeight),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      iconSize: 14,
      textStyle:
          Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12) ??
          const TextStyle(fontSize: 12),
    ),
    segments: [
      for (final MapEntry(key: segment, value: label) in segments.entries)
        ButtonSegment<T>(value: segment, label: Text(label, maxLines: 1)),
    ],
  );
}

/// [child], centred in a box [height] high, where a tap on the part above or
/// below the child counts as a tap on the segment that is level with it. The
/// child's own taps are untouched: its recogniser is deeper and wins the tap.
class _ExtendedHitArea<T> extends StatelessWidget {
  const _ExtendedHitArea({
    required this.height,
    required this.keys,
    required this.onPick,
    required this.child,
  });

  final double height;
  final List<T> keys;
  final ValueChanged<T> onPick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final width = (context.findRenderObject() as RenderBox).size.width;
        if (width <= 0 || keys.isEmpty) return;
        var index = (details.localPosition.dx / width * keys.length)
            .floor()
            .clamp(0, keys.length - 1);
        if (rtl) index = keys.length - 1 - index;
        onPick(keys[index]);
      },
      child: SizedBox(
        height: height,
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }
}
