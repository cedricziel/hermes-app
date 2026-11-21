import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/trailing_action_fit.dart';
import '../hermes_messaging_repository.dart';

/// One messaging platform in the platform group: its switch, or a "Set Up"
/// control while it has no credentials and is off. The row opens the setup.
class MessagingPlatformRow extends StatelessWidget {
  const MessagingPlatformRow({
    super.key,
    required this.platform,
    required this.onSetUp,
    required this.onToggle,
  });

  final HermesMessagingPlatform platform;
  final VoidCallback onSetUp;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    const leading = GroupedTile(child: AppIcon(AppIcons.bot));
    final subtitle = platform.description.isEmpty ? null : platform.description;
    if (!platform.configured && !platform.enabled) {
      final chrome = platformChromeOf(context);
      final ios = chrome == PlatformChrome.ios;
      final mac = chrome == PlatformChrome.macos;
      GroupedRow row({bool stacked = false}) => GroupedRow(
        title: platform.name,
        subtitle: subtitle,
        error: platform.errorMessage,
        leading: leading,
        onTap: onSetUp,
        value: ios ? 'Set Up' : null,
        trailing: ios ? null : _SetUpButton(mac: mac, onSetUp),
        trailingBelow: stacked,
      );
      if (ios) return row();
      // Past the width the button fits beside the name, it goes on a line of
      // its own under the text, still its own control.
      return LayoutBuilder(
        builder: (context, box) {
          final metrics = GroupedMetrics.of(context);
          return row(
            stacked: trailingActionStacks(
              context,
              width: box.maxWidth,
              title: platform.name,
              actionLabel: _SetUpButton.label(mac),
              actionStyle: _SetUpButton.labelStyle(mac),
              actionChrome: mac ? 22 : 26,
              leading: metrics.tileSize + metrics.leadingGap,
            ),
          );
        },
      );
    }
    return GroupedSwitchRow(
      title: platform.name,
      subtitle: subtitle,
      // Switched on without its credentials: it can only be switched off.
      warning: platform.configured ? null : 'Needs setup',
      error: platform.errorMessage,
      leading: leading,
      value: platform.enabled,
      onChanged: onToggle,
      onTap: onSetUp,
    );
  }
}

class _SetUpButton extends StatelessWidget {
  const _SetUpButton(this.onPressed, {required this.mac});

  final VoidCallback onPressed;
  final bool mac;

  static String label(bool mac) => mac ? 'Set Up…' : 'Set up';

  static TextStyle labelStyle(bool mac) => TextStyle(
    fontSize: mac ? 12 : 14,
    fontWeight: mac ? FontWeight.w400 : FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.zero,
        // Taps reach the pill across 48 dp; a Mac takes clicks.
        tapTargetSize: mac
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        padding: mac
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mac ? 6 : 999),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.merge(labelStyle(mac)),
      ),
      child: Text(label(mac)),
    );
  }
}
