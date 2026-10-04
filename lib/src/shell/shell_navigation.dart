import 'package:flutter/material.dart';

import '../chat/widgets/thread_sidebar.dart';
import '../macos/mac_sidebar.dart';
import '../macos/mac_source_list.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';

/// One place the shell can show: the icon pair and the label of its entry,
/// and a caption a Mac sidebar shows after the label.
typedef ShellDestination = ({
  AppIconSet icon,
  AppIconSet selected,
  String label,
  String? caption,
});

/// The shell's destinations as sidebar rows: in the sidebar of a wide layout,
/// and at the top of the drawer of a narrow one. Picking one closes the drawer
/// it sits in. On macOS they are source-list rows.
class ShellNavigation extends StatelessWidget {
  const ShellNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return Column(
      children: [
        for (final (i, d) in destinations.indexed)
          if (mac)
            MacSourceListRow(
              icon: d.icon,
              label: d.label,
              caption: d.caption,
              selected: i == selectedIndex,
              onTap: () => _select(context, i),
            )
          else
            SidebarAction(
              icon: i == selectedIndex ? d.selected : d.icon,
              label: d.label,
              selected: i == selectedIndex,
              onTap: () => _select(context, i),
            ),
      ],
    );
  }

  void _select(BuildContext context, int index) {
    Scaffold.maybeOf(context)?.closeDrawer();
    MacSidebarScope.read(context)?.closeOverlay();
    onSelected(index);
  }
}

/// The sidebar next to a page that has no thread list of its own: the same
/// column as the chat's, so the destinations stay where they are.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({super.key, required this.navigation});

  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: macSidebarColor(context, context.hermesColors.sidebar),
      child: SafeArea(
        child: Column(
          children: [
            macSidebarHeader(context) ??
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.hub,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hermes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: navigation,
            ),
            const Spacer(),
            const AccountFooter(),
          ],
        ),
      ),
    );
  }
}

/// Opens the shell's navigation drawer from a page other than Chat on a
/// narrow layout, where there is no sidebar. Chat has a drawer of its own.
class ShellMenu extends InheritedWidget {
  const ShellMenu({
    super.key,
    required this.onOpen,
    this.leadingInset = 0,
    required super.child,
  });

  final VoidCallback onOpen;

  /// Room to leave before the button, for a window control in the corner.
  final double leadingInset;

  /// The menu button for the app bar of a page the shell shows, or null when
  /// the page is not inside a narrow shell and keeps its default leading.
  static Widget? button(BuildContext context) {
    final menu = context.dependOnInheritedWidgetOfExactType<ShellMenu>();
    if (menu == null) return null;
    return clearOfWindowControls(
      context,
      IconButton(
        key: const Key('shell-menu'),
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        icon: const AppIcon(AppIcons.menu),
        onPressed: menu.onOpen,
      ),
    );
  }

  /// [leading] moved clear of the window controls when the page sits in a
  /// collapsed Mac sidebar layout, otherwise as it is.
  static Widget clearOfWindowControls(BuildContext context, Widget leading) {
    final inset =
        context.dependOnInheritedWidgetOfExactType<ShellMenu>()?.leadingInset ??
        0;
    if (inset == 0) return leading;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(left: inset),
        child: leading,
      ),
    );
  }

  @override
  bool updateShouldNotify(ShellMenu oldWidget) =>
      onOpen != oldWidget.onOpen || leadingInset != oldWidget.leadingInset;
}
