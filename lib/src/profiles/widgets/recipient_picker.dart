import 'package:flutter/material.dart';

import '../hermes_profiles_repository.dart';
import '../profile_avatar_repository.dart';
import 'profile_avatar.dart';
import '../../widgets/composer_selector_chip.dart';

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
    this.onSetup,
    this.avatars,
  });

  final List<HermesProfile> profiles;
  final ValueChanged<HermesProfile> onSelected;
  final String? selectedProfile;
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onSetup;
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
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading recipients'),
            ],
          ),
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
      ] else if (profiles.isEmpty) ...[
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No profiles available'),
        ),
        if (onSetup != null)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onSetup,
              child: const Text('Set up profiles'),
            ),
          ),
      ] else
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

enum RecipientSelectorState {
  loading,
  choose,
  empty,
  unavailable,
  failed,
  ready,
}

/// A recipient selector that keeps identity visible through discovery failures.
class ProfileRecipientChip extends StatelessWidget {
  const ProfileRecipientChip({
    super.key,
    required this.profile,
    this.state = RecipientSelectorState.ready,
    this.onTap,
    this.onRetry,
    this.onSetup,
    this.avatars,
  });

  final HermesProfile? profile;
  final RecipientSelectorState state;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onSetup;
  final ProfileAvatarRepository? avatars;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final state = this.state == RecipientSelectorState.ready && profile == null
        ? RecipientSelectorState.choose
        : this.state;
    final label = switch (state) {
      RecipientSelectorState.loading => 'Loading recipients',
      RecipientSelectorState.choose => 'Choose a recipient',
      RecipientSelectorState.empty => 'No profiles available',
      RecipientSelectorState.unavailable =>
        '${profile?.label ?? 'Recipient'} unavailable',
      RecipientSelectorState.failed => 'Could not load recipients',
      RecipientSelectorState.ready => 'To: ${profile!.label}',
    };
    final retry =
        state == RecipientSelectorState.failed ||
        state == RecipientSelectorState.unavailable;
    final empty = state == RecipientSelectorState.empty;
    final interactive =
        state == RecipientSelectorState.ready ||
        state == RecipientSelectorState.choose ||
        state == RecipientSelectorState.unavailable;
    return ComposerSelectorChip(
      label: label,
      semanticLabel:
          profile != null &&
              (state == RecipientSelectorState.loading ||
                  state == RecipientSelectorState.failed)
          ? '$label, selected recipient ${profile.label}'
          : label,
      leading: profile == null
          ? null
          : ProfileAvatar(profile: profile, repository: avatars, size: 24),
      onPressed: interactive ? onTap : null,
      actionLabel: retry
          ? 'Retry'
          : empty
          ? 'Set up profiles'
          : null,
      actionSemanticLabel: retry
          ? 'Retry recipients'
          : empty
          ? 'Set up profiles'
          : null,
      onAction: retry
          ? onRetry
          : empty
          ? onSetup
          : null,
    );
  }
}
