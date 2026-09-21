import 'package:hermes_app/src/plugins/catalog_detail.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/plugin_tag.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Future<bool> _opens(Uri _) async => true;

WidgetbookNode pluginsNode() => WidgetbookFolder(
  name: 'Plugins',
  children: [
    WidgetbookComponent(
      name: 'PluginTag',
      useCases: [
        WidgetbookUseCase(
          name: 'Variants',
          builder: (_) => frame(
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PluginTag('Plain'),
                PluginTag('Strong', strong: true),
                PluginTag('Filled', filled: true),
                PluginTag('a1b2c3d', mono: true),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PluginStatusChip',
      useCases: [
        for (final status in PluginStatus.values)
          WidgetbookUseCase(
            name: status.name[0].toUpperCase() + status.name.substring(1),
            builder: (_) => frame(PluginStatusChip(status)),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'CatalogDetail',
      useCases: [
        WidgetbookUseCase(
          name: 'Official',
          builder: (_) => fill(
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
        WidgetbookUseCase(
          name: 'Installed, update available',
          builder: (_) => fill(
            CatalogDetail(
              entry: installedCatalogEntry,
              openLink: _opens,
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Update'),
              ),
            ),
            width: 480,
          ),
        ),
      ],
    ),
  ],
);
