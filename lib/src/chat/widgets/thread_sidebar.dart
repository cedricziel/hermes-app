import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_controller.dart';
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import 'relative_time.dart';

/// The thread list rail — assistant-ui's `<ThreadList />`: a "New thread"
/// action pinned above a scrollable history, with the active thread picked
/// out by a filled row instead of a border or shadow.
class ThreadSidebar extends StatelessWidget {
  const ThreadSidebar({
    super.key,
    required this.threads,
    required this.selectedId,
    required this.onSelect,
    required this.onNewThread,
    this.onOpenProfiles,
    this.onOpenBots,
  });

  final List<ChatThread> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewThread;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenBots;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    return Container(
      color: colors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hermes',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: onNewThread,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New chat'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  return _ThreadRow(
                    thread: thread,
                    selected: thread.id == selectedId,
                    onTap: () => onSelect(thread.id),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            if (onOpenProfiles != null)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline, size: 18),
                  title: const Text('Profiles'),
                  onTap: onOpenProfiles,
                ),
              ),
            if (onOpenBots != null)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.smart_toy_outlined, size: 18),
                  title: const Text('Bots'),
                  onTap: onOpenBots,
                ),
              ),
            const _AccountFooter(),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

  final ChatThread thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.7)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thread.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relativeTime(thread.updatedAt),
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.hermesColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountFooter extends StatelessWidget {
  const _AccountFooter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final identity = auth.identity;
    final label = identity == null
        ? (auth.baseUrl ?? 'Not connected')
        : (identity.displayName.isNotEmpty
              ? identity.displayName
              : identity.email);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: PopupMenuButton<String>(
        tooltip: 'Account',
        offset: const Offset(0, -8),
        position: PopupMenuPosition.over,
        onSelected: (value) {
          if (value == 'sign-out') auth.signOut();
          if (value == 'change-server') auth.changeServer();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Text(
              auth.baseUrl ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const PopupMenuDivider(),
          if (auth.status?.authRequired ?? false)
            const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
          const PopupMenuItem(
            value: 'change-server',
            child: Text('Change server'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: Icon(
                  Icons.person_outline,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.more_horiz,
                size: 16,
                color: context.hermesColors.subtleText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
