import 'package:flutter/material.dart';
import 'package:hermes_app/src/plugins/catalog_detail.dart';
import 'package:hermes_app/src/plugins/catalog_entry.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/widgets/catalog_row.dart';
import 'package:hermes_app/src/plugins/widgets/plugin_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Future<bool> _opens(Uri _) async => true;

const _plugins = [
  InstalledPlugin(
    name: 'netbox',
    version: '1.2.0',
    description: 'Query NetBox for devices and prefixes.',
    source: 'user',
    status: PluginStatus.enabled,
  ),
  InstalledPlugin(
    name: 'terminal',
    version: '1.0.0',
    description: 'Run shell commands.',
    source: 'bundled',
    status: PluginStatus.enabled,
  ),
  InstalledPlugin(
    name: 'calendar',
    version: '0.4.1',
    description: 'Read and create calendar events.',
    source: 'user',
    authRequired: true,
  ),
  InstalledPlugin(
    name: 'notes-sync',
    version: '2.0.0',
    description: 'Keep a folder of notes in step with memory.',
    source: 'user',
    status: PluginStatus.disabled,
  ),
  InstalledPlugin(
    name: 'a-plugin-with-a-name-long-enough-to-run-out-of-room',
    version: '12.0.0-beta.7',
    description:
        'Its description is long too, so it ends in an ellipsis instead of '
        'wrapping onto a second line.',
    source: 'user',
    status: PluginStatus.enabled,
    removedReason: 'unsafe network call',
  ),
];

const _entries = [
  catalogEntry,
  installedCatalogEntry,
  CatalogEntry(
    name: 'rss-reader',
    description: 'Read feeds and summarise them.',
    maintainer: 'A community author',
    installed: true,
  ),
];

Widget _group(List<Widget> rows) => Scaffold(
  body: GroupedListView(children: [GroupedSection(children: rows)]),
);

WidgetbookNode pluginsNode() => WidgetbookFolder(
  name: 'Plugins',
  children: [
    WidgetbookComponent(
      name: 'PluginRow',
      useCases: [
        ...onEachPlatform(
          'Installed plugins',
          (_) => _group([
            for (final (i, plugin) in _plugins.indexed)
              PluginRow(plugin: plugin, selected: i == 0, onTap: () {}),
          ]),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CatalogRow',
      useCases: [
        ...onEachPlatform(
          'Catalog entries',
          (_) => _group([
            for (final entry in _entries)
              CatalogRow(entry: entry, onTap: () {}, onInstall: () {}),
            CatalogRow(
              entry: const CatalogEntry(
                name: 'weather',
                description: 'Forecasts.',
                maintainer: 'A community author',
              ),
              installing: true,
              onTap: () {},
              onInstall: () {},
            ),
          ]),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CatalogDetail',
      useCases: [
        ...onEachPlatform(
          'Official',
          (_) => fill(
            CatalogDetail(
              entry: catalogEntry,
              openLink: _opens,
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Install'),
              ),
            ),
            width: 480,
          ),
        ),
        ...onEachPlatform(
          'Installed, update available',
          (_) => fill(
            CatalogDetail(entry: installedCatalogEntry, openLink: _opens),
            width: 480,
          ),
        ),
      ],
    ),
  ],
);
