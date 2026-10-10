import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
            child: Text(
              label,
              maxLines: 1,
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
class PillSegmentedControl<T> extends StatelessWidget {
  const PillSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final MapEntry(key: segment, value: label) in segments.entries)
            Expanded(
              child: _PillSegment(
                label: label,
                selected: segment == value,
                onTap: () => onChanged(segment),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  const _PillSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.surface : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: selected ? BorderSide(color: scheme.outline) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ShrinkToFitText(
                label,
                style: TextStyle(
                  fontSize: 14,
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
    );
  }
}
