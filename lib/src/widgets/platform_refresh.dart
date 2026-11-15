import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';

/// Pull to refresh around [child] on every platform but the Mac. iOS gets the
/// adaptive Cupertino spinner. The Mac reloads through its toolbar or menu, so
/// it gets [child] as is.
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
      : RefreshIndicator.adaptive(onRefresh: onRefresh, child: child);
}
