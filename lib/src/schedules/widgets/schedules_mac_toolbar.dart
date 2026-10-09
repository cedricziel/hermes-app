import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../macos/mac_toolbar.dart';
import '../../theme/app_icons.dart';
import 'schedule_filter_menu.dart';

/// The Schedules toolbar in a Mac window: the title with the number of jobs
/// listed, the profile scope, the status filter, Refresh and New Schedule.
class SchedulesMacToolbar extends StatelessWidget {
  const SchedulesMacToolbar({
    super.key,
    required this.jobCount,
    required this.allProfiles,
    required this.onScopeChanged,
    required this.filterMenu,
    required this.onRefresh,
    required this.onNew,
  });

  final int jobCount;
  final bool allProfiles;
  final ValueChanged<bool> onScopeChanged;

  /// The [ScheduleFilterMenu] for the failing and paused jobs.
  final Widget filterMenu;
  final VoidCallback onRefresh;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => MacToolbar(
    title: 'Schedules',
    subtitle: jobCount == 1 ? '1 job' : '$jobCount jobs',
    border: true,
    actions: [
      // Shrinks rather than overflows in a narrow window.
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ScheduleScopeControl(
            allProfiles: allProfiles,
            onChanged: onScopeChanged,
          ),
        ),
      ),
      const MacToolbarSeparator(),
      filterMenu,
      MacToolbarButton(
        label: 'Refresh',
        icon: AppIcons.refresh,
        onPressed: onRefresh,
      ),
      MacToolbarButton(
        label: 'New Schedule',
        shortcut: '⌘N',
        icon: AppIcons.add,
        onPressed: onNew,
      ),
    ],
  );
}

/// The small segmented control between the active profile's jobs and every
/// profile's.
class ScheduleScopeControl extends StatelessWidget {
  const ScheduleScopeControl({
    super.key,
    required this.allProfiles,
    required this.onChanged,
  });

  final bool allProfiles;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: 12, color: scheme.onSurface),
      ),
    );
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: allProfiles,
      backgroundColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.surface,
      padding: const EdgeInsets.all(2),
      children: {false: label('This profile'), true: label('All profiles')},
      onValueChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
