import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';

/// The switch between views of the same content, for `AppBar.bottom`: a
/// [TabBar] on Material, a sliding segmented control on Apple platforms.
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
    if (!platformChromeOf(context).isApple) {
      return TabBar(
        controller: controller,
        tabs: [for (final label in labels) Tab(text: label)],
      );
    }
    final tabs = controller ?? DefaultTabController.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: kTextTabBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ListenableBuilder(
          listenable: tabs.animation ?? tabs,
          builder: (context, _) => CupertinoSlidingSegmentedControl<int>(
            groupValue: tabs.index,
            backgroundColor: scheme.surfaceContainerHighest,
            thumbColor: scheme.surface,
            children: {
              for (final (i, label) in labels.indexed)
                i: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label, style: TextStyle(color: scheme.onSurface)),
                ),
            },
            onValueChanged: (value) {
              if (value != null) tabs.animateTo(value);
            },
          ),
        ),
      ),
    );
  }
}
