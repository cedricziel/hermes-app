import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';

/// The back button of a pushed screen: on iOS a chevron with the title of the
/// screen underneath, elsewhere the stock [BackButton], which already draws a
/// chevron on macOS.
///
/// Pass it as `AppBar.leading` together with
/// `leadingWidth: adaptiveBackLeadingWidth(context)`. It draws nothing when
/// there is no route to go back to.
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({super.key, this.previousTitle});

  /// The title of the screen underneath, or null to show "Back".
  final String? previousTitle;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    if (platformChromeOf(context) != PlatformChrome.ios) {
      return const BackButton();
    }
    return CupertinoNavigationBarBackButton(
      previousPageTitle: previousTitle,
      color: Theme.of(context).colorScheme.primary,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The `AppBar.leadingWidth` that leaves room for the iOS label, or null for
/// the default.
double? adaptiveBackLeadingWidth(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.ios ? 120 : null;
