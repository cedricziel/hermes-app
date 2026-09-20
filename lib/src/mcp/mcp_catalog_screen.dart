import 'package:flutter/material.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_catalog_controller.dart';
import 'mcp_chip.dart';
import 'mcp_install_panel.dart';
import 'mcp_presentation.dart';
import 'mcp_server_detail.dart';
import 'mcp_servers_controller.dart';
import 'mcp_servers_screen.dart';

/// Browses Hermes' approved MCP servers for the profile [servers] acts on.
/// Below [McpServersScreen.wideBreakpoint] a tapped entry opens on its own;
/// at or above it, beside the list.
class McpCatalogScreen extends StatefulWidget {
  const McpCatalogScreen({super.key, required this.servers});

  /// The state of the MCP servers screen that opened the catalog. It knows
  /// the profile and is told about what gets installed.
  final McpServersController servers;

  @override
  State<McpCatalogScreen> createState() => _McpCatalogScreenState();
}

class _McpCatalogScreenState extends State<McpCatalogScreen> {
  late final McpCatalogController _catalog;
  final _search = TextEditingController();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _catalog = McpCatalogController(widget.servers)..load();
  }

  @override
  void dispose() {
    _catalog.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(HermesMcpCatalogEntry entry, {required bool wide}) async {
    if (wide) {
      setState(() => _selected = entry.name);
    } else if (entry.installed) {
      await _openServer(entry.name);
    } else {
      await _openSheet(entry);
    }
  }

  Future<void> _openSheet(HermesMcpCatalogEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => McpInstallPanel(
        servers: widget.servers,
        catalog: _catalog,
        entry: entry,
        onInstalled: () {
          Navigator.of(sheet).pop();
          _announceInstalled(entry.name, wide: false);
        },
        onGone: () => Navigator.of(sheet).pop(),
      ),
    );
  }

  void _announceInstalled(String name, {required bool wide}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Installed $name'),
        action: wide
            ? null
            : SnackBarAction(label: 'Open', onPressed: () => _openServer(name)),
      ),
    );
  }

  Future<void> _openServer(String name) async {
    final servers = widget.servers;
    if (servers.serverNamed(name) == null) await servers.refresh();
    if (!mounted || servers.serverNamed(name) == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => McpServerPage(controller: servers, name: name),
      ),
    );
  }

  void _clearSearch() {
    _search.clear();
    _catalog.clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.servers,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catalog'),
              if (widget.servers.profile case final profile?)
                Text(
                  'Installing into: $profile',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _catalog,
        builder: (context, _) => _body(),
      ),
    );
  }

  Widget _body() {
    if (_catalog.loading && _catalog.entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_catalog.failed || _catalog.entries == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load the catalog'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _catalog.load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= McpServersScreen.wideBreakpoint;
        final list = _CatalogList(
          catalog: _catalog,
          search: _search,
          selected: wide ? _selected : null,
          onOpen: (entry) => _open(entry, wide: wide),
          onClear: _clearSearch,
        );
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 380, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: _pane()),
          ],
        );
      },
    );
  }

  Widget _pane() {
    final entry = _catalog.entryNamed(_selected);
    if (entry == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pick a server to see what Hermes would run.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!entry.installed) {
      return McpInstallPanel(
        key: ValueKey(entry.name),
        servers: widget.servers,
        catalog: _catalog,
        entry: entry,
        onInstalled: () => _announceInstalled(entry.name, wide: true),
      );
    }
    return McpServerDetail(
      key: ValueKey(entry.name),
      controller: widget.servers,
      name: entry.name,
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    required this.catalog,
    required this.search,
    required this.selected,
    required this.onOpen,
    required this.onClear,
  });

  final McpCatalogController catalog;
  final TextEditingController search;
  final String? selected;
  final ValueChanged<HermesMcpCatalogEntry> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = catalog.visible;
    final total = catalog.entries?.length ?? 0;
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: search,
            onChanged: catalog.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search ${mcpPlural(total, 'server')}',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final filter in McpCatalogFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: catalog.filter == filter,
                  onSelected: (_) => catalog.select(filter),
                ),
            ],
          ),
        ),
        if (catalog.hasDiagnostics)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Some catalog entries could not be read.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('No servers match', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear search'),
                ),
              ],
            ),
          ),
        for (final entry in visible)
          _CatalogRow(
            key: ValueKey('mcp-catalog-row-${entry.name}'),
            entry: entry,
            selected: entry.name == selected,
            onTap: () => onOpen(entry),
          ),
      ],
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final HermesMcpCatalogEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transport = mcpTransportLabel(entry.transport);
    final auth = mcpAuthKindLabel(entry.authKind);
    return Material(
      color: selected
          ? theme.colorScheme.surfaceContainerHighest
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  entry.name.characters.first.toUpperCase(),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (entry.description.isNotEmpty)
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (transport != null) McpChip(transport),
                        if (auth != null) McpChip(auth),
                        if (entry.buildsLocally)
                          const McpChip('Builds locally'),
                        if (entry.installed) const McpChip('Installed'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
