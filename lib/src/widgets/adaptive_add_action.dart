import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import 'named_icon_button.dart';

/// The "add an item" action of a list screen: a "+" at the trailing edge of
/// the app bar on Apple platforms, which have no floating action button, and
/// an extended [FloatingActionButton] elsewhere.
///
/// Put [toolbarButton] last in `AppBar.actions` and [floatingButton] in
/// `Scaffold.floatingActionButton`; each is null on the other platforms.
class AdaptiveAddAction {
  const AdaptiveAddAction({
    required this.label,
    this.toolbarLabel,
    required this.onPressed,
  });

  /// The floating button's text.
  final String label;

  /// The bar button's accessible name, when [label] is too short to say what
  /// is added.
  final String? toolbarLabel;
  final VoidCallback onPressed;

  Widget? toolbarButton(BuildContext context) {
    if (!platformChromeOf(context).isApple) return null;
    return NamedIconButton(
      label: toolbarLabel ?? label,
      icon: AppIcons.add,
      onPressed: onPressed,
    );
  }

  Widget? floatingButton(BuildContext context) {
    if (platformChromeOf(context).isApple) return null;
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const AppIcon(AppIcons.add),
      label: Text(label),
    );
  }
}
