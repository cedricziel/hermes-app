import 'package:flutter/material.dart';

import '../../macos/mac_toolbar.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../../widgets/settings_scaffold.dart';
import '../schedule_models.dart';

/// The bar's filter button for the job list: every job, or only the failing
/// or paused ones. The button is marked while a filter is on.
class ScheduleFilterMenu extends StatelessWidget {
  const ScheduleFilterMenu({
    super.key,
    required this.filter,
    required this.failingCount,
    required this.onChanged,
  });

  final ScheduleFilter filter;
  final int failingCount;
  final ValueChanged<ScheduleFilter> onChanged;

  List<PopupMenuEntry<ScheduleFilter>> _items(BuildContext context) => [
    for (final (value, label) in [
      (ScheduleFilter.all, 'All tasks'),
      (
        ScheduleFilter.failing,
        failingCount > 0 ? 'Failing ($failingCount)' : 'Failing',
      ),
      (ScheduleFilter.paused, 'Paused'),
    ])
      CheckedPopupMenuItem(
        value: value,
        checked: filter == value,
        child: Text(label),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final active = filter != ScheduleFilter.all;
    final chrome = platformChromeOf(context);
    if (chrome == PlatformChrome.macos) {
      return MacToolbarMenu<ScheduleFilter>(
        key: const Key('schedule-filter'),
        label: 'Filter',
        icon: AppIcons.filter,
        selected: active,
        itemBuilder: _items,
        onSelected: onChanged,
      );
    }
    final background = active
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
        : null;
    return NamedPopupMenuButton<ScheduleFilter>(
      key: const Key('schedule-filter'),
      label: 'Filter',
      icon: AppIcons.filter,
      style: chrome == PlatformChrome.ios
          ? SettingsScaffold.appleBarButtonStyle.copyWith(
              backgroundColor: WidgetStatePropertyAll(background),
            )
          : IconButton.styleFrom(backgroundColor: background),
      itemBuilder: _items,
      onSelected: onChanged,
    );
  }
}
