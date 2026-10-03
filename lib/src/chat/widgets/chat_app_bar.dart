import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';

/// The chat's top bar on a narrow layout. On iOS it is a 44pt navigation
/// bar with a centred title and a hairline underneath; elsewhere it is the
/// Material app bar.
AppBar buildChatAppBar(
  BuildContext context, {
  Widget? leading,
  Widget? title,
  List<Widget>? actions,
}) {
  final ios = platformChromeOf(context) == PlatformChrome.ios;
  final theme = Theme.of(context);
  return AppBar(
    leading: leading,
    title: title,
    actions: actions,
    toolbarHeight: ios ? kAppleNavBarHeight : null,
    centerTitle: ios ? true : null,
    leadingWidth: ios ? kAppleMinTapTarget + 8 : null,
    titleTextStyle: ios
        ? theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 17)
        : null,
    shape: ios
        ? Border(bottom: BorderSide(color: theme.colorScheme.outline))
        : null,
  );
}
