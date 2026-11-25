import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';
import '../../widgets/trailing_action_fit.dart';
import '../../widgets/whats_the_difference_link.dart';
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
    this.onWhatsTheDifference,
    this.header,
  });

  final List<SkillGroup> groups;
  final ValueChanged<HermesSkill> onOpen;
  final void Function(HermesSkill skill, bool enabled) onToggle;

  /// Shown when the search and filter leave nothing.
  final VoidCallback onClearFilters;
  final VoidCallback? onCheckForUpdates;

  /// Whether a hub job runs, which keeps the update row closed.
  final bool updating;

  /// Opens the explanation of tools, skills, plugins and MCP servers; the link
  /// that ends the list. Null leaves it out.
  final VoidCallback? onWhatsTheDifference;

  /// A group above the first category, such as the skill curator. The screen
  /// leaves it out while a search or filter is active.
  final Widget? header;

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
    final header = this.header;
    final onCheckForUpdates = this.onCheckForUpdates;
    final onWhatsTheDifference = this.onWhatsTheDifference;
    return GroupedListView(
      children: [
        ?header,
        for (final group in groups)
          GroupedSection(
            header: categoryLabel(group.category),
            children: [
              for (final skill in group.skills)
                GroupedSwitchRow(
                  key: ValueKey('skill-${skill.name}'),
                  title: skill.name,
                  subtitle: skillSubtitle(context.l10n, skill),
                  subtitleMaxLines: 2,
                  value: skill.enabled,
                  onChanged: (v) => onToggle(skill, v),
                  onTap: () => onOpen(skill),
                ),
            ],
          ),
        if (onCheckForUpdates != null)
          SkillUpdatesSection(onPressed: updating ? null : onCheckForUpdates),
        if (onWhatsTheDifference != null)
          WhatsTheDifferenceFooter(onTap: onWhatsTheDifference),
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
String skillSubtitle(AppLocalizations l10n, HermesSkill skill) => [
  if (skill.description.isNotEmpty) skill.description,
  skillSourceLabel(l10n, skill.source),
  if (skill.usage > 0) l10n.skillsScreenUsed(skill.usage),
].join(' · ');

/// The group that checks the hub skills for updates: a row on iOS and
/// Material, and on macOS a "Hub skills" row with a bordered button.
class SkillUpdatesSection extends StatelessWidget {
  const SkillUpdatesSection({super.key, required this.onPressed});

  /// Null while a job runs.
  final VoidCallback? onPressed;

  static const _label = 'Check for updates';

  static const _hubTitle = 'Hub skills';

  /// The Mac's small bordered button: the theme's label style at 12 pt.
  static ButtonStyle _macButtonStyle(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, 22),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 12),
      ).copyWith(
        shape: focusRingShapeOf(
          context,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final row = switch (platformChromeOf(context)) {
      PlatformChrome.macos => LayoutBuilder(
        builder: (context, box) {
          final label = context.l10n.skillsCheckForUpdatesMac;
          final style = _macButtonStyle(context);
          // Past the width the button fits beside the title, it goes on a
          // line of its own. Its own accessibility node at every size, so a
          // screen reader finds the same controls however large the text.
          return GroupedRow(
            title: _hubTitle,
            separateTrailing: true,
            trailingBelow: trailingActionStacks(
              context,
              width: box.maxWidth,
              title: _hubTitle,
              actionLabel: label,
              buttonStyle: style,
            ),
            trailing: OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            ),
          );
        },
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
