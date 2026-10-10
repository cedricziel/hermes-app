import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';
import 'thread_actions_menu.dart';
import '../../widgets/named_icon_button.dart';

/// The bar above a wide chat: the open thread's title, its actions once the
/// dashboard knows it, and New Chat. A Mac window has `MacChatToolbar`
/// instead.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.thread,
    this.housekeeping,
    this.displayTitle,
    required this.onNewChat,
  });

  /// The open thread, or null before one is picked.
  final ChatThread? thread;
  final ThreadHousekeeping? housekeeping;
  final String? displayTitle;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final thread = this.thread;
    final title = Expanded(
      child: Text(
        displayTitle ?? thread?.title ?? 'Hermes',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
    final actions = [
      if (thread != null && thread.remote)
        ThreadActionsButton(
          key: const Key('header-thread-actions'),
          thread: thread,
          housekeeping: housekeeping,
          includeCopyTranscript: true,
        ),
      NewChatButton(onPressed: onNewChat),
    ];
    return SafeArea(
      bottom: false,
      left: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(children: [title, ...actions]),
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
