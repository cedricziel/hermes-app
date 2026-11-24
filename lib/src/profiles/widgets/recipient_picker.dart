import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/focus_ring.dart';

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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            l10n.profilesRecipientTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.profilesRecipientLoading),
              ],
            ),
          )
        else if (failed) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.profilesRecipientLoadFailedMessage),
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onRetry,
                child: Text(l10n.commonRetry),
              ),
            ),
        ] else if (profiles.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.profilesRecipientNone),
          ),
          if (onSetup != null)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onSetup,
                child: Text(l10n.profilesRecipientSetUp),
              ),
            ),
        ] else
          for (final profile in profiles)
            FocusRing(
              child: ListTile(
                leading: ExcludeSemantics(
                  child: ProfileAvatar(profile: profile, repository: avatars),
                ),
                title: Text(
                  profile.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: profile.label != profile.name
                    ? Text(profile.name)
                    : null,
                selected: selectedProfile == profile.name,
                trailing: selectedProfile == profile.name
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => onSelected(profile),
              ),
            ),
      ],
    );
  }
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
    final l10n = context.l10n;
    final profile = this.profile;
    final state = this.state == RecipientSelectorState.ready && profile == null
        ? RecipientSelectorState.choose
        : this.state;
    final label = switch (state) {
      RecipientSelectorState.loading => l10n.profilesRecipientLoading,
      RecipientSelectorState.choose => l10n.profilesRecipientChoose,
      RecipientSelectorState.empty => l10n.profilesRecipientNone,
      RecipientSelectorState.unavailable => l10n.profilesRecipientUnavailable(
        profile?.label ?? l10n.profilesRecipientFallbackName,
      ),
      RecipientSelectorState.failed => l10n.profilesRecipientLoadFailed,
      RecipientSelectorState.ready => l10n.profilesRecipientTo(profile!.label),
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
          ? l10n.profilesRecipientSelectedLabel(label, profile.label)
          : label,
      leading: profile == null
          ? null
          : ProfileAvatar(profile: profile, repository: avatars, size: 24),
      onPressed: interactive ? onTap : null,
      actionLabel: retry
          ? l10n.commonRetry
          : empty
          ? l10n.profilesRecipientSetUp
          : null,
      actionSemanticLabel: retry
          ? l10n.profilesRecipientRetryRecipients
          : empty
          ? l10n.profilesRecipientSetUp
          : null,
      onAction: retry
          ? onRetry
          : empty
          ? onSetup
          : null,
    );
  }
}
