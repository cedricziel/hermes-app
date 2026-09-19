import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_controller.dart';
import '../../notifications/notifications_dialog.dart';
import '../../settings/appearance_dialog.dart';
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';
import 'relative_time.dart';

/// The thread list rail — assistant-ui's `<ThreadList />`: a "New thread"
/// action pinned above a scrollable history, with the active thread picked
/// out by a filled row instead of a border or shadow.
///
/// With [housekeeping], each server-backed thread gets a rename / pin /
/// archive / delete menu (from its button, a long press or a secondary click)
/// and the list asks for its next page when it scrolls to the end.
class ThreadSidebar extends StatelessWidget {
  const ThreadSidebar({
    super.key,
    required this.threads,
    required this.selectedId,
    required this.onSelect,
    required this.onNewThread,
    this.housekeeping,
    this.onOpenProfiles,
    this.onOpenBots,
  });

  final List<ChatThread> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewThread;
  final ThreadHousekeeping? housekeeping;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenBots;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final housekeeping = this.housekeeping;
    final showMore = housekeeping != null && housekeeping.hasMore;
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
                itemCount: threads.length + (showMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == threads.length) {
                    return _ShowMoreRow(
                      key: ValueKey(threads.length),
                      loading: housekeeping!.loadingMore,
                      onLoad: housekeeping.loadMore,
                    );
                  }
                  final thread = threads[index];
                  return _ThreadRow(
                    key: ValueKey('thread-${thread.id}'),
                    thread: thread,
                    selected: thread.id == selectedId,
                    onTap: () => onSelect(thread.id),
                    housekeeping: thread.remote ? housekeeping : null,
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

enum _ThreadAction { rename, pin, archive, delete }

class _ThreadRow extends StatefulWidget {
  const _ThreadRow({
    super.key,
    required this.thread,
    required this.selected,
    required this.onTap,
    this.housekeeping,
  });

  final ChatThread thread;
  final bool selected;
  final VoidCallback onTap;
  final ThreadHousekeeping? housekeeping;

  @override
  State<_ThreadRow> createState() => _ThreadRowState();
}

class _ThreadRowState extends State<_ThreadRow> {
  final _menu = GlobalKey<PopupMenuButtonState<_ThreadAction>>();

  ChatThread get _thread => widget.thread;

  void _openMenu() => _menu.currentState?.showButtonMenu();

  Future<void> _run(_ThreadAction action) async {
    final housekeeping = widget.housekeeping!;
    switch (action) {
      case _ThreadAction.rename:
        final title = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(initial: _thread.title),
        );
        if (title != null && title != _thread.title) {
          await housekeeping.rename(_thread, title);
        }
      case _ThreadAction.pin:
        await housekeeping.setPinned(_thread, !_thread.pinned);
      case _ThreadAction.archive:
        await housekeeping.archive(_thread);
      case _ThreadAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _DeleteDialog(title: _thread.title),
        );
        if (confirmed ?? false) await housekeeping.delete(_thread);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final actionable = widget.housekeeping != null;
    return Material(
      color: widget.selected
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.7)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        onLongPress: actionable ? _openMenu : null,
        onSecondaryTap: actionable ? _openMenu : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            actionable ? 3 : 9,
            actionable ? 2 : 10,
            actionable ? 3 : 9,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_thread.pinned) ...[
                          Icon(Icons.push_pin, size: 12, color: subtle),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            _thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relativeTime(_thread.updatedAt),
                      style: TextStyle(fontSize: 11.5, color: subtle),
                    ),
                  ],
                ),
              ),
              if (actionable)
                PopupMenuButton<_ThreadAction>(
                  key: _menu,
                  tooltip: 'Chat actions',
                  iconSize: 16,
                  icon: Icon(Icons.more_horiz, color: subtle),
                  onSelected: _run,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _ThreadAction.rename,
                      child: Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: _ThreadAction.pin,
                      child: Text(_thread.pinned ? 'Unpin' : 'Pin'),
                    ),
                    const PopupMenuItem(
                      value: _ThreadAction.archive,
                      child: Text('Archive'),
                    ),
                    const PopupMenuItem(
                      value: _ThreadAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete this chat?'),
      content: Text('"$title" and its messages will be deleted for good.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// The end of a list with more pages. It loads the next one as soon as it
/// scrolls into view; the button is for when that fails. Keyed by the list's
/// length so each page gets a fresh row that loads again if it is still in
/// view.
class _ShowMoreRow extends StatefulWidget {
  const _ShowMoreRow({super.key, required this.loading, required this.onLoad});

  final bool loading;
  final VoidCallback onLoad;

  @override
  State<_ShowMoreRow> createState() => _ShowMoreRowState();
}

class _ShowMoreRowState extends State<_ShowMoreRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoad());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: widget.loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: widget.onLoad,
                child: const Text('Show more'),
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
          if (value == 'appearance') showAppearanceDialog(context);
          if (value == 'notifications') showNotificationsDialog(context);
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
          const PopupMenuItem(value: 'appearance', child: Text('Appearance')),
          const PopupMenuItem(
            value: 'notifications',
            child: Text('Notifications'),
          ),
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
