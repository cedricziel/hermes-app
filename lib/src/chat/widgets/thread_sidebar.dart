import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:provider/provider.dart';

import '../../app_lock/app_lock_dialog.dart';
import '../../auth/auth_controller.dart';
import '../../macos/mac_sidebar.dart';
import '../../macos/mac_source_list.dart';
import '../../notifications/notifications_dialog.dart';
import '../../settings/about_dialog.dart';
import '../../settings/appearance_dialog.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';
import '../thread_search.dart';
import '../thread_sections.dart';
import 'mac_search_results.dart';
import 'mac_thread_row.dart';
import 'relative_time.dart';
import 'sidebar_row.dart';
import 'swipeable_thread_row.dart';
import 'thread_actions_menu.dart';
import 'thread_search_view.dart';
import 'working_dot.dart';

/// The thread list rail — assistant-ui's `<ThreadList />`: a "New thread"
/// action pinned above a scrollable history, with the active thread picked
/// out by a filled row instead of a border or shadow.
///
/// With [housekeeping], each server-backed thread gets a rename / pin /
/// archive / delete menu (from its button, a long press or a secondary click)
/// and the list asks for its next page when it scrolls to the end.
///
/// With [search], a field above the list searches the sessions, and while it
/// holds text the list shows what it found; a tapped result goes to
/// [onOpenHit]. A Mac window searches from its toolbar instead, and shows the
/// results here while the search is open.
///
/// On macOS the threads sit in sections by when they were last active, under
/// headers that fold them away, as 28pt rows with hover buttons and a Mac
/// context menu.
class ThreadSidebar extends StatelessWidget {
  const ThreadSidebar({
    super.key,
    required this.threads,
    required this.selectedId,
    required this.onSelect,
    required this.onNewThread,
    this.busy = const {},
    this.housekeeping,
    this.search,
    this.onOpenHit,
    this.navigation,
    this.onOpenProfiles,
    this.onOpenMessaging,
    this.onOpenSkills,
    this.onOpenPlugins,
    this.onOpenMcp,
    this.onOpenHelperModels,
    this.onOpenInNewWindow,
    this.searchProfile,
  });

  final List<ChatThread> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewThread;

  /// The ids of threads a turn is running in right now, shown as a small
  /// spinner on their row.
  final Set<String> busy;

  final ThreadHousekeeping? housekeeping;
  final ThreadSearch? search;
  final ValueChanged<ThreadSearchHit>? onOpenHit;

  /// The destinations of the app shell, shown under the app name.
  final Widget? navigation;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenMessaging;
  final VoidCallback? onOpenSkills;
  final VoidCallback? onOpenPlugins;
  final VoidCallback? onOpenMcp;
  final VoidCallback? onOpenHelperModels;

  /// Opens a server-backed thread in a window of its own, from its Mac
  /// context menu; the item is left out without it.
  final ValueChanged<ChatThread>? onOpenInNewWindow;

  /// The profile [search] looks in by default; results from another one name
  /// theirs.
  final String? searchProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    final search = this.search;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return Container(
      color: macSidebarColor(context, colors.sidebar),
      child: SafeArea(
        child: Column(
          children: [
            macSidebarHeader(context) ??
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.hub,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hermes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
            if (mac)
              Expanded(child: _macBody())
            else ...[
              if (navigation != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: navigation,
                ),
                const Divider(height: 17, indent: 16, endIndent: 16),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SidebarAction(
                  icon: AppIcons.add,
                  label: 'New chat',
                  onTap: onNewThread,
                ),
              ),
              const SizedBox(height: 4),
              if (search != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListenableBuilder(
                    listenable: search,
                    builder: (context, _) => ThreadSearchField(
                      query: search.query,
                      onChanged: search.update,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: search == null
                    ? _threadList()
                    : ListenableBuilder(
                        listenable: search,
                        builder: (context, _) =>
                            search.status == ThreadSearchStatus.idle
                            ? _threadList()
                            : ThreadSearchResults(
                                query: search.query,
                                status: search.status,
                                hits: search.hits,
                                selectedId: selectedId,
                                onOpen: onOpenHit ?? (_) {},
                              ),
                      ),
              ),
            ],
            const Divider(height: 1),
            _MoreSection(
              entries: [
                if (onOpenProfiles != null)
                  (AppIcons.person, 'Profiles', onOpenProfiles!),
                if (onOpenSkills != null)
                  (AppIcons.extension, 'Skills', onOpenSkills!),
                if (onOpenMessaging != null)
                  (AppIcons.bot, 'Messaging', onOpenMessaging!),
                if (onOpenPlugins != null)
                  (AppIcons.extension, 'Plugins', onOpenPlugins!),
                if (onOpenMcp != null)
                  (AppIcons.power, 'MCP servers', onOpenMcp!),
                if (onOpenHelperModels != null)
                  (AppIcons.tune, 'Helper models', onOpenHelperModels!),
              ],
            ),
            const AccountFooter(),
          ],
        ),
      ),
    );
  }

