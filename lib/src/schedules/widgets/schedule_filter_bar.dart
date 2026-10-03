import 'package:flutter/material.dart';

import '../schedule_models.dart';

/// The profile and status chips above the job list. They wrap onto a second
/// line rather than scroll, so none of them sits out of view.
class ScheduleFilterBar extends StatelessWidget {
  const ScheduleFilterBar({
    super.key,
    required this.activeProfile,
    required this.allProfiles,
    required this.filter,
    required this.failingCount,
    required this.onAllProfilesChanged,
    required this.onFilterChanged,
  });

  final String? activeProfile;
  final bool allProfiles;
  final ScheduleFilter filter;
  final int failingCount;
  final ValueChanged<bool> onAllProfilesChanged;
  final ValueChanged<ScheduleFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final profile = activeProfile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (profile != null)
            ChoiceChip(
              label: Text('$profile (active)', overflow: TextOverflow.ellipsis),
              selected: !allProfiles,
              onSelected: (_) => onAllProfilesChanged(false),
            ),
          ChoiceChip(
            label: const Text('All profiles'),
            selected: allProfiles || profile == null,
            onSelected: (_) => onAllProfilesChanged(true),
          ),
          FilterChip(
            label: Text(
              failingCount > 0 ? 'Failing ($failingCount)' : 'Failing',
            ),
            selected: filter == ScheduleFilter.failing,
            onSelected: (on) => onFilterChanged(
              on ? ScheduleFilter.failing : ScheduleFilter.all,
            ),
          ),
          FilterChip(
            label: const Text('Paused'),
            selected: filter == ScheduleFilter.paused,
            onSelected: (on) => onFilterChanged(
              on ? ScheduleFilter.paused : ScheduleFilter.all,
            ),
          ),
        ],
      ),
    );
  }
}
