import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';

/// Pull to refresh around [child] on every platform but the Mac, where a
/// scrolled list has no pull gesture and the screen offers a Refresh button
/// instead.
class PlatformRefresh extends StatelessWidget {
  const PlatformRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      platformChromeOf(context) == PlatformChrome.macos
      ? child
      : RefreshIndicator(onRefresh: onRefresh, child: child);
}
