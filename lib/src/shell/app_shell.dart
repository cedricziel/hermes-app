import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../chat/chat_screen.dart';
import '../kanban/hermes_plugins_repository.dart';
import '../kanban/kanban_screen.dart';

/// Top-level navigation between Chat and the optional Kanban plugin.
///
/// The Kanban tab exists only while the server reports the plugin as on; with
/// it off the shell is just the chat, exactly as before. The check runs on
/// connect and whenever the app returns to the foreground.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.plugins});

  /// Overrides the repository built from the signed-in client.
  final HermesPluginsRepository? plugins;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const double _wideBreakpoint = 900;

  final _chatKey = GlobalKey();
  HermesPluginsRepository? _plugins;
  bool _kanban = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthController>().api;
    _plugins =
        widget.plugins ??
        (api == null ? null : HermesPluginsRepository(api.raw));
    WidgetsBinding.instance.addObserver(this);
    _detect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _detect();
  }

  Future<void> _detect() async {
    final enabled = await _plugins?.isKanbanEnabled() ?? false;
    if (!mounted || enabled == _kanban) return;
    setState(() {
      _kanban = enabled;
      if (!enabled) _index = 0;
    });
  }

  static const _destinations = [
    (
      icon: Icons.chat_bubble_outline,
      selected: Icons.chat_bubble,
      label: 'Chat',
    ),
    (
      icon: Icons.view_kanban_outlined,
      selected: Icons.view_kanban,
      label: 'Kanban',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final chat = KeyedSubtree(key: _chatKey, child: const ChatScreen());
    if (!_kanban) return chat;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final pages = IndexedStack(
          index: _index,
          children: [chat, const KanbanScreen()],
        );
        void select(int i) => setState(() => _index = i);
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages),
              ],
            ),
          );
        }
        return Scaffold(
          body: pages,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: select,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