  /// The Mac sidebar under its header: the destinations and the threads, or
  /// while a search is open, its results. New Chat and the search field are
  /// in the toolbar there.
  Widget _macBody() {
    final navigation = this.navigation;
    final body = Column(
      children: [
        if (navigation != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: navigation,
          ),
        Expanded(
          child: _MacThreadList(
            threads: threads,
            selectedId: selectedId,
            onSelect: onSelect,
            busy: busy,
            housekeeping: housekeeping,
            onOpenInNewWindow: onOpenInNewWindow,
          ),
        ),
      ],
    );
    final search = this.search;
    if (search == null) return body;
    return ListenableBuilder(
      listenable: search,
      builder: (context, _) => !search.active
          ? body
          : MacSearchResults(
              query: search.query,
              status: search.status,
              hits: search.hits,
              scope: search.scope,
              recent: search.recent,
              currentProfile: searchProfile,
              selectedId: selectedId,
              onOpen: onOpenHit ?? (_) {},
              onPickRecent: search.update,
              onScopeChanged: search.canSearchAllProfiles
                  ? search.setScope
                  : null,
            ),
    );
  }

  Widget _threadList() {
    final housekeeping = this.housekeeping;
    final showMore = housekeeping != null && housekeeping.hasMore;
    return ListView.builder(
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
          busy: busy.contains(thread.id) || thread.isReplying,
          onTap: () => onSelect(thread.id),
          housekeeping: thread.remote ? housekeeping : null,
        );
      },
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
    this.expanded,
  });

  final AppIconSet icon;
  final String label;
  final VoidCallback onTap;

  /// Fills the row, as for the open destination.
  final bool selected;

  /// Whether the section this row opens is open; null for a plain action.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      expanded: expanded,
      child: Material(
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
                AppIcon(icon, size: 18),
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
      ),
    );
  }
}

/// Profiles, skills, messaging, plugins, MCP servers and helper models behind one
/// row, so the thread list keeps the height.
class _MoreSection extends StatefulWidget {
  const _MoreSection({required this.entries});

