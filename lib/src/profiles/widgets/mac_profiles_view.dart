import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../macos/mac_source_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../hermes_profiles_repository.dart';
import 'profile_avatar.dart';
import '../../macos/menu_selection_area.dart';

/// What a profile's home holds, by the screen that manages it. Its words come
/// from [profileSectionTitle] and [profileSectionDetail].
enum ProfileSection {
  skills(AppIcons.sparkle),
  memory(AppIcons.memory),

  /// Hidden through `hiddenSections` while the server lacks the route.
  personality(AppIcons.personality),
  messaging(AppIcons.bot),
  plugins(AppIcons.extension),
  mcp(AppIcons.power),
  providers(AppIcons.hub),

  /// Hidden through `hiddenSections` unless the server offers Tools.
  tools(AppIcons.wrench),
  helperModels(AppIcons.tune);

  const ProfileSection(this.icon);

  final AppIconSet icon;
}

/// The name of [section]'s row.
String profileSectionTitle(AppLocalizations l10n, ProfileSection section) =>
    switch (section) {
      ProfileSection.skills => l10n.skillsScreenTitle,
      ProfileSection.memory => l10n.memoryTitle,
      ProfileSection.personality => l10n.profilesSoulTitle,
      ProfileSection.messaging => l10n.profilesSectionMessagingTitle,
      ProfileSection.plugins => l10n.profilesSectionPluginsTitle,
      ProfileSection.mcp => l10n.profilesSectionMcpTitle,
      ProfileSection.providers => l10n.providersListTitle,
      ProfileSection.tools => l10n.toolsTitle,
      ProfileSection.helperModels => l10n.settingsHelperModelsTitle,
    };

/// The line under [section]'s name.
String profileSectionDetail(AppLocalizations l10n, ProfileSection section) =>
    switch (section) {
      ProfileSection.skills => l10n.profilesSectionSkillsDetail,
      ProfileSection.memory => l10n.profilesSectionMemoryDetail,
      ProfileSection.personality => l10n.profilesSoulRowDetail,
      ProfileSection.messaging => l10n.profilesSectionMessagingDetail,
      ProfileSection.plugins => l10n.profilesSectionPluginsDetail,
      ProfileSection.mcp => l10n.profilesSectionMcpDetail,
      ProfileSection.providers => l10n.providersProfileSectionDetail,
      ProfileSection.tools => l10n.toolsProfileDetail,
      ProfileSection.helperModels => l10n.profilesSectionHelperModelsDetail,
    };

/// The Profiles page of a Mac window: the profiles in a 220pt column, and the
/// selected one's home with what it holds.
class MacProfilesView extends StatelessWidget {
  const MacProfilesView({
    super.key,
    required this.profiles,
    required this.selected,
    required this.onSelect,
    required this.counts,
    required this.onOpen,
    this.memoryWaiting,
    this.hiddenSections = const {},
    this.toolsCount,
  });

  final List<HermesProfile> profiles;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// How many of each the selected profile holds; a section without a count
  /// (still loading, or it could not be read) shows none.
  final Map<ProfileSection, int> counts;
  final ValueChanged<ProfileSection> onOpen;

  /// How many staged memory changes wait in the selected profile.
  final int? memoryWaiting;

  /// Sections this server does not offer.
  final Set<ProfileSection> hiddenSections;

  /// How many of the selected profile's tools are on, and how many there are;
  /// none while unread.
  final ({int on, int total})? toolsCount;

  @override
  Widget build(BuildContext context) {
    final profile = profiles.where((p) => p.name == selected).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final p in profiles)
                MacProfileRow(
                  key: ValueKey('profile-row-${p.name}'),
                  profile: p,
                  selected: p.name == selected,
                  onTap: () => onSelect(p.name),
                ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: profile == null
              ? const SizedBox.shrink()
              : MacProfileDetail(
                  profile: profile,
                  counts: counts,
                  onOpen: onOpen,
                  memoryWaiting: memoryWaiting,
                  hiddenSections: hiddenSections,
                  toolsCount: toolsCount,
                ),
        ),
      ],
    );
  }
}

/// A profile in the Profiles page's list: avatar, name and description.
class MacProfileRow extends StatelessWidget {
  const MacProfileRow({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final HermesProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    return Semantics(
      button: true,
      selected: selected,
      child: MacSourceListTile(
        height: 44,
        selected: selected,
        onTap: onTap,
        builder: (context, _) => Row(
          children: [
            InitialsAvatar(label: profile.label, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (profile.description.isNotEmpty)
                    Text(
                      profile.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: subtle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One profile's home: its name and path (selectable, to copy), then a group of what it holds
/// with a count each, and a note on what else lives there.
class MacProfileDetail extends StatelessWidget {
  const MacProfileDetail({
    super.key,
    required this.profile,
    required this.counts,
    required this.onOpen,
    this.memoryWaiting,
    this.hiddenSections = const {},
    this.toolsCount,
  });

  final HermesProfile profile;
  final Map<ProfileSection, int> counts;
  final ValueChanged<ProfileSection> onOpen;

  /// Shown for Memory in place of its entry count while changes wait.
  final int? memoryWaiting;
  final Set<ProfileSection> hiddenSections;

  /// The Tools row's "5 of 12 on" value.
  final ({int on, int total})? toolsCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final path = profile.path;
    return GroupedListView(
      children: [
        GroupedSection(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupedRow(
                  title: profile.label,
                  subtitle: profile.description.isEmpty
                      ? null
                      : profile.description,
                  subtitleMaxLines: null,
                  leading: GroupedTile(child: Text(initialsOf(profile.label))),
                ),
                if (path != null && path.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.indentAfterTile,
                      0,
                      metrics.rowPadding,
                      metrics.rowVerticalPadding + 4,
                    ),
                    // Selectable to copy, but read as text, not a field.
                    child: MenuSelectionArea(
                      child: Text(
                        path,
                        style: TextStyle(
                          fontSize: metrics.footerSize,
                          fontFamily: 'monospace',
                          color: context.hermesColors.subtleText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        GroupedSection(
          header: 'In this profile',
          dividerIndent: metrics.indentAfterTile,
          footer:
              "Everything here lives in this profile's home directory. Chats, "
              'schedules, memory and API keys are also per profile; Kanban and '
              'sign-in are shared.',
          children: [
            for (final section in ProfileSection.values)
              if (!hiddenSections.contains(section))
                GroupedRow(
                  wrapWhenStacked: true,
                  key: ValueKey('profile-section-${section.name}'),
                  title: profileSectionTitle(l10n, section),
                  subtitle: profileSectionDetail(l10n, section),
                  leading: GroupedTile(child: AppIcon(section.icon)),
                  value: switch (section) {
                    ProfileSection.memory when (memoryWaiting ?? 0) > 0 =>
                      '$memoryWaiting waiting',
                    ProfileSection.providers when counts[section] != null =>
                      l10n.providersConnectedCount(counts[section]!),
                    ProfileSection.tools => switch (toolsCount) {
                      (:final on, :final total) => l10n.toolsProfilesCount(
                        on,
                        total,
                      ),
                      null => null,
                    },
                    _ => counts[section]?.toString(),
                  },
                  onTap: () => onOpen(section),
                ),
          ],
        ),
      ],
    );
  }
}
