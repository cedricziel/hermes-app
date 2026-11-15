import 'package:flutter/material.dart';

import '../../files/widgets/files_metrics.dart' show isLargeText;
import '../../theme/platform_chrome.dart';

/// Whether the open chat's title leaves the Material bar for a row under it:
/// at a large text size, where the leading button and three or four 48 dp
/// actions leave the title less than a word's width. iOS and the Mac keep
/// their bars.
bool chatTitleBelowBar(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.material &&
    isLargeText(context);

/// The bar's `bottom` that holds [text] (and the chat's [avatar]) on up to two
/// lines across the full width, sized to the text at the current scale.
PreferredSizeWidget chatTitleBelowBarRow(
  BuildContext context, {
  required String text,
  Widget? avatar,
}) {
  final theme = Theme.of(context);
  // The same style for the painter and the text, whatever sits above the bar.
  final style = theme.textTheme.bodyMedium!.merge(
    theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
  );
  const gutter = 16.0;
  const avatarSlot = 40.0;
  const padding = 12.0;
  final width =
      MediaQuery.sizeOf(context).width -
      2 * gutter -
      (avatar == null ? 0 : avatarSlot);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
  )..layout(maxWidth: width > 0 ? width : 0);
  final height = painter.height;
  painter.dispose();
  return PreferredSize(
    preferredSize: Size.fromHeight(height + padding),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[avatar, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The chat's top bar on a narrow layout. On iOS it is a 44pt navigation
/// bar with a centred title and a hairline underneath; elsewhere it is the
/// Material app bar.
AppBar buildChatAppBar(
  BuildContext context, {
  Widget? leading,
  Widget? title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  final ios = platformChromeOf(context) == PlatformChrome.ios;
  final theme = Theme.of(context);
  return AppBar(
    leading: leading,
    title: title,
    actions: actions,
    bottom: bottom,
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
