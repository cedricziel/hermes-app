import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';

import 'installed_plugin.dart';
import 'plugin_detail.dart';
import 'plugin_tag.dart';
import 'plugins_controller.dart';
import 'sheet_host.dart';

/// The installed plugins, with a details view for each: a bottom sheet on a
/// narrow screen, a pane beside the list on a wide one.
class InstalledTab extends StatefulWidget {
  const InstalledTab({super.key, required this.controller});

  final PluginsController controller;

  @override
  State<InstalledTab> createState() => _InstalledTabState();
}

class _InstalledTabState extends State<InstalledTab>
    with AutomaticKeepAliveClientMixin {
  PluginsController get _controller => widget.controller;

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _controller.refresh()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not refresh plugins')),
      );
    }
  }

  Future<void> _open(InstalledPlugin plugin, {required bool wide}) async {
    _controller.select(plugin.name);
    if (wide) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SheetHost(
        listenable: _controller,
        isGone: () => _controller.selected == null,
        builder: (_) => PluginDetail(
          plugin: _controller.selected!,
          controller: _controller,
        ),
      ),
    );
    if (mounted) _controller.select(null);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideLayoutBreakpoint;
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final selected = _controller.selected;
            return ListWithDetail(
              wide: wide,
              list: _body(wide),
              detail: selected == null
                  ? null
                  : PluginDetail(
                      key: ValueKey(selected.name),
                      plugin: selected,
                      controller: _controller,
                    ),
              placeholder: 'Select a plugin',
            );
          },
        );
      },
    );
  }

  Widget _body(bool wide) {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_controller.failure) {
      case PluginsFailure.unsupported:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The plugin list is not available on this server',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case PluginsFailure.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load plugins'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _controller.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case null:
        break;
    }
    final plugins = _controller.plugins;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: plugins.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: Text('No plugins installed')),
                ),
              ],
            )
          : ListView.separated(
              itemCount: plugins.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final plugin = plugins[index];
                return _PluginRow(
                  plugin: plugin,
                  selected: wide && plugin.name == _controller.selectedName,
                  onTap: () => _open(plugin, wide: wide),
                );
              },
            ),
    );
  }
}

class _PluginRow extends StatelessWidget {
  const _PluginRow({
    required this.plugin,
    required this.selected,
    required this.onTap,
  });

  final InstalledPlugin plugin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurfaceVariant;
    final tags = [
      if (plugin.bundled) const PluginTag('Bundled'),
      if (plugin.authRequired) const PluginTag('Needs login', strong: true),
      if (plugin.removedReason case final reason?)
        PluginTag('Removed: $reason', strong: true),
    ];
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      onTap: onTap,
      title: Row(
        children: [
          Flexible(child: Text(plugin.name, overflow: TextOverflow.ellipsis)),
          if (plugin.version.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(plugin.version, style: TextStyle(color: subtle, fontSize: 12)),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plugin.description.isNotEmpty)
            Text(
              plugin.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 4, children: tags),
            ),
        ],
      ),
      trailing: PluginStatusChip(plugin.status),
    );
  }
}
