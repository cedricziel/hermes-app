import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/named_icon_button.dart';
import '../hermes_profiles_repository.dart';
import 'profile_avatar.dart';

/// One profile in the Profiles group: its initials in a tile, its label,
/// its description (or home), and its default model and skill count.
///
/// A check marks the active profile on Apple platforms, a muted "Active" on
/// Material. With [onChangeModel] a button changes its default model; on iOS
/// that moves to a long-press action sheet, which VoiceOver gets as a custom
/// action.
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
    final chrome = platformChromeOf(context);
    final ios = chrome == PlatformChrome.ios;
    final change = onChangeModel;
    final path = profile.path;
    final check = active && chrome.isApple
        ? const AppIcon(AppIcons.check, semanticLabel: 'Active')
        : null;
    final button = change == null || ios
        ? null
        : NamedIconButton(
            key: Key('profile-model-${profile.name}'),
            label: 'Change default model',
            icon: AppIcons.tune,
            onPressed: change,
          );
    final trailing = [?check, ?button];
    final row = GroupedRow(
      title: profile.label,
      subtitle: profile.description.isNotEmpty
          ? profile.description
          : (path != null && path.isNotEmpty ? path : null),
      caption: [?profile.model, '${profile.skillCount} skills'].join(' · '),
      leading: GroupedTile(child: Text(initialsOf(profile.label))),
      value: active && !chrome.isApple ? 'Active' : null,
      trailing: trailing.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      chevron: false,
      onTap: onTap,
    );
    if (!ios || change == null) return row;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Change default model'): change,
      },
      child: GestureDetector(
        onLongPress: () => _showActions(context, change),
        child: row,
      ),
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
