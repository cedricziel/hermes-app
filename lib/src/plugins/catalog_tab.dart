import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_search_field.dart';

import 'catalog_controller.dart';
import 'catalog_detail.dart';
import 'catalog_entry.dart';
import 'install_report.dart';
import 'plugins_controller.dart' show PluginsFailure;
import 'sheet_host.dart';
import 'widgets/catalog_row.dart';

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
        final wide = isWideLayout(context, width: constraints.maxWidth);
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final selected = _controller.selected;
            return ListWithDetail(
              wide: wide,
              list: Column(
                children: [
                  // A Mac window searches from its toolbar.
                  if (platformChromeOf(context) != PlatformChrome.macos)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SettingsSearchField(
                        key: const Key('catalog-search'),
                        search: SettingsSearch(
                          query: _controller.query,
                          hint: 'Search catalog',
                          onChanged: _controller.setQuery,
                        ),
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
      return const Center(child: CircularProgressIndicator.adaptive());
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
          : GroupedListView(
              key: const Key('catalog-list'),
              children: [
                GroupedSection(
                  children: [
                    for (final entry in entries)
                      CatalogRow(
                        entry: entry,
                        installing: _controller.isInstalling(entry.name),
                        selected:
                            wide && entry.name == _controller.selectedName,
                        onTap: () => _open(entry, wide: wide),
                        onInstall: () => _install(entry),
                      ),
                  ],
                ),
              ],
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
    final metrics = GroupedMetrics.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          children: [
            GroupedSwitchRow(
              key: const Key('catalog-enable-switch'),
              title: 'Enable after install',
              value: _enable,
              onChanged: widget.installing
                  ? null
                  : (value) => setState(() => _enable = value),
            ),
          ],
        ),
        SizedBox(height: metrics.sectionGap),
        FilledButton(
          key: const Key('catalog-detail-install'),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(metrics.rowMinHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(metrics.radius),
            ),
          ),
          onPressed: widget.installing ? null : () => widget.onInstall(_enable),
          child: widget.installing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Text('Install'),
        ),
      ],
    );
  }
}
