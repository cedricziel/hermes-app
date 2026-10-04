import 'package:flutter/material.dart';

import '../shell/shell_navigation.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import 'mac_sidebar.dart';
import '../widgets/named_icon_button.dart';
import 'mac_window.dart';

/// The unified toolbar at the top of a page in a Mac window: 52 points high,
/// a title with an optional subtitle, and [actions] at the trailing edge.
///
/// Where no sidebar sits to its left (the sidebar is hidden, or the window is
/// too narrow for one) it leaves room for the traffic lights and starts with
/// a button that shows the sidebar.
class MacToolbar extends StatelessWidget {
  const MacToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.border = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Draws a hairline under the bar, for a page whose content does not start
  /// with a surface of its own.
  final bool border;

  @override
  Widget build(BuildContext context) {
    final menu = context.dependOnInheritedWidgetOfExactType<ShellMenu>();
    final sidebar = MacSidebarScope.maybeOf(context);
    final theme = Theme.of(context);
    return MacWindowDragArea(
      child: Container(
        height: kMacToolbarHeight,
        decoration: border
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              )
            : null,
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            if (menu != null) ...[
              const SizedBox(width: kMacTrafficLightsWidth),
              if (sidebar != null)
                MacSidebarToggle(controller: sidebar)
              else
                MacToolbarButton(
                  key: const Key('shell-menu'),
                  label: MaterialLocalizations.of(context).openAppDrawerTooltip,
                  icon: AppIcons.menu,
                  onPressed: menu.onOpen,
                ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 20),
            Expanded(
              child: MacToolbarTitle(title: title, subtitle: subtitle),
            ),
            for (final action in actions) ...[const SizedBox(width: 4), action],
          ],
        ),
      ),
    );
  }
}

/// A toolbar's title in 13 point bold, with an optional 11 point muted line
/// under it.
class MacToolbarTitle extends StatelessWidget {
  const MacToolbarTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final subtitle = this.subtitle;
    final muted = context.hermesColors.subtleText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.25, color: muted),
          ),
      ],
    );
  }
}

/// A borderless 28 point toolbar button with an 18 point icon, as in a Mac
/// app's toolbar. It fills while the pointer is over it, and stays filled
/// while [selected], for a toggle such as an inspector's.
///
/// Its hover text is [label] followed by [shortcut], e.g. "New Task ⌘N";
/// screen readers get [label] alone.
class MacToolbarButton extends StatelessWidget {
  const MacToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.shortcut,
    this.selected,
  });

  final String label;
  final AppIconSet icon;
  final VoidCallback? onPressed;

  /// The key equivalent shown after the label in the tooltip, e.g. "⌘N".
  final String? shortcut;

  /// Whether a toggle is on; null for a plain button.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final shortcut = this.shortcut;
    return NamedIconButton(
      label: label,
      tooltip: shortcut == null ? label : '$label $shortcut',
      icon: icon,
      isSelected: selected,
      onPressed: onPressed,
      style: macToolbarButtonStyle(context),
    );
  }
}

/// The look of a [MacToolbarButton], for a toolbar control built on another
/// button, such as a menu.
ButtonStyle macToolbarButtonStyle(BuildContext context) {
  final onSurface = Theme.of(context).colorScheme.onSurface;
  return IconButton.styleFrom(
    fixedSize: const Size.square(28),
    minimumSize: const Size.square(28),
    padding: EdgeInsets.zero,
    iconSize: 18,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    hoverColor: onSurface.withValues(alpha: 0.06),
    highlightColor: onSurface.withValues(alpha: 0.1),
  ).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? onSurface.withValues(alpha: 0.1)
          : null,
    ),
  );
}

/// The 1 by 20 point rule between groups of toolbar buttons.
class MacToolbarSeparator extends StatelessWidget {
  const MacToolbarSeparator({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Theme.of(context).dividerColor,
  );
}
