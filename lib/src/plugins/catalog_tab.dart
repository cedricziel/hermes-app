import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog_controller.dart';
import 'catalog_detail.dart';
import 'catalog_entry.dart';
import 'git_install_dialog.dart';
import 'install_report.dart';
import 'plugin_install_result.dart';
import 'plugin_tag.dart';
import 'plugins_controller.dart' show PluginsFailure;
import 'sheet_host.dart';

/// The catalog to install plugins from, with a search field. It loads when
/// it is first shown.
class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key, required this.controller, this.openLink});

  final CatalogController controller;

  /// Opens a docs link; the system browser when null.
  final LinkOpener? openLink;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab>
    with AutomaticKeepAliveClientMixin {
  CatalogController get _controller => widget.controller;
  final _search = TextEditingController();

  LinkOpener get _openLink =>
      widget.openLink ??
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _controller.refresh()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not refresh the catalog')),
      );
    }
  }

  Future<void> _open(CatalogEntry entry, {required bool wide}) async {
    _controller.select(entry.name);
    if (wide) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SheetHost(
        listenable: _controller,
        isGone: () => _controller.selected == null,
        builder: (_) => _detail(_controller.selected!),
      ),
    );
    if (mounted) _controller.select(null);
  }

  Future<void> _install(CatalogEntry entry, {bool enable = true}) async {
    final result = await _controller.installFromCatalog(
      entry.name,
      enable: enable,
    );
    if (result == null || !mounted) return;
    await reportInstall(context, result);
  }

  Future<void> _installFromGit() async {
    final result = await showDialog<PluginInstallResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GitInstallDialog(install: _controller.installFromSource),
    );
    if (result == null || !mounted) return;
    await reportInstall(context, result);
  }

  Widget _detail(CatalogEntry entry) => CatalogDetail(
    key: ValueKey(entry.name),
    entry: entry,
    openLink: _openLink,
    actions: entry.installed
        ? null
        : InstallActions(
            installing: _controller.isInstalling(entry.name),
            onInstall: (enable) => _install(entry, enable: enable),
          ),
  );

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
              list: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('catalog-search'),
                            controller: _search,
                            onChanged: _controller.setQuery,
                            decoration: const InputDecoration(
                              hintText: 'Search catalog',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const Key('catalog-git-install'),
                          onPressed: _installFromGit,
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('Git URL'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _body(wide)),
                ],
              ),
              detail: selected == null ? null : _detail(selected),
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
              'The catalog is not available on this server',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case PluginsFailure.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load the catalog'),
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
    final entries = _controller.visible;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: entries.isEmpty
          ? ListView(
              key: const Key('catalog-list'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      _controller.entries.isEmpty
                          ? 'The catalog is empty'
                          : 'No plugins match',
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              key: const Key('catalog-list'),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _CatalogRow(
                  entry: entry,
                  controller: _controller,
                  selected: wide && entry.name == _controller.selectedName,
                  onTap: () => _open(entry, wide: wide),
                  onInstall: () => _install(entry),
                );
              },
            ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.entry,
    required this.controller,
    required this.selected,
    required this.onTap,
    required this.onInstall,
  });

  final CatalogEntry entry;
  final CatalogController controller;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurfaceVariant;
    final installing = controller.isInstalling(entry.name);
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      onTap: onTap,
      title: Row(
        children: [
          Flexible(child: Text(entry.name, overflow: TextOverflow.ellipsis)),
          if (entry.official) ...[
            const SizedBox(width: 8),
            const PluginTag('Official', filled: true),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.maintainer.isNotEmpty)
            Text(
              entry.maintainer,
              style: TextStyle(color: subtle, fontSize: 12),
            ),
          if (entry.description.isNotEmpty)
            Text(
              entry.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (entry.commit.isNotEmpty)
                  PluginTag(entry.commit, mono: true),
                if (entry.installed && entry.updateAvailable)
                  const PluginTag('Update available', strong: true),
              ],
            ),
          ),
        ],
      ),
      trailing: entry.installed
          ? const PluginTag('Installed', filled: true)
          : FilledButton.tonal(
              key: Key('catalog-install-${entry.name}'),
              onPressed: installing ? null : onInstall,
              child: installing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Install'),
            ),
    );
  }
}

/// The "Enable after install" switch and the Install button of an entry that
/// is not installed yet.
class InstallActions extends StatefulWidget {
  const InstallActions({
    super.key,
    required this.installing,
    required this.onInstall,
  });

  final bool installing;
  final ValueChanged<bool> onInstall;

  @override
  State<InstallActions> createState() => _InstallActionsState();
}

class _InstallActionsState extends State<InstallActions> {
  bool _enable = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SwitchListTile(
          key: const Key('catalog-enable-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable after install'),
          value: _enable,
          onChanged: widget.installing
              ? null
              : (value) => setState(() => _enable = value),
        ),
        FilledButton(
          key: const Key('catalog-detail-install'),
          onPressed: widget.installing ? null : () => widget.onInstall(_enable),
          child: widget.installing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Install'),
        ),
      ],
    );
  }
}
