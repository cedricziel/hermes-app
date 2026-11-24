import 'package:material_ui/material_ui.dart';

import '../../theme/platform_chrome.dart';
import '../../workspaces/widgets/working_directory_line.dart'
    show isHeaderLargeText;

/// Whether the open chat's title leaves the Material bar for a row under it:
/// from 1.3x text ([kHeaderLargeTextScale], inclusive), where the leading
/// button and three or four 48 dp actions leave the title less than a word's
/// width. iOS and the Mac keep their bars.
bool chatTitleBelowBar(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.material &&
    isHeaderLargeText(context);

/// The bar's `bottom` that holds [text] (and the chat's [avatar]) on up to two
/// lines across the full width, sized to the text at the current scale. The
/// 32 dp avatar is centred on the first line of the title.
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
  const avatarSize = 32.0;
  const gap = 8.0;
  const bottomPadding = 12.0;
  // The bar sits inside a SafeArea, so a cutout at the side narrows the row.
  final insets = MediaQuery.paddingOf(context);
  final width =
      MediaQuery.sizeOf(context).width -
      insets.left -
      insets.right -
      2 * gutter -
      (avatar == null ? 0 : avatarSize + gap);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
  )..layout(maxWidth: width > 0 ? width : 0);
  final textHeight = painter.height;
  final firstLine = painter.computeLineMetrics().first.height;
  painter.dispose();
  // Whichever of the avatar and the first line is shorter is centred on the
  // other.
  final avatarTop = avatar == null || firstLine <= avatarSize
      ? 0.0
      : (firstLine - avatarSize) / 2;
  final textTop = avatar != null && firstLine < avatarSize
      ? (avatarSize - firstLine) / 2
      : 0.0;
  final height = [
    textTop + textHeight,
    if (avatar != null) avatarTop + avatarSize,
  ].reduce((a, b) => a > b ? a : b);
  return PreferredSize(
    preferredSize: Size.fromHeight(height + bottomPadding),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[
            Padding(
              padding: EdgeInsets.only(top: avatarTop),
              child: SizedBox.square(dimension: avatarSize, child: avatar),
            ),
            const SizedBox(width: gap),
          ],
          Expanded(
            // AppBar wraps only its `title` this way; `bottom` gets nothing,
            // so the moved title keeps the header node and the route name.
            child: Padding(
              padding: EdgeInsets.only(top: textTop),
              child: Semantics(
                header: true,
                namesRoute: switch (theme.platform) {
                  TargetPlatform.android ||
                  TargetPlatform.fuchsia ||
                  TargetPlatform.linux ||
                  TargetPlatform.windows => true,
                  TargetPlatform.iOS || TargetPlatform.macOS => null,
                },
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
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
