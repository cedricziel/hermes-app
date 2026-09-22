import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_lock/app_lock_dialog.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications_dialog.dart';
import '../../settings/appearance_dialog.dart';
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';
import 'relative_time.dart';
import 'thread_actions_menu.dart';

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
    this.navigation,
    this.onOpenProfiles,
    this.onOpenBots,
    this.onOpenSkills,
    this.onOpenPlugins,
    this.onOpenMcp,
  });

  final List<ChatThread> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewThread;
  final ThreadHousekeeping? housekeeping;

  /// The destinations of the app shell, shown under the app name.
  final Widget? navigation;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenBots;
  final VoidCallback? onOpenSkills;
  final VoidCallback? onOpenPlugins;
  final VoidCallback? onOpenMcp;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
            if (navigation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: navigation,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SidebarAction(
                icon: Icons.add,
                label: 'New chat',
                onTap: onNewThread,
              ),
            ),
            const SizedBox(height: 4),
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
            _MoreSection(
              entries: [
                if (onOpenProfiles != null)
                  (Icons.person_outline, 'Profiles', onOpenProfiles!),
                if (onOpenSkills != null)
                  (Icons.extension_outlined, 'Skills', onOpenSkills!),
                if (onOpenBots != null)
                  (Icons.smart_toy_outlined, 'Bots', onOpenBots!),
                if (onOpenPlugins != null)
                  (Icons.extension_outlined, 'Plugins', onOpenPlugins!),
                if (onOpenMcp != null)
                  (Icons.power_outlined, 'MCP servers', onOpenMcp!),
              ],
            ),
            const AccountFooter(),
          ],
        ),
      ),
    );
  }
}

/// A flat, full-width row for an action or destination in the sidebar.
class SidebarAction extends StatelessWidget {
  const SidebarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Fills the row, as for the open destination.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.7)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profiles, skills, bots, plugins and MCP servers behind one row, so the
/// thread list keeps the height.
class _MoreSection extends StatefulWidget {
  const _MoreSection({required this.entries});

  final List<(IconData, String, VoidCallback)> entries;

  @override
  State<_MoreSection> createState() => _MoreSectionState();
}

class _MoreSectionState extends State<_MoreSection> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const Divider(height: 1),
          SidebarAction(
            icon: _open ? Icons.expand_more : Icons.chevron_right,
            label: 'More',
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            for (final (icon, label, onTap) in widget.entries)
              SidebarAction(icon: icon, label: label, onTap: onTap),
        ],
      ),
    );
  }
}

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
  final _actions = GlobalKey<ThreadActionsButtonState>();

  ChatThread get _thread => widget.thread;

  void _openMenu() => _actions.currentState?.open();

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
        child: Semantics(
          hint: relativeTime(_thread.updatedAt),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              actionable ? 2 : 9,
              actionable ? 2 : 10,
              actionable ? 2 : 9,
            ),
            child: Row(
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
                if (actionable)
                  ThreadActionsButton(
                    key: _actions,
                    thread: _thread,
                    housekeeping: widget.housekeeping,
                    dense: true,
                  ),
              ],
            ),
          ),
        ),
      ),
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

/// The signed-in user with the account menu.
class AccountFooter extends StatelessWidget {
  const AccountFooter({super.key});

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
          if (value == 'app-lock') showAppLockDialog(context);
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
          const PopupMenuItem(value: 'app-lock', child: Text('App lock')),
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
