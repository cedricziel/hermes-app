import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';

import 'installed_plugin.dart';
import 'plugin_actions.dart';
import 'plugin_detail.dart';
import 'widgets/plugin_row.dart';
import 'plugins_controller.dart';
import 'sheet_host.dart';
import '../widgets/grouped_list.dart';
import '../widgets/row_actions.dart';

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
        final wide = isWideLayout(context, width: constraints.maxWidth);
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
      return const Center(child: CircularProgressIndicator.adaptive());
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
          : GroupedListView(
              children: [
                GroupedSection(
                  children: [
                    for (final plugin in plugins)
                      RowActions(
                        title: plugin.name,
                        actions: pluginRowActions(context, _controller, plugin),
                        child: PluginRow(
                          plugin: plugin,
                          selected:
                              wide && plugin.name == _controller.selectedName,
                          onTap: () => _open(plugin, wide: wide),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
