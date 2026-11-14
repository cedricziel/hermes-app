import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../workspaces/ui/bound_working_directory.dart'
    show FolderLineBuilder;
import '../../workspaces/widgets/working_directory_line.dart'
    show workingDirectoryLineBelowBar;
import '../chat_models.dart';
import '../thread_housekeeping.dart';
import 'thread_actions_menu.dart';
import '../../widgets/named_icon_button.dart';
import '../activity/widgets/activity_panel.dart';

/// The bar above a wide chat: the open thread's title, its actions once the
/// dashboard knows it, the connection details and New Chat. A Mac window has
/// `MacChatToolbar` instead; a phone keeps only New Chat in its app bar.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    this.avatar,
    this.callButton,
    this.onShowFiles,
    required this.thread,
    this.housekeeping,
    this.displayTitle,
    required this.onShowConnection,
    required this.onNewChat,
    this.activityOpen = false,
    this.activityWaiting = 0,
    this.onToggleActivity,
    this.folderLine,
  });

  /// The line under the title that names the chat's folder and opens its
  /// details; null shows none. At a large text size it moves out of the bar
  /// into a full-width row under it.
  final FolderLineBuilder? folderLine;

  /// The open thread, or null before one is picked.
  final Widget? avatar;
  final Widget? callButton;

  /// Opens the chat's Files page; null while the server has none.
  final VoidCallback? onShowFiles;
  final ChatThread? thread;
  final ThreadHousekeeping? housekeeping;
  final String? displayTitle;
  final VoidCallback onShowConnection;
  final VoidCallback onNewChat;
  final bool activityOpen;

  /// How many requests need the user; marks the Activity button.
  final int activityWaiting;

  /// Opens or closes the Activity panel; null while no chat is open.
  final VoidCallback? onToggleActivity;

  @override
  Widget build(BuildContext context) {
    final thread = this.thread;
    final line = folderLine;
    final below = line != null && workingDirectoryLineBelowBar(context);
    final titleText = Text(
      displayTitle ?? thread?.title ?? 'Hermes',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
    final title = Expanded(
      child: line == null || below
          ? titleText
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [titleText, line(context, belowBar: false)],
            ),
    );
    final actions = [
      ?callButton,
      if (thread != null && thread.remote)
        ThreadActionsButton(
          key: const Key('header-thread-actions'),
          thread: thread,
          housekeeping: housekeeping,
          includeCopyTranscript: true,
          onShowFiles: onShowFiles,
        ),
      if (onToggleActivity case final toggle?)
        ActivityButton(
          open: activityOpen,
          waiting: activityWaiting,
          onPressed: toggle,
        ),
      ConnectionInfoButton(onPressed: onShowConnection),
      NewChatButton(onPressed: onNewChat),
    ];
    return SafeArea(
      bottom: false,
      left: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            child: Row(
              children: [
                if (avatar != null) ...[avatar!, const SizedBox(width: 8)],
                title,
                ...actions,
              ],
            ),
          ),
          if (below) line(context, belowBar: true),
        ],
      ),
    );
  }
}

/// Starts a new chat.
class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NamedIconButton(
    key: const Key('header-new-chat'),
    label: 'New chat',
    icon: AppIcons.compose,
    onPressed: onPressed,
  );
}

/// Opens the connection details.
class ConnectionInfoButton extends StatelessWidget {
  const ConnectionInfoButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NamedIconButton(
    key: const Key('header-connection'),
    label: 'Connection details',
    icon: AppIcons.info,
    onPressed: onPressed,
  );
}
