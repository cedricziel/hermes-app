import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'catalog_controller.dart';
import 'catalog_detail.dart' show LinkOpener;
import 'catalog_tab.dart';
import 'hermes_plugin_manager_repository.dart';
import 'installed_tab.dart';
import 'plugins_controller.dart';
import 'providers_controller.dart';
import 'providers_tab.dart';

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

class _PluginsScreenState extends State<PluginsScreen> {
  late final PluginsController _installed;
  late final CatalogController _catalog;
  late final ProvidersController _providers;

  @override
  void initState() {
    super.initState();
    final repository =
        widget.repository ??
        HermesPluginManagerRepository(context.read<AuthController>().api!.raw);
    final events =
        widget.events ?? context.read<AppEventLogger?>() ?? noopAppEventLogger;
    _installed = PluginsController(repository, events: events)..load();
    _catalog = CatalogController(
      repository,
      events: events,
      onInstalled: _installed.refresh,
    );
    _providers = ProvidersController(repository, events: events);
  }

  @override
  void dispose() {
    _providers.dispose();
    _catalog.dispose();
    _installed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plugins'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Installed'),
              Tab(text: 'Catalog'),
              Tab(text: 'Providers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            InstalledTab(controller: _installed),
            CatalogTab(controller: _catalog, openLink: widget.openLink),
            ProvidersTab(controller: _providers),
          ],
        ),
      ),
    );
  }
}
