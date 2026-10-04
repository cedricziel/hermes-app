import 'package:flutter/material.dart';

import '../../macos/mac_sidebar.dart';
import '../../macos/mac_toolbar.dart';
import '../../macos/mac_toolbar_search_field.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/named_popup_menu_button.dart';

/// From this window width the toolbar shows the search field itself; below
/// it a button that opens the field.
const double kMacToolbarSearchFieldWidth = 1000;

enum _More { copyTranscript, connection }

/// The chat's toolbar in a Mac window: the chat's title over "profile ·
/// model", then New Chat, Copy Transcript, Connection Details and search.
///
/// A medium window shows a search button until a search is open; a compact
/// one also folds Copy Transcript and Connection Details into a "…" menu.
class MacChatToolbar extends StatelessWidget {
  const MacChatToolbar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onNewChat,
    required this.onShowConnection,
    this.onCopyTranscript,
    required this.searchQuery,
    required this.searchActive,
    required this.onSearchBegin,
    required this.onSearchChanged,
    required this.onSearchEnd,
    this.onSearchSubmitted,
    this.searchFocus,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onNewChat;
  final VoidCallback onShowConnection;

  /// Copies the open chat as Markdown; null while no chat is open.
  final VoidCallback? onCopyTranscript;
  final String searchQuery;
  final bool searchActive;
  final VoidCallback onSearchBegin;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchEnd;
  final ValueChanged<String>? onSearchSubmitted;
  final FocusNode? searchFocus;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < kMacCompactWindowWidth;
    final showField = searchActive || width >= kMacToolbarSearchFieldWidth;
    return MacToolbar(
      title: title,
      subtitle: subtitle,
      actions: [
        MacToolbarButton(
          key: const Key('toolbar-new-chat'),
          label: 'New Chat',
          shortcut: '⌘N',
          icon: AppIcons.compose,
          onPressed: onNewChat,
        ),
        if (compact)
          _moreMenu(context)
        else ...[
          MacToolbarButton(
            key: const Key('toolbar-share'),
            label: 'Copy Transcript',
            icon: AppIcons.share,
            onPressed: onCopyTranscript,
          ),
          MacToolbarButton(
            key: const Key('toolbar-connection'),
            label: 'Connection Details',
            icon: AppIcons.info,
            onPressed: onShowConnection,
          ),
        ],
        if (showField)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: MacToolbarSearchField(
              query: searchQuery,
              active: searchActive,
              focusNode: searchFocus,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onEnd: onSearchEnd,
            ),
          )
        else
          MacToolbarButton(
            key: const Key('toolbar-search'),
            label: 'Search',
            shortcut: '⌘F',
            icon: AppIcons.search,
            onPressed: onSearchBegin,
          ),
      ],
    );
  }

  Widget _moreMenu(BuildContext context) {
    final onCopyTranscript = this.onCopyTranscript;
    return NamedPopupMenuButton<_More>(
      key: const Key('toolbar-more'),
      label: 'More',
      icon: AppIcons.more,
      iconSize: 18,
      color: context.hermesColors.subtleText,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(28),
        minimumSize: const Size.square(28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onSelected: (item) => switch (item) {
        _More.copyTranscript => onCopyTranscript?.call(),
        _More.connection => onShowConnection(),
      },
      itemBuilder: (_) => [
        AdaptiveMenuItem(
          value: _More.copyTranscript,
          enabled: onCopyTranscript != null,
          child: const Text('Copy Transcript'),
        ),
        const AdaptiveMenuItem(
          value: _More.connection,
          child: Text('Connection Details'),
        ),
      ],
    );
  }
}
