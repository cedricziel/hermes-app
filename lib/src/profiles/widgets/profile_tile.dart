import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import '../hermes_profiles_repository.dart';

/// One row of the Profiles screen: the profile's label, its description,
/// default model and skill count, an "Active" chip on the active one, and,
/// with [onChangeModel], a button that changes its default model.
///
/// On iOS it is a standard list row instead: a trailing checkmark marks the
/// active profile and the model change moves to a long-press action sheet,
/// which VoiceOver gets as a custom action.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.onChangeModel,
  });

  final HermesProfile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onChangeModel;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (profile.description.isNotEmpty) profile.description,
      ?profile.model,
      '${profile.skillCount} skills',
    ];
    if (platformChromeOf(context) == PlatformChrome.ios) {
      return _buildIos(context, parts.join(' · '));
    }
    return ListTile(
      leading: const AppIcon(AppIcons.person),
      title: Text(profile.label),
      subtitle: Text(parts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) const Chip(label: Text('Active')),
          if (onChangeModel != null)
            NamedIconButton(
              key: Key('profile-model-${profile.name}'),
              label: 'Change default model',
              icon: AppIcons.tune,
              onPressed: onChangeModel,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildIos(BuildContext context, String subtitle) {
    final change = onChangeModel;
    final row = ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minTileHeight: kAppleMinTapTarget,
      selected: active,
      title: Text(profile.label),
      subtitle: Text(subtitle),
      trailing: active
          ? const Icon(CupertinoIcons.check_mark, semanticLabel: 'Active')
          : null,
      onTap: onTap,
      onLongPress: change == null ? null : () => _showActions(context, change),
    );
    if (change == null) return row;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Change default model'): change,
      },
      child: row,
    );
  }

  Future<void> _showActions(BuildContext context, VoidCallback change) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(profile.label),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheet).pop();
              change();
            },
            child: const Text('Change default model'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
