import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import '../widgets/state_message.dart';
import 'hermes_skills_hub_repository.dart';
import 'skills_hub_controller.dart';
import 'widgets/skill_badges.dart';

/// Featured and official skills, or the results of a hub search, one inset
/// group each. The page's search field and its source filter drive [hub].
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key, required this.hub, required this.onOpen});

  final SkillsHubController hub;
  final ValueChanged<HubSkill> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        switch (hub.status) {
          case HubStatus.loading:
            return const Center(child: CircularProgressIndicator.adaptive());
          case HubStatus.unsupported:
            return const StateMessage(
              title: 'The connected Hermes does not support the skills hub.',
            );
          case HubStatus.failed:
            return StateMessage(
              title: 'Could not load the hub',
              action: FilledButton(
                onPressed: hub.load,
                child: const Text('Retry'),
              ),
            );
          case HubStatus.ready:
            return _list();
        }
      },
    );
  }

  Widget _list() {
    if (hub.isSearch) {
      if (hub.searchFailed) {
        return StateMessage(
          title: 'Could not search the hub',
          action: FilledButton(
            onPressed: hub.retrySearch,
            child: const Text('Retry'),
          ),
        );
      }
      if (hub.searching && hub.results.isEmpty) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      final timedOut = hub.timedOut.length;
      if (hub.results.isEmpty && timedOut == 0) {
        return const StateMessage(title: 'No skills found.');
      }
      return GroupedListView(
        children: [
          if (hub.results.isNotEmpty)
            GroupedSection(
              header: 'Results',
              children: [for (final s in hub.results) _row(s)],
            ),
          if (timedOut > 0)
            GroupedSection(
              children: [
                GroupedRow(
                  title:
                      '$timedOut source${timedOut == 1 ? '' : 's'} '
                      'timed out',
                  leading: const AppIcon(AppIcons.waiting),
                  trailing: TextButton(
                    onPressed: hub.retrySearch,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
        ],
      );
    }
    final featured = hub.featured;
    final official = hub.official;
    if (featured.isEmpty && official.isEmpty) {
      return const StateMessage(title: 'No skills to show.');
    }
    return GroupedListView(
      children: [
        if (featured.isNotEmpty)
          GroupedSection(
            header: 'Featured',
            children: [for (final s in featured) _row(s)],
          ),
        if (official.isNotEmpty)
          GroupedSection(
            header: 'Official',
            children: [for (final s in official) _row(s)],
          ),
      ],
    );
  }

  Widget _row(HubSkill skill) => GroupedRow(
    key: ValueKey('hub-${skill.identifier}'),
    title: skill.name,
    subtitle: [
      trustLabel(skill.trustLevel),
      if (skill.description.isNotEmpty) skill.description,
    ].join(' · '),
    value: hub.isInstalled(skill) ? 'Installed' : null,
    onTap: () => onOpen(skill),
  );
}
