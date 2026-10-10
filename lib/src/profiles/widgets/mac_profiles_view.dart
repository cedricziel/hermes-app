import 'package:flutter/material.dart';

import '../../macos/mac_source_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../hermes_profiles_repository.dart';
import 'profile_avatar.dart';

/// What a profile's home holds, by the screen that manages it.
enum ProfileSection {
  skills('Skills', 'What the agent knows how to do', AppIcons.sparkle),
  messaging('Messaging', 'Chat platforms the agent answers on', AppIcons.bot),
  plugins('Plugins', 'Agent plugins and providers', AppIcons.extension),
  mcp('MCP servers', 'Tools from MCP servers', AppIcons.power),
  helperModels('Helper models', 'Models for side tasks', AppIcons.tune);

  const ProfileSection(this.label, this.detail, this.icon);

  final String label;
  final String detail;
  final AppIconSet icon;
}

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
  });

  final List<HermesProfile> profiles;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// How many of each the selected profile holds; a section without a count
  /// (still loading, or it could not be read) shows none.
  final Map<ProfileSection, int> counts;
  final ValueChanged<ProfileSection> onOpen;

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
  });

  final HermesProfile profile;
  final Map<ProfileSection, int> counts;
  final ValueChanged<ProfileSection> onOpen;

  @override
  Widget build(BuildContext context) {
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
                    child: SelectableText(
                      path,
                      style: TextStyle(
                        fontSize: metrics.footerSize,
                        fontFamily: 'monospace',
                        color: context.hermesColors.subtleText,
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
              GroupedRow(
                key: ValueKey('profile-section-${section.name}'),
                title: section.label,
                subtitle: section.detail,
                leading: GroupedTile(child: AppIcon(section.icon)),
                value: counts[section]?.toString(),
                onTap: () => onOpen(section),
              ),
          ],
        ),
      ],
    );
  }
}
