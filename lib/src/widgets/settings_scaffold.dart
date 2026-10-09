import 'package:flutter/material.dart';

import '../macos/mac_toolbar.dart';
import '../macos/mac_window.dart';
import '../shell/shell_navigation.dart';
import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'adaptive_back_button.dart';
import 'adaptive_popup_menu_button.dart';
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

/// A form's Save or Create in a settings page's bar: a text button on iOS
/// and Material, a small push button in the Mac toolbar. While [busy] it
/// shows progress and ignores taps.
class SettingsFormAction {
  const SettingsFormAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool busy;
  final Key? key;

  VoidCallback? get _onPressed => busy ? null : onPressed;

  Widget _progress(double size) => SizedBox.square(
    dimension: size,
    child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
  );

  Widget _mac(BuildContext context) => FilledButton(
    key: key,
    onPressed: _onPressed,
    style: FilledButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    child: busy ? _progress(12) : Text(label),
  );

  Widget _phone(BuildContext context, {required bool ios}) {
    final color = Theme.of(context).colorScheme.primary;
    return TextButton(
      key: key,
      onPressed: _onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(kAppleMinTapTarget, kAppleMinTapTarget),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: ios ? 17 : 16, fontWeight: FontWeight.w600),
      ),
      child: busy ? _progress(18) : Text(label),
    );
  }
}

/// A menu that a settings page's subtitle opens, such as the profiles a page
/// can show; the subtitle then ends in a small chevron.
class SettingsSubtitleMenu<T> {
  const SettingsSubtitleMenu({
    required this.label,
    required this.itemBuilder,
    required this.onSelected,
  });

  /// The button's accessible name, such as "Profile".
  final String label;
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;

  Widget _button(BuildContext context, Widget subtitle) {
    final muted = context.hermesColors.subtleText;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: label,
          child: AdaptivePopupMenuButton<T>(
            key: const Key('settings-subtitle-menu'),
            tooltip: '',
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            onSelected: onSelected,
            itemBuilder: itemBuilder,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Flexible(child: subtitle),
                AppIcon(AppIcons.expandMore, size: 12, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    this.subtitleMenu,
    this.previousTitle = 'Chat',
    this.actions = const [],
    this.tabs,
    this.tabController,
    this.search,
    this.formAction,
    this.cancel = false,
    required this.body,
  });

  final String title;

  /// A muted line under the title, such as "work · 12 skills".
  final String? subtitle;

  /// Makes the [subtitle] a button that opens this menu.
  final SettingsSubtitleMenu<Object?>? subtitleMenu;

  /// The title of the page underneath, which the iOS back button shows.
  final String? previousTitle;
  final List<SettingsBarAction> actions;
  final List<String>? tabs;
  final TabController? tabController;
  final SettingsSearch? search;

  /// A form's Save or Create, at the bar's trailing edge after [actions].
  final SettingsFormAction? formAction;

  /// Leads with Cancel (iOS) or a close button (Material) instead of back,
  /// for a form; the Mac keeps its back button.
  final bool cancel;
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
            subtitleBuilder: subtitleMenu?._button,
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
              if (formAction case final formAction?) ...[
                const SizedBox(width: 4),
                formAction._mac(context),
              ],
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
    // A page the shell shows at the top level opens the shell's drawer.
    final back = Navigator.canPop(context);
    final leading = back
        ? AdaptiveBackButton(previousTitle: previousTitle)
        : ShellMenu.button(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ios ? kAppleNavBarHeight : 56,
        centerTitle: ios,
        automaticallyImplyLeading: false,
        leading: cancel ? _cancelButton(context, ios) : leading,
        leadingWidth: cancel
            ? (ios ? 88 : null)
            : back
            ? adaptiveBackLeadingWidth(context)
            : null,
        title: _BarTitle(
          title: title,
          subtitle: subtitle,
          subtitleMenu: subtitleMenu,
          ios: ios,
        ),
        actions: [
          for (final action in actions) _phoneAction(context, action, ios),
          if (formAction case final formAction?)
            formAction._phone(context, ios: ios),
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

  Widget _cancelButton(BuildContext context, bool ios) {
    if (!ios) return const CloseButton();
    return TextButton(
      onPressed: () => Navigator.maybePop(context),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w400),
      ),
      child: const Text('Cancel'),
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
    required this.subtitleMenu,
    required this.ios,
  });

  final String title;
  final String? subtitle;
  final SettingsSubtitleMenu<Object?>? subtitleMenu;
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
        if (subtitle != null) _subtitle(context, subtitle),
      ],
    );
  }

  Widget _subtitle(BuildContext context, String subtitle) {
    final text = Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: context.hermesColors.subtleText,
      ),
    );
    return subtitleMenu?._button(context, text) ?? text;
  }
}
