import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';
import '../hermes_skills_repository.dart';
import '../skills_controller.dart';
import 'skill_badges.dart';

/// The installed skills of a profile, one inset group per category, each
/// skill a switch row that opens the skill. [onCheckForUpdates] adds a group
/// at the end that updates the hub skills; null leaves it out.
class InstalledSkillsList extends StatelessWidget {
  const InstalledSkillsList({
    super.key,
    required this.groups,
    required this.onOpen,
    required this.onToggle,
    required this.onClearFilters,
    this.onCheckForUpdates,
    this.updating = false,
  });

  final List<SkillGroup> groups;
  final ValueChanged<HermesSkill> onOpen;
  final void Function(HermesSkill skill, bool enabled) onToggle;

  /// Shown when the search and filter leave nothing.
  final VoidCallback onClearFilters;
  final VoidCallback? onCheckForUpdates;

  /// Whether a hub job runs, which keeps the update row closed.
  final bool updating;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return StateMessage(
        title: 'No skills match.',
        action: TextButton(
          onPressed: onClearFilters,
          child: const Text('Clear filters'),
        ),
      );
    }
    final onCheckForUpdates = this.onCheckForUpdates;
    return GroupedListView(
      children: [
        for (final group in groups)
          GroupedSection(
            header: categoryLabel(group.category),
            children: [
              for (final skill in group.skills)
                GroupedSwitchRow(
                  key: ValueKey('skill-${skill.name}'),
                  title: skill.name,
                  subtitle: skillSubtitle(skill),
                  subtitleMaxLines: 2,
                  value: skill.enabled,
                  onChanged: (v) => onToggle(skill, v),
                  onTap: () => onOpen(skill),
                ),
            ],
          ),
        if (onCheckForUpdates != null)
          SkillUpdatesSection(onPressed: updating ? null : onCheckForUpdates),
      ],
    );
  }
}

/// A category as a group's header: "apple" reads "Apple".
String categoryLabel(String category) =>
    _brandedCategories[category.toLowerCase()] ??
    (category.isEmpty
        ? category
        : category[0].toUpperCase() + category.substring(1));

const _brandedCategories = {
  'devops': 'DevOps',
  'github': 'GitHub',
  'gitlab': 'GitLab',
  'mlops': 'MLOps',
  'macos': 'macOS',
  'ios': 'iOS',
};

/// "Read Apple Notes · Bundled · used 14 times".
String skillSubtitle(HermesSkill skill) => [
  if (skill.description.isNotEmpty) skill.description,
  skillSourceLabel(skill.source),
  if (skill.usage == 1) 'used once',
  if (skill.usage > 1) 'used ${skill.usage} times',
].join(' · ');

/// The group that checks the hub skills for updates: a row on iOS and
/// Material, and on macOS a "Hub skills" row with a bordered button.
class SkillUpdatesSection extends StatelessWidget {
  const SkillUpdatesSection({super.key, required this.onPressed});

  /// Null while a job runs.
  final VoidCallback? onPressed;

  static const _label = 'Check for updates';

  @override
  Widget build(BuildContext context) {
    final row = switch (platformChromeOf(context)) {
      PlatformChrome.macos => GroupedRow(
        title: 'Hub skills',
        trailing: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 22),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text(
            'Check for Updates',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
      PlatformChrome.ios => GroupedRow(
        title: _label,
        onTap: onPressed,
        chevron: false,
      ),
      PlatformChrome.material => GroupedRow(
        title: _label,
        leading: const AppIcon(AppIcons.refresh),
        onTap: onPressed,
        chevron: false,
      ),
    };
    return GroupedSection(
      footer: 'Updates the skills installed from the hub.',
      children: [row],
    );
  }
}