  final List<(AppIconSet, String, VoidCallback)> entries;

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
            icon: _open ? AppIcons.expandMore : AppIcons.chevronRight,
            label: 'More',
            expanded: _open,
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
    required this.busy,
    required this.onTap,
    this.housekeeping,
  });

  final ChatThread thread;
  final bool selected;
  final bool busy;
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
    final housekeeping = widget.housekeeping;
    final touch = platformChromeOf(context) == PlatformChrome.ios;
    final swipeable = touch && housekeeping != null;
    final inlineButton = housekeeping != null && !touch;
    final row = Semantics(
      hint: relativeTime(_thread.updatedAt),
      child: SidebarRow(
        selected: widget.selected,
        onTap: widget.onTap,
        onLongPress: inlineButton ? _openMenu : null,
        onSecondaryTap: inlineButton ? _openMenu : null,
        padding: touch
            ? const EdgeInsets.symmetric(horizontal: 10)
            : EdgeInsets.fromLTRB(
                10,
                inlineButton ? 2 : 9,
                inlineButton ? 2 : 10,
                inlineButton ? 2 : 9,
              ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: touch ? kAppleMinTapTarget : 0,
          ),
          child: Row(
            children: [
              if (_thread.pinned) ...[
                AppIcon(AppIcons.pin, size: 12, color: subtle),
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
              if (widget.busy) ...[
                const WorkingDot(),
                const SizedBox(width: 4),
              ],
              if (inlineButton)
                ThreadActionsButton(
                  key: _actions,
                  thread: _thread,
                  housekeeping: housekeeping,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
    );
    if (!swipeable) return row;
    return SwipeableThreadRow(
      title: _thread.title,
      pinned: _thread.pinned,
      onAction: (action) => runThreadAction(
        context,
        action,
        thread: _thread,
        housekeeping: housekeeping,
      ),
      child: row,
    );
  }
}

/// The threads of a Mac sidebar in sections. Which sections are folded comes
/// from the window's [MacSidebarScope], so it outlasts a relaunch; without one
/// the list keeps it itself.
class _MacThreadList extends StatefulWidget {
  const _MacThreadList({
    required this.threads,
    required this.selectedId,
    required this.onSelect,
    required this.busy,
    required this.housekeeping,
    required this.onOpenInNewWindow,
  });

  final List<ChatThread> threads;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Set<String> busy;
  final ThreadHousekeeping? housekeeping;
  final ValueChanged<ChatThread>? onOpenInNewWindow;

  @override
  State<_MacThreadList> createState() => _MacThreadListState();
}

class _MacThreadListState extends State<_MacThreadList> {
  final _folded = <String>{};

  @override
  Widget build(BuildContext context) {
    final sections = MacSidebarScope.sectionsOf(context);
    if (sections == null) return _list(context);
    return ListenableBuilder(
      listenable: sections,
      builder: (context, _) => _list(context, sections),
    );
  }

  Widget _list(BuildContext context, [MacSidebarSections? sections]) {
    bool folded(ThreadSectionKind kind) =>
        sections?.isCollapsed(kind.name) ?? _folded.contains(kind.name);
    void toggle(ThreadSectionKind kind) => sections != null
        ? sections.toggle(kind.name)
        : setState(() {
            if (!_folded.remove(kind.name)) _folded.add(kind.name);
          });

    final housekeeping = widget.housekeeping;
    final items = <Object>[
      for (final section in groupThreads(
        widget.threads,
        now: DateTime.now(),
      )) ...[section.kind, if (!folded(section.kind)) ...section.threads],
      if (housekeeping != null && housekeeping.hasMore) housekeeping,
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        final ThreadSectionKind kind => MacSidebarSectionHeader(
          key: ValueKey('thread-section-${kind.label}'),
          label: kind.label,
          collapsed: folded(kind),
          onToggle: () => toggle(kind),
        ),
        final ChatThread thread => _row(context, thread),
        _ => _ShowMoreRow(
          key: ValueKey(widget.threads.length),
          loading: housekeeping!.loadingMore,
          onLoad: housekeeping.loadMore,
        ),
      },
    );
  }

  Widget _row(BuildContext context, ChatThread thread) {
    final housekeeping = thread.remote ? widget.housekeeping : null;
    final onOpenInNewWindow = widget.onOpenInNewWindow;
    void run(ThreadAction action) => runThreadAction(
      context,
      action,
      thread: thread,
      housekeeping: housekeeping,
      onOpenInNewWindow: onOpenInNewWindow,
    );
    return MacThreadRow(
      key: ValueKey('thread-${thread.id}'),
      title: thread.title,
      selected: thread.id == widget.selectedId,
      busy: widget.busy.contains(thread.id) || thread.isReplying,
      relativeTime: relativeTime(thread.updatedAt),
      onTap: () => widget.onSelect(thread.id),
      onArchive: housekeeping == null ? null : () => run(ThreadAction.archive),
      menuItems: (_) => macThreadMenuItems(
        pinned: thread.pinned,
        canonical: thread.isCanonicalBotChat,
        manageable: housekeeping != null,
        canOpenInNewWindow: onOpenInNewWindow != null && thread.remote,
      ),
      onAction: run,
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
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
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
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: 'Account',
          child: Tooltip(
            message: 'Account',
            excludeFromSemantics: true,
            child: AdaptivePopupMenuButton<String>(
              tooltip: '',
              offset: const Offset(0, -8),
              position: PopupMenuPosition.over,
              onSelected: (value) {
                if (value == 'sign-out') auth.signOut();
                if (value == 'change-server') auth.changeServer();
                if (value == 'appearance') showAppearanceDialog(context);
                if (value == 'notifications') showNotificationsDialog(context);
                if (value == 'app-lock') showAppLockDialog(context);
                if (value == 'about') showAppAboutDialog(context);
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
                const PopupMenuItem(
                  value: 'appearance',
                  child: Text('Appearance'),
                ),
                const PopupMenuItem(
                  value: 'notifications',
                  child: Text('Notifications'),
                ),
                const PopupMenuItem(value: 'app-lock', child: Text('App lock')),
                const PopupMenuItem(value: 'about', child: Text('About')),
                if (auth.status?.authRequired ?? false)
                  const PopupMenuItem(
                    value: 'sign-out',
                    child: Text('Sign out'),
                  ),
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
                      child: AppIcon(
                        AppIcons.person,
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
                    AppIcon(
                      AppIcons.more,
                      size: 16,
                      color: context.hermesColors.subtleText,
                    ),
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
