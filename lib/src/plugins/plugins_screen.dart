import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'hermes_plugin_manager_repository.dart';
import 'installed_plugin.dart';
import 'plugin_detail.dart';
import 'plugin_tag.dart';
import 'plugins_controller.dart';

/// The plugins installed on the connected dashboard, with a details view for
/// each: a bottom sheet on a narrow screen, a pane beside the list on a wide
/// one.
class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key, this.repository, this.events});

  final HermesPluginManagerRepository? repository;
  final AppEventLogger? events;

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  static const _wideBreakpoint = 900.0;

  late final PluginsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PluginsController(
      widget.repository ??
          HermesPluginManagerRepository(
            context.read<AuthController>().api!.raw,
          ),
      events:
          widget.events ??
          context.read<AppEventLogger?>() ??
          noopAppEventLogger,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      builder: (_) => _SheetHost(controller: _controller),
    );
    if (mounted) _controller.select(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugins')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final list = _body(wide);
              if (!wide) return list;
              final selected = _controller.selected;
              return Row(
                children: [
                  SizedBox(width: 400, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selected == null
                        ? const Center(child: Text('Select a plugin'))
                        : PluginDetail(
                            key: ValueKey(selected.name),
                            plugin: selected,
                            controller: _controller,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
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

/// Shows the selected plugin's details in a bottom sheet, and closes the
/// sheet when the plugin is gone.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.controller});

  final PluginsController controller;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_closeIfGone);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_closeIfGone);
    super.dispose();
  }

  void _closeIfGone() {
    if (widget.controller.selected == null && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final plugin = widget.controller.selected;
        if (plugin == null) return const SizedBox(height: 1);
        return PluginDetail(plugin: plugin, controller: widget.controller);
      },
    );
  }
}
