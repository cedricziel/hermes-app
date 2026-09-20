import 'package:flutter/material.dart';

import '../profiles/hermes_profiles_repository.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_add_server_screen.dart';
import 'mcp_catalog_screen.dart';
import 'mcp_chip.dart';
import 'mcp_json_editor_screen.dart';
import 'mcp_presentation.dart';
import 'mcp_server_detail.dart';
import 'mcp_servers_controller.dart';

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
    this.launchLink,
  });

  final HermesMcpRepository repository;

  /// Where the active profile comes from; without it the screen acts without
  /// a profile.
  final HermesProfilesRepository? profiles;

  /// Opens links in the browser; the system browser unless a test says
  /// otherwise.
  final McpLinkLauncher? launchLink;

  static const double wideBreakpoint = mcpWideBreakpoint;

  @override
  State<McpServersScreen> createState() => _McpServersScreenState();
}

enum _MoreChoice { editAsJson }

class _McpServersScreenState extends State<McpServersScreen> {
  late final McpServersController _controller;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _controller = McpServersController(
      repository: widget.repository,
      profiles: widget.profiles,
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
  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= McpServersScreen.wideBreakpoint;

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
      MaterialPageRoute<bool>(
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
    return Scaffold(
      appBar: AppBar(
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) =>
                _controller.servers == null || _controller.failed
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MenuAnchor(
                        menuChildren: [
                          MenuItemButton(
                            onPressed: _openCatalog,
                            child: const Text('Browse the catalog'),
                          ),
                          MenuItemButton(
                            onPressed: _openCustomForm,
                            child: const Text('Add a custom server'),
                          ),
                        ],
                        builder: (context, menu, _) => TextButton.icon(
                          onPressed: () =>
                              menu.isOpen ? menu.close() : menu.open(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ),
                      PopupMenuButton<_MoreChoice>(
                        tooltip: 'More',
                        onSelected: (_) => _openJsonEditor(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _MoreChoice.editAsJson,
                            child: Text('Edit as JSON'),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
          ),
        ],
        title: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MCP servers'),
              if (_controller.profile case final profile?)
                Text(
                  'Profile: $profile',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _body(),
      ),
    );
  }

  Widget _body() {
    final servers = _controller.servers;
    if (_controller.loading && servers == null) {
      return const Center(child: CircularProgressIndicator());
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
        final wide = constraints.maxWidth >= McpServersScreen.wideBreakpoint;
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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profile == null
                  ? 'No MCP servers'
                  : 'No MCP servers on "$profile"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'MCP servers give the agent extra tools, such as searching your '
              'documents or reading a calendar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
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
          ],
        ),
      ),
    );
  }
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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Changes apply from the next chat, not to one that is '
                  'already running.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        for (final server in servers)
          _ServerRow(
            key: ValueKey('mcp-row-${server.name}'),
            server: server,
            tested: switch (controller.testOf(server.name)) {
              McpTestFinished(:final result) => result,
              _ => null,
            },
            selected: server.name == selected,
            switching: controller.isSwitching(server.name),
            onTap: () => onOpen(server),
            onSwitch: (on) => switchMcpServer(context, controller, server, on),
          ),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    super.key,
    required this.server,
    required this.tested,
    required this.selected,
    required this.switching,
    required this.onTap,
    required this.onSwitch,
  });

  final HermesMcpServer server;
  final HermesMcpTestResult? tested;
  final bool selected;
  final bool switching;
  final VoidCallback onTap;
  final ValueChanged<bool> onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tested = this.tested;
    final auth = mcpAuthLabel(server);
    final transport = mcpTransportLabel(server.transport);
    return Material(
      color: selected
          ? theme.colorScheme.surfaceContainerHighest
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  server.name.characters.first.toUpperCase(),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (server.address.isNotEmpty)
                      Text(
                        server.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: server.transport == McpTransport.command
                              ? 'monospace'
                              : null,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (transport != null) McpChip(transport),
                        if (auth != null) McpChip(auth),
                        if (!server.enabled) const McpChip('Off'),
                        if (tested != null && tested.signInNeeded)
                          const McpChip('Sign in needed', warning: true),
                        if (tested != null && tested.ok)
                          McpChip(mcpPlural(tested.tools.length, 'tool')),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: server.enabled,
                onChanged: switching ? null : onSwitch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
