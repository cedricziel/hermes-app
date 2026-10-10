import 'package:flutter/material.dart';

import '../theme/breakpoints.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_catalog_controller.dart';
import 'mcp_install_panel.dart';
import 'mcp_presentation.dart';
import 'mcp_server_detail.dart';
import 'mcp_servers_controller.dart';

/// Browses Hermes' approved MCP servers for the profile [servers] acts on.
/// Below [isWideLayout] a tapped entry opens on its own;
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
  String? _selected;

  @override
  void initState() {
    super.initState();
    _catalog = McpCatalogController(widget.servers)..load();
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  Future<void> _open(HermesMcpCatalogEntry entry, {required bool wide}) async {
    if (wide) {
      setState(() => _selected = entry.name);
      if (entry.installed && widget.servers.serverNamed(entry.name) == null) {
        await widget.servers.refresh();
      }
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_catalog, widget.servers]),
      builder: (context, _) {
        final profile = widget.servers.profile;
        final entries = _catalog.entries;
        return SettingsScaffold(
          title: 'Catalog',
          subtitle: profile == null ? null : 'Installing into: $profile',
          previousTitle: 'MCP servers',
          search: entries == null
              ? null
              : SettingsSearch(
                  query: _catalog.query,
                  onChanged: _catalog.search,
                  hint: 'Search ${mcpPlural(entries.length, 'server')}',
                  filters: [
                    for (final filter in McpCatalogFilter.values)
                      SettingsFilter(
                        label: filter.label,
                        selected: _catalog.filter == filter,
                        onSelected: () => _catalog.select(filter),
                      ),
                  ],
                ),
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    if (_catalog.loading && _catalog.entries == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
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
        final wide = isWideLayout(context, width: constraints.maxWidth);
        final list = _CatalogList(
          catalog: _catalog,
          selected: wide ? _selected : null,
          onOpen: (entry) => _open(entry, wide: wide),
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
    required this.selected,
    required this.onOpen,
  });

  final McpCatalogController catalog;
  final String? selected;
  final ValueChanged<HermesMcpCatalogEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = catalog.visible;
    return GroupedListView(
      children: [
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('No servers match', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: catalog.clearSearch,
                  child: const Text('Clear search'),
                ),
              ],
            ),
          )
        else
          GroupedSection(
            dividerIndent: GroupedMetrics.of(context).indentAfterTile,
            footer: catalog.hasDiagnostics
                ? 'Some catalog entries could not be read.'
                : null,
            children: [
              for (final entry in visible)
                _CatalogRow(
                  key: ValueKey('mcp-catalog-row-${entry.name}'),
                  entry: entry,
                  building: catalog.buildOf(entry.name) != null,
                  selected: entry.name == selected,
                  onTap: () => onOpen(entry),
                ),
            ],
          ),
      ],
    );
  }
}

/// An entry of the catalog: its initial in a tile, its name and description,
/// and its facts on one line, such as "Remote · OAuth · Installed".
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    super.key,
    required this.entry,
    required this.building,
    required this.selected,
    required this.onTap,
  });

  final HermesMcpCatalogEntry entry;
  final bool building;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final facts = [
      ?mcpTransportLabel(entry.transport),
      ?mcpAuthKindLabel(entry.authKind),
      if (entry.buildsLocally) 'Builds locally',
      if (entry.installed) 'Installed',
      if (building) 'Building',
    ].join(' · ');
    return GroupedRow(
      title: entry.name,
      leading: GroupedTile(
        child: Text(entry.name.characters.first.toUpperCase()),
      ),
      subtitle: entry.description.isEmpty ? null : entry.description,
      caption: facts.isEmpty ? null : facts,
      selected: selected,
      onTap: onTap,
    );
  }
}
