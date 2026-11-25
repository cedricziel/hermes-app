import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../macos/mac_sidebar.dart';
import '../../macos/mac_toolbar.dart';
import '../../macos/mac_toolbar_search_field.dart';
import '../../theme/app_icons.dart';
import 'mac_chat_more_menu.dart';
import 'thread_actions_menu.dart' show ExportJsonOffer;

/// From this window width the toolbar shows the search field itself; below
/// it a button that opens the field.
const double kMacToolbarSearchFieldWidth = 1000;

/// The chat's toolbar in a Mac window: the chat's title over "profile ·
/// model", then New Chat, Copy Transcript, Connection Details and search.
///
/// A medium window shows a search button until a search is open; a compact
/// one also folds Copy Transcript and Connection Details into a "…" menu.
class MacChatToolbar extends StatelessWidget {
  const MacChatToolbar({
    super.key,
    this.avatar,
    required this.title,
    this.subtitle,
    this.subtitleBuilder,
    required this.onNewChat,
    required this.onShowConnection,
    this.onCopyTranscript,
    this.exportJson,
    this.onShowFiles,
    this.folderButton,
    this.callButton,
    this.activityOpen = false,
    this.activityWaiting = 0,
    this.onToggleActivity,
    required this.searchQuery,
    required this.searchActive,
    required this.onSearchBegin,
    required this.onSearchChanged,
    required this.onSearchEnd,
    this.onSearchSubmitted,
    this.searchFocus,
  });

  final Widget? avatar;
  final String title;
  final String? subtitle;

  /// Wraps the drawn [subtitle], e.g. to draw a `MacToolbarSubtitle` instead.
  /// It runs only while [subtitle] is not null.
  final Widget Function(BuildContext context, Widget subtitle)? subtitleBuilder;
  final VoidCallback onNewChat;
  final VoidCallback onShowConnection;

  /// Copies the open chat as Markdown; null while no chat is open.
  final VoidCallback? onCopyTranscript;

  /// "Export Chat as JSON…" in the compact window's … menu, after Copy
  /// Transcript; null leaves it out. Wide windows use the Chat menu.
  final ExportJsonOffer? exportJson;

  /// Opens the chat's Files page; null hides the item (an older server).
  final VoidCallback? onShowFiles;

  /// The titled folder button before New Chat: opens the picker on a new chat
  /// and the details on an open one. Null shows none (an older server).
  final Widget? folderButton;

  /// Starts or returns to the voice call, before New Chat; null shows none.
  final Widget? callButton;
  final bool activityOpen;

  /// How many requests need the user; marks the Activity button.
  final int activityWaiting;

  /// Shows or hides the Activity inspector; null while no chat is open.
  final VoidCallback? onToggleActivity;
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
    final compact = isMacCompact(context);
    final showField = searchActive || width >= kMacToolbarSearchFieldWidth;
    return MacToolbar(
      leading: avatar,
      title: title,
      subtitle: subtitle,
      subtitleBuilder: subtitleBuilder,
      actions: [
        ?folderButton,
        ?callButton,
        MacToolbarButton(
          key: const Key('toolbar-new-chat'),
          label: context.l10n.chatWidgetsMacToolbarNewChat,
          shortcut: '⌘N',
          icon: AppIcons.compose,
          onPressed: onNewChat,
        ),
        if (compact)
          MacChatMoreMenu(
            onShowFiles: onShowFiles,
            onCopyTranscript: onCopyTranscript,
            exportJson: exportJson,
            onShowConnection: onShowConnection,
          )
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
        MacToolbarButton(
          key: const Key('toolbar-activity'),
          label: activityWaiting > 0
              ? (activityOpen
                    ? context.l10n.chatActivityInspectorHideWaiting(
                        activityWaiting,
                      )
                    : context.l10n.chatActivityInspectorShowWaiting(
                        activityWaiting,
                      ))
              : (activityOpen
                    ? context.l10n.chatActivityInspectorHide
                    : context.l10n.chatActivityInspectorShow),
          shortcut: '⌥⌘I',
          icon: AppIcons.inspector,
          selected: activityOpen,
          marked: activityWaiting > 0,
          onPressed: onToggleActivity,
        ),
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
              onBegin: onSearchBegin,
            ),
          )
        else
          MacToolbarButton(
            key: const Key('toolbar-search'),
            label: context.l10n.chatWidgetsMacToolbarSearch,
            shortcut: '⌘F',
            icon: AppIcons.search,
            onPressed: onSearchBegin,
          ),
      ],
    );
  }
}
