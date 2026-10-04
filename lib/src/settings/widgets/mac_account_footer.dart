import 'package:flutter/material.dart';

import '../../profiles/widgets/profile_avatar.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';

enum _AccountAction { settings, connection, signOut }

/// The signed-in user at the bottom of a Mac sidebar: initials, name and the
/// server's host; just the host when the dashboard reports no user. A click opens a menu above it with Settings…, Connection
/// Details and, with [onSignOut], Sign Out.
class MacAccountFooter extends StatelessWidget {
  const MacAccountFooter({
    super.key,
    required this.name,
    required this.host,
    required this.onSettings,
    required this.onConnection,
    this.onSignOut,
  });

  /// The user's name; null when the dashboard reports none.
  final String? name;
  final String host;
  final VoidCallback onSettings;
  final VoidCallback onConnection;

  /// Signs out of the dashboard; left out of the menu when the server needs
  /// no sign-in.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final onSignOut = this.onSignOut;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MergeSemantics(
          child: Semantics(
            button: true,
            label: 'Account',
            child: AdaptivePopupMenuButton<_AccountAction>(
              key: const Key('mac-account-footer'),
              tooltip: '',
              position: PopupMenuPosition.over,
              // Above the footer, as a Mac menu opens from the bottom edge:
              // the menu's 8pt padding on each side, its rows and divider.
              offset: Offset(
                0,
                -(16 +
                    AdaptivePopupMenuButton.macRowHeight *
                        (onSignOut == null ? 3 : 4) +
                    (onSignOut == null ? 0 : 9) +
                    4),
              ),
              onSelected: (action) => switch (action) {
                _AccountAction.settings => onSettings(),
                _AccountAction.connection => onConnection(),
                _AccountAction.signOut => onSignOut?.call(),
              },
              itemBuilder: (_) => [
                PopupMenuItem<_AccountAction>(
                  enabled: false,
                  child: Text(
                    onSignOut == null
                        ? 'Connected to the dashboard'
                        : 'Signed in to the dashboard',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const AdaptiveMenuItem(
                  value: _AccountAction.settings,
                  shortcut: '⌘,',
                  child: Text('Settings…'),
                ),
                const AdaptiveMenuItem(
                  value: _AccountAction.connection,
                  child: Text('Connection Details'),
                ),
                if (onSignOut != null) ...[
                  const PopupMenuDivider(),
                  const AdaptiveMenuItem(
                    value: _AccountAction.signOut,
                    child: Text('Sign Out'),
                  ),
                ],
              ],
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (name case final name?)
                      InitialsAvatar(label: name, size: 26)
                    else
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: AppIcon(
                          AppIcons.person,
                          size: 14,
                          color: scheme.onSurface,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name ?? host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (name != null)
                            Text(
                              host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: subtle),
                            ),
                        ],
                      ),
                    ),
                    AppIcon(AppIcons.unfold, size: 14, color: subtle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
