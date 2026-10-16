import 'package:flutter/material.dart';

import '../hermes_profiles_repository.dart';
import '../profile_avatar_repository.dart';
import 'profile_avatar.dart';

/// Lists available local chat recipients without changing the server default.
class RecipientPicker extends StatelessWidget {
  const RecipientPicker({
    super.key,
    required this.profiles,
    required this.onSelected,
    this.selectedProfile,
    this.loading = false,
    this.failed = false,
    this.onRetry,
    this.avatars,
  });

  final List<HermesProfile> profiles;
  final ValueChanged<HermesProfile> onSelected;
  final String? selectedProfile;
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;
  final ProfileAvatarRepository? avatars;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.symmetric(vertical: 12),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(
          'New message',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (loading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (failed) ...[
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Could not load recipients.'),
        ),
        if (onRetry != null)
          Align(
            alignment: Alignment.center,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
      ] else if (profiles.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recipients available.'),
        )
      else
        for (final profile in profiles)
          ListTile(
            leading: ExcludeSemantics(
              child: ProfileAvatar(profile: profile, repository: avatars),
            ),
            title: Text(
              profile.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: profile.label != profile.name ? Text(profile.name) : null,
            selected: selectedProfile == profile.name,
            trailing: selectedProfile == profile.name
                ? const Icon(Icons.check)
                : null,
            onTap: () => onSelected(profile),
          ),
    ],
  );
}

/// The selected unsent recipient, optionally tappable to choose another.
class ProfileRecipientChip extends StatelessWidget {
  const ProfileRecipientChip({
    super.key,
    required this.profile,
    this.onTap,
    this.avatars,
  });

  final HermesProfile profile;
  final VoidCallback? onTap;
  final ProfileAvatarRepository? avatars;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: ExcludeSemantics(
      child: ProfileAvatar(profile: profile, repository: avatars, size: 24),
    ),
    label: Text(
      'To: ${profile.label}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onPressed: onTap,
  );
}
