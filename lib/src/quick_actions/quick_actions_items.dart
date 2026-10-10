import 'package:characters/characters.dart';

import '../deep_links/deep_link_target.dart';
import '../deep_links/deep_link_uri.dart';
import '../surfaces/surface_snapshot.dart';
import 'quick_actions_port.dart';

/// iOS shows four items; both platforms list the same ones.
const kQuickActionRecents = 2;
const kQuickActionTitleLength = 40;

/// The icon menu for [snapshot]: nothing when signed out, else New Chat,
/// Dictate and the newest titled chats. Under App Lock the snapshot's titles
/// are empty, which leaves no chat here.
///
/// Each item's type is its `hermes://` link, so a pick takes the path any
/// other link does.
List<ShortcutItem> quickActionItems(
  SurfaceSnapshot snapshot, {
  bool ios = false,
}) {
  if (!snapshot.signedIn) return const [];
  final recents = <(RecentChat, String)>[
    for (final chat in snapshot.recentChats)
      if (_cut(chat.title) case final title when title.isNotEmpty)
        (chat, title),
  ].take(kQuickActionRecents).toList();
  final showProfile =
      ios && {for (final (c, _) in recents) c.profile}.length > 1;
  return [
    ShortcutItem(
      type: deepLinkUri(const NewChat()).toString(),
      localizedTitle: 'New Chat',
      icon: 'quick_new_chat',
    ),
    ShortcutItem(
      type: deepLinkUri(const NewChat(dictate: true)).toString(),
      localizedTitle: 'Dictate',
      icon: 'quick_dictate',
    ),
    for (final (chat, title) in recents)
      ShortcutItem(
        type: chat.url,
        localizedTitle: title,
        localizedSubtitle: showProfile ? chat.profile : null,
        icon: 'quick_chat',
      ),
  ];
}

String _cut(String title) {
  final text = title.trim().characters;
  if (text.length <= kQuickActionTitleLength) return text.toString();
  return '${text.take(kQuickActionTitleLength - 1).toString().trimRight()}…';
}
