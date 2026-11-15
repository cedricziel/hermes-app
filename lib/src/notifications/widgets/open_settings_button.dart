import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';

/// The row under a denied notification permission that opens the system's
/// settings for the app: a text button, never filled. It is a row of its own
/// in the section, not part of the switch row above, so a screen reader finds
/// the switch and the button apart. The button is 48 dp tall on Material, 44
/// pt on iOS and 28 pt on the Mac, in the size the grouped rows set their
/// titles. Takes only the callback, so a catalog entry or a test can place it
/// without a dialog.
class OpenSettingsButton extends StatelessWidget {
  const OpenSettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final chrome = platformChromeOf(context);
    final height = switch (chrome) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: metrics.rowPadding),
          child: TextButton.icon(
            key: const Key('notifications-open-settings'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(48, height),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: metrics.titleSize,
                fontWeight: chrome.isApple ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
            onPressed: onPressed,
            icon: AppIcon(AppIcons.settings, size: metrics.titleSize + 1),
            label: Text(context.l10n.notificationsOpenSettings),
          ),
        ),
      ),
    );
  }
}
