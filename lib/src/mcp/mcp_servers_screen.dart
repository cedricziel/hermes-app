import 'package:flutter/material.dart';

import '../profiles/hermes_profiles_repository.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../widgets/adaptive_popup_menu_button.dart';
import '../widgets/grouped_list.dart';
import '../widgets/row_actions.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_add_server_screen.dart';
import 'mcp_catalog_screen.dart';
import 'mcp_json_editor_screen.dart';
import 'mcp_presentation.dart';
import 'mcp_server_detail.dart';
import 'mcp_servers_controller.dart';
import 'widgets/mcp_server_row.dart';

/// Lists the MCP servers of the active profile and switches, tests and removes
/// them. Below [wideBreakpoint] a tapped server opens as a page; at or above
/// it the detail sits beside the list.
///
/// The profile is the sticky active one, learned from [profiles] on every
/// visit and named in the header, so a switch is never flipped on another
/// profile than the one shown.
class McpServersScreen extends StatefulWidget {
  const McpServersScreen({
    super.key,
    required this.repository,
    this.profiles,
    this.profile,
    this.launchLink,
  });

  final HermesMcpRepository repository;

  /// The profile to show; the active one when null.
  final String? profile;

  /// Where the active profile comes from; without it the screen acts without
  /// a profile.
  final HermesProfilesRepository? profiles;

  /// Opens links in the browser; the system browser unless a test says
  /// otherwise.
  final McpLinkLauncher? launchLink;

  @override
  State<McpServersScreen> createState() => _McpServersScreenState();
}

class _McpServersScreenState extends State<McpServersScreen> {
  late final McpServersController _controller;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _controller = McpServersController(
      repository: widget.repository,
      profiles: widget.profiles,
      forProfile: widget.profile,
      launchLink: widget.launchLink,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Whether the screen is laid out with the detail beside the list. Read
  /// from the media instead of the body's layout, which the empty state
  /// never builds.
  bool _isWide(BuildContext context) => isWideLayout(context);

  void _open(HermesMcpServer server) {
    if (_isWide(context)) {
      setState(() => _selected = server.name);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            McpServerPage(controller: _controller, name: server.name),
      ),
    );
  }

  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => McpCatalogScreen(servers: _controller),
      ),
    );
  }

  void _openJsonEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => McpJsonEditorScreen(servers: _controller),
      ),
    );
  }

  Future<void> _openCustomForm() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => McpAddServerScreen(servers: _controller),
      ),
    );
    if (!mounted || name == null) return;
    if (_controller.serverNamed(name) case final added?) {
      _open(added);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final profile = _controller.profile;
        final servers = _controller.servers;
        final loaded = servers != null && !_controller.failed;
        final mac = platformChromeOf(context) == PlatformChrome.macos;
        return SettingsScaffold(
          title: 'MCP servers',
          subtitle: mac && loaded
              ? [?profile, mcpPlural(servers.length, 'server')].join(' · ')
              : profile,
          actions: [
            if (loaded) ...[
              SettingsBarAction.menu(
                label: 'Add server',
                icon: AppIcons.add,
                menu: (_) => [
                  AdaptiveMenuItem<void>(
                    onTap: _openCatalog,
                    child: const Text('Browse the catalog'),
                  ),
                  AdaptiveMenuItem<void>(
                    onTap: _openCustomForm,
                    child: const Text('Add a custom server'),
                  ),
                ],
              ),
              SettingsBarAction.menu(
                label: 'More',
                icon: AppIcons.more,
                menu: (_) => [
                  AdaptiveMenuItem<void>(
                    onTap: _openJsonEditor,
                    child: const Text('Edit as JSON'),
                  ),
                ],
              ),
            ],
          ],
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    final servers = _controller.servers;
    if (_controller.loading && servers == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_controller.failed || servers == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load MCP servers'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (servers.isEmpty) {
      return _EmptyState(
        profile: _controller.profile,
        onBrowse: _openCatalog,
        onAddCustom: _openCustomForm,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = isWideLayout(context, width: constraints.maxWidth);
        final selected = _controller.serverNamed(_selected) ?? servers.first;
        final list = _ServerList(
          controller: _controller,
          servers: servers,
          selected: wide ? selected.name : null,
          onOpen: _open,
        );
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 380, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: McpServerDetail(
                key: ValueKey(selected.name),
                controller: _controller,
                name: selected.name,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.profile,
    required this.onBrowse,
    required this.onAddCustom,
  });

  final String? profile;
  final VoidCallback onBrowse;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) => StateMessage(
    title: profile == null ? 'No MCP servers' : 'No MCP servers on "$profile"',
    detail:
        'MCP servers give the agent extra tools, such as searching your '
        'documents or reading a calendar.',
    action: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: onBrowse,
          child: const Text('Browse the catalog'),
        ),
        OutlinedButton(
          onPressed: onAddCustom,
          child: const Text('Add a custom server'),
        ),
      ],
    ),
  );
}

class _ServerList extends StatelessWidget {
  const _ServerList({
    required this.controller,
    required this.servers,
    required this.selected,
    required this.onOpen,
  });

  final McpServersController controller;
  final List<HermesMcpServer> servers;
  final String? selected;
  final ValueChanged<HermesMcpServer> onOpen;

  @override
  Widget build(BuildContext context) {
    return GroupedListView(
      children: [
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          footer:
              'Changes apply from the next chat, not to one that is '
              'already running.',
          children: [
            for (final server in servers)
              RowActions(
                key: ValueKey('mcp-actions-${server.name}'),
                title: server.name,
                actions: [
                  if (!controller.isSwitching(server.name))
                    RowAction(
                      label: server.enabled ? 'Turn off' : 'Turn on',
                      icon: server.enabled
                          ? AppIcons.toggleOff
                          : AppIcons.toggleOn,
                      onPressed: () => switchMcpServer(
                        context,
                        controller,
                        server,
                        !server.enabled,
                      ),
                    ),
                  RowAction(
                    label: 'Remove',
                    icon: AppIcons.delete,
                    destructive: true,
                    onPressed: () =>
                        removeMcpServer(context, controller, server),
                  ),
                ],
                child: McpServerRow(
                  key: ValueKey('mcp-row-${server.name}'),
                  server: server,
                  tested: switch (controller.testOf(server.name)) {
                    McpTestFinished(:final result) => result,
                    _ => null,
                  },
                  selected: server.name == selected,
                  switching: controller.isSwitching(server.name),
                  onTap: () => onOpen(server),
                  onSwitch: (on) =>
                      switchMcpServer(context, controller, server, on),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
