import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';

/// The smallest a control's target is on this platform: 44 pt on iOS, 48 dp
/// on Material and 28 pt on a Mac, where the pointer is the input.
double toolsTarget(BuildContext context) => switch (platformChromeOf(context)) {
  PlatformChrome.ios => kAppleMinTapTarget,
  PlatformChrome.material => 48.0,
  PlatformChrome.macos => 28.0,
};

/// A button style at the platform's target height. [wide] makes it as wide
/// as the space it is given. The standard density keeps a Mac button at its
/// 28 pt instead of the compact desktop density's 20.
ButtonStyle toolsButtonStyle(BuildContext context, {bool wide = false}) =>
    ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(wide ? double.infinity : 0, toolsTarget(context)),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
