import 'package:flutter/material.dart';

import '../../macos/mac_source_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../hermes_profiles_repository.dart';
import 'profile_avatar.dart';

/// What a profile's home holds, by the screen that manages it.
enum ProfileSection {
  skills('Skills', 'What the agent knows how to do', AppIcons.extension),
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: MacProfileDetail(
                        profile: profile,
                        counts: counts,
                        onOpen: onOpen,
                      ),
                    ),
                  ),
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

/// One profile's home: its name and path, then a card of what it holds with
/// a count each, and a note on what else lives there.
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
    final theme = Theme.of(context);
    final subtle = context.hermesColors.subtleText;
    final path = profile.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InitialsAvatar(label: profile.label, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.label, style: theme.textTheme.titleMedium),
                  if (path != null && path.isNotEmpty)
                    SelectableText(
                      path,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['Courier', 'monospace'],
                        color: subtle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (final (i, section) in ProfileSection.values.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 44),
                _SectionRow(
                  section: section,
                  count: counts[section],
                  onTap: () => onOpen(section),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Everything here lives in this profile's home directory. Chats, "
          'schedules, memory and API keys are also per profile; Kanban and '
          'sign-in are shared.',
          style: TextStyle(fontSize: 11, color: subtle),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.count,
    required this.onTap,
  });

  final ProfileSection section;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final count = this.count;
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('profile-section-${section.name}'),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                AppIcon(section.icon, size: 18, color: subtle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.label, style: const TextStyle(fontSize: 13)),
                      Text(
                        section.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                    ],
                  ),
                ),
                if (count != null)
                  Text('$count', style: TextStyle(fontSize: 13, color: subtle)),
                const SizedBox(width: 6),
                AppIcon(AppIcons.chevronRight, size: 14, color: subtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
