import 'package:flutter/material.dart';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../api/hermes_repositories.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';

import 'catalog_controller.dart';
import 'catalog_detail.dart' show LinkOpener;
import 'catalog_tab.dart';
import 'git_install_dialog.dart';
import 'hermes_plugin_manager_repository.dart';
import 'install_report.dart';
import 'installed_plugin.dart';
import 'installed_tab.dart';
import 'plugin_install_result.dart';
import 'plugins_controller.dart';
import 'providers_controller.dart';
import 'providers_tab.dart';

const _catalogTab = 1;

/// Manages the plugins of the connected dashboard: the ones installed, with a
/// details view for each, and the catalog to install more from.
class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key, this.repository, this.events, this.openLink});

  final HermesPluginManagerRepository? repository;
  final AppEventLogger? events;

  /// Opens a docs link; the system browser when null.
  final LinkOpener? openLink;

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen>
    with SingleTickerProviderStateMixin {
  late final HermesPluginManagerRepository _repository;
  late final PluginsController _installed;
  late final CatalogController _catalog;
  final _catalogQuery = ValueNotifier<String>('');
  late final ProvidersController _providers;
  late final _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    final repositories = widget.repository == null || widget.events == null
        ? HermesRepositories.maybeOf(context)
        : null;
    _repository = widget.repository ?? repositories!.pluginManager;
    final events =
        widget.events ?? repositories?.telemetry.events ?? noopAppEventLogger;
    _installed = PluginsController(_repository, events: events)..load();
    _catalog = CatalogController(
      _repository,
      events: events,
      onInstalled: _installed.refresh,
    );
    _providers = ProvidersController(_repository, events: events);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _catalogQuery.dispose();
    _providers.dispose();
    _catalog.dispose();
    _installed.dispose();
    super.dispose();
  }

  Future<void> _installFromGit() async {
    final result = await showDialog<PluginInstallResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GitInstallDialog(install: _catalog.installFromSource),
    );
    if (result == null || !mounted) return;
    await reportInstall(context, result);
  }

  /// Filters the catalog from the Mac toolbar. The catalog's other changes
  /// (it loads when its tab first builds) must not rebuild the toolbar, so
  /// only the query does, through [_catalogQuery].
  void _search(String query) {
    _catalog.setQuery(query);
    _catalogQuery.value = query;
  }

  /// "work · 3 installed · 2 on" on a Mac, the profile alone elsewhere.
  String? _subtitle(bool mac) {
    final plugins = _installed.plugins;
    final parts = [
      ?_repository.profile,
      if (mac && !_installed.loading && _installed.failure == null) ...[
        '${plugins.length} installed',
        '${plugins.where((p) => p.status == PluginStatus.enabled).length} on',
      ],
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return ListenableBuilder(
      listenable: Listenable.merge([_installed, _tabs, _catalogQuery]),
      child: TabBarView(
        controller: _tabs,
        children: [
          InstalledTab(controller: _installed),
          CatalogTab(controller: _catalog, openLink: widget.openLink),
          ProvidersTab(controller: _providers),
        ],
      ),
      builder: (context, body) => SettingsScaffold(
        title: 'Plugins',
        subtitle: _subtitle(mac),
        tabs: const ['Installed', 'Catalog', 'Providers'],
        tabController: _tabs,
        search: mac && _tabs.index == _catalogTab
            ? SettingsSearch(
                query: _catalog.query,
                hint: 'Search catalog',
                onChanged: _search,
              )
            : null,
        actions: [
          SettingsBarAction(
            key: const Key('catalog-git-install'),
            label: 'Install from Git',
            icon: AppIcons.add,
            onPressed: _installFromGit,
          ),
        ],
        body: body!,
      ),
    );
  }
}
