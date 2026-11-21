import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';

/// Pull to refresh around [child] on every platform but the Mac. iOS gets the
/// adaptive Cupertino spinner. The Mac reloads through its toolbar or menu, so
/// it gets [child] as is.
class PlatformRefresh extends StatefulWidget {
  const PlatformRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.semanticsLabel,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// What a screen reader announces while the spinner shows. The Cupertino
  /// spinner ignores the indicator's own label, so on iOS a polite live
  /// region carries it for as long as the refresh runs.
  final String? semanticsLabel;

  @override
  State<PlatformRefresh> createState() => _PlatformRefreshState();
}

class _PlatformRefreshState extends State<PlatformRefresh> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (mounted) setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    if (chrome == PlatformChrome.macos) return widget.child;
    final indicator = RefreshIndicator.adaptive(
      onRefresh: _refresh,
      semanticsLabel: widget.semanticsLabel,
      child: widget.child,
    );
    final label = widget.semanticsLabel;
    if (chrome != PlatformChrome.ios || label == null) return indicator;
    // The same tree whether idle or refreshing: a root that changed shape
    // would remount the indicator and the list under it mid-refresh. Only
    // the live region's label changes.
    return Stack(
      children: [
        Positioned.fill(child: indicator),
        Positioned(
          top: 0,
          left: 0,
          child: IgnorePointer(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: _refreshing ? label : '',
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
