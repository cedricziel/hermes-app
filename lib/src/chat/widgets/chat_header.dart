import 'package:flutter/material.dart';

import '../chat_models.dart';
import '../thread_housekeeping.dart';
import 'thread_actions_menu.dart';

/// The bar above a wide chat: the open thread's title, its actions once the
/// dashboard knows it, and the connection details.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.thread,
    this.housekeeping,
    required this.onShowConnection,
  });

  /// The open thread, or null before one is picked.
  final ChatThread? thread;
  final ThreadHousekeeping? housekeeping;
  final VoidCallback onShowConnection;

  @override
  Widget build(BuildContext context) {
    final thread = this.thread;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              thread?.title ?? 'Hermes',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (thread != null && thread.remote)
            ThreadActionsButton(
              key: const Key('header-thread-actions'),
              thread: thread,
              housekeeping: housekeeping,
              includeCopyTranscript: true,
            ),
          ConnectionInfoButton(onPressed: onShowConnection),
        ],
      ),
    );
  }
}

/// Opens the connection details.
class ConnectionInfoButton extends StatelessWidget {
  const ConnectionInfoButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Connection details',
    icon: const Icon(Icons.info_outline),
    onPressed: onPressed,
  );
}
