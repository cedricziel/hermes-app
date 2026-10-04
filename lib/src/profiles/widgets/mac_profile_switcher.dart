import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../hermes_profiles_repository.dart';
import 'profile_avatar.dart';

sealed class _Pick {
  const _Pick();
}

class _Switch extends _Pick {
  const _Switch(this.name);

  final String name;
}

class _NewProfile extends _Pick {
  const _NewProfile();
}

class _Manage extends _Pick {
  const _Manage();
}

/// The profile the Mac sidebar works in, as a card at its top. A click opens
/// a menu of every profile, with the active one checked and each one's home
/// under its name, then "New Profile…" and "Manage Profiles…".
class MacProfileSwitcher extends StatelessWidget {
  const MacProfileSwitcher({
    super.key,
    required this.profiles,
    required this.current,
    required this.onSwitch,
    required this.onNewProfile,
    required this.onManage,
  });

  final List<HermesProfile> profiles;

  /// The name of the profile in use; null while it is not known.
  final String? current;
  final ValueChanged<String> onSwitch;
  final VoidCallback onNewProfile;
  final VoidCallback onManage;

  HermesProfile? get _currentProfile =>
      profiles.where((p) => p.name == current).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final scheme = Theme.of(context).colorScheme;
    final profile = _currentProfile;
    final label = profile?.label ?? current ?? 'Profile';
    final description = profile?.description ?? '';
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: 'Profile $label',
        child: AdaptivePopupMenuButton<_Pick>(
          key: const Key('mac-profile-switcher'),
          tooltip: '',
          position: PopupMenuPosition.under,
          onSelected: (pick) => switch (pick) {
            _Switch(:final name) => name == current ? null : onSwitch(name),
            _NewProfile() => onNewProfile(),
            _Manage() => onManage(),
          },
          itemBuilder: (context) => [
            PopupMenuItem<_Pick>(
              enabled: false,
              child: Text(
                'Profiles',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            for (final p in profiles)
              AdaptiveMenuItem<_Pick>(
                value: _Switch(p.name),
                macHeight: 36,
                child: _ProfileMenuEntry(
                  profile: p,
                  checked: p.name == current,
                ),
              ),
            const PopupMenuDivider(),
            const AdaptiveMenuItem<_Pick>(
              value: _NewProfile(),
              child: Text('New Profile…'),
            ),
            const AdaptiveMenuItem<_Pick>(
              value: _Manage(),
              child: Text('Manage Profiles…'),
            ),
          ],
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                InitialsAvatar(label: label),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.subtleText,
                          ),
                        ),
                    ],
                  ),
                ),
                AppIcon(AppIcons.unfold, size: 14, color: colors.subtleText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuEntry extends StatelessWidget {
  const _ProfileMenuEntry({required this.profile, required this.checked});

  final HermesProfile profile;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final path = profile.path;
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: checked
              ? const AppIcon(AppIcons.check, size: 13)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (path != null && path.isNotEmpty)
                Opacity(
                  opacity: 0.65,
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
