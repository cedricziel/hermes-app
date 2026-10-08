import 'package:flutter/material.dart';

import '../macos/mac_toolbar.dart';
import '../macos/mac_window.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'adaptive_back_button.dart';
import 'adaptive_tab_bar.dart';
import 'named_icon_button.dart';
import 'named_popup_menu_button.dart';
import 'settings_search_field.dart';

/// A button in a settings page's bar: an action, or with [SettingsBarAction.menu]
/// a button that opens a menu whose items act through their `onTap`.
class SettingsBarAction {
  const SettingsBarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.shortcut,
    this.key,
  }) : menu = null;

  const SettingsBarAction.menu({
    required this.label,
    required this.icon,
    required PopupMenuItemBuilder<void> this.menu,
    this.key,
  }) : onPressed = null,
       shortcut = null;

  /// The accessible name and tooltip.
  final String label;
  final AppIconSet icon;
  final VoidCallback? onPressed;
  final PopupMenuItemBuilder<void>? menu;

  /// The key equivalent a Mac tooltip shows, such as "⌘N".
  final String? shortcut;
  final Key? key;
}

/// A settings page (Skills, Plugins, MCP servers…) with its platform's bar:
///
/// - iOS: a 44 point bar with a back chevron, the title centered over the
///   [subtitle], [actions] as 44 point icon buttons, then the [tabs] as a
///   segmented control and the [search] field under it.
/// - macOS: the 52 point [MacToolbar] with a back button, the title over the
///   subtitle, and the tabs, search field and actions in the toolbar.
/// - Material: a 56 point bar with a back arrow, the title at the start over
///   the subtitle, the actions, then pill tabs and a pill search field.
///
/// [tabs] drive [tabController], or the nearest [DefaultTabController].
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.previousTitle = 'Chat',
    this.actions = const [],
    this.tabs,
    this.tabController,
    this.search,
    required this.body,
  });

  final String title;

  /// A muted line under the title, such as "work · 12 skills".
  final String? subtitle;

  /// The title of the page underneath, which the iOS back button shows.
  final String? previousTitle;
  final List<SettingsBarAction> actions;
  final List<String>? tabs;
  final TabController? tabController;
  final SettingsSearch? search;
  final Widget body;

  @override
  Widget build(BuildContext context) => switch (platformChromeOf(context)) {
    PlatformChrome.macos => _mac(context),
    PlatformChrome.ios => _phone(context, ios: true),
    PlatformChrome.material => _phone(context, ios: false),
  };

  Widget _mac(BuildContext context) {
    final tabs = this.tabs;
    final search = this.search;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MacToolbar(
            title: title,
            subtitle: subtitle,
            // A page pushed over the whole window sits under the title bar.
            clearTrafficLights:
                MacWindow.enabled && MediaQuery.paddingOf(context).top > 0,
            leading: Navigator.canPop(context)
                ? MacToolbarButton(
                    key: const Key('settings-back'),
                    label: 'Back',
                    shortcut: '⌘[',
                    icon: AppIcons.chevronLeft,
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
            actions: [
              // Both shrink rather than overflow in a narrow window.
              if (tabs != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MacToolbarTabs(
                      controller: tabController,
                      labels: tabs,
                    ),
                  ),
                ),
              if (search != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SettingsSearchField(search: search),
                  ),
                ),
              if ((tabs != null || search != null) && actions.isNotEmpty)
                const MacToolbarSeparator(),
              for (final action in actions) _macAction(action),
            ],
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macAction(SettingsBarAction action) {
    final menu = action.menu;
    if (menu == null) {
      return MacToolbarButton(
        key: action.key,
        label: action.label,
        icon: action.icon,
        shortcut: action.shortcut,
        onPressed: action.onPressed,
      );
    }
    return MacToolbarMenu<void>(
      key: action.key,
      label: action.label,
      icon: action.icon,
      itemBuilder: menu,
      onSelected: (_) {},
    );
  }

  Widget _phone(BuildContext context, {required bool ios}) {
    final tabs = this.tabs;
    final search = this.search;
    final double bottomHeight =
        (tabs == null ? 0 : kTextTabBarHeight) +
        (search == null
            ? 0
            : SettingsSearchField.heightFor(ios: ios) + _searchBottomGap);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ios ? kAppleNavBarHeight : 56,
        centerTitle: ios,
        leading: AdaptiveBackButton(previousTitle: previousTitle),
        leadingWidth: adaptiveBackLeadingWidth(context),
        title: _BarTitle(title: title, subtitle: subtitle, ios: ios),
        actions: [
          for (final action in actions) _phoneAction(context, action, ios),
          SizedBox(width: ios ? 4 : 8),
        ],
        bottom: bottomHeight == 0
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(bottomHeight),
                child: Column(
                  children: [
                    if (tabs != null)
                      AdaptiveTabBar(controller: tabController, labels: tabs),
                    if (search != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          _searchBottomGap,
                        ),
                        child: SettingsSearchField(search: search),
                      ),
                  ],
                ),
              ),
      ),
      body: body,
    );
  }

  Widget _phoneAction(
    BuildContext context,
    SettingsBarAction action,
    bool ios,
  ) {
    final style = ios
        ? IconButton.styleFrom(
            fixedSize: const Size.square(kAppleMinTapTarget),
            minimumSize: const Size.square(kAppleMinTapTarget),
            padding: EdgeInsets.zero,
            iconSize: 22,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;
    final menu = action.menu;
    if (menu == null) {
      return NamedIconButton(
        key: action.key,
        label: action.label,
        icon: action.icon,
        style: style,
        onPressed: action.onPressed,
      );
    }
    return NamedPopupMenuButton<void>(
      key: action.key,
      label: action.label,
      icon: action.icon,
      style: style,
      itemBuilder: menu,
    );
  }
}

const double _searchBottomGap = 8;

class _BarTitle extends StatelessWidget {
  const _BarTitle({
    required this.title,
    required this.subtitle,
    required this.ios,
  });

  final String title;
  final String? subtitle;
  final bool ios;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: ios
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ios ? 17 : 18,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: context.hermesColors.subtleText,
            ),
          ),
      ],
    );
  }
}
