import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../widgets/grouped_list.dart';
import 'catalog_entry.dart';
import 'widgets/detail_page.dart';

/// Opens [uri] in the system browser; false when nothing could open it.
typedef LinkOpener = Future<bool> Function(Uri uri);

/// One catalog entry's details. Shown in a bottom sheet or in a pane; it does
/// not know which.
class CatalogDetail extends StatelessWidget {
  const CatalogDetail({
    super.key,
    required this.entry,
    required this.openLink,
    this.actions,
  });

  final CatalogEntry entry;
  final LinkOpener openLink;

  /// What the user can do with the entry, shown above its facts.
  final Widget? actions;

  /// The docs address as a link, or null when it is not a plain web address.
  static Uri? webAddress(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final docs = webAddress(entry.docsUrl);
    final facts = [
      if (entry.installed)
        GroupedRow(
          title: 'Status',
          value: entry.updateAvailable ? 'Update available' : 'Installed',
        ),
      if (entry.commit.isNotEmpty)
        GroupedRow(title: 'Commit', value: entry.commit),
      if (entry.requiresHermes.isNotEmpty)
        GroupedRow(title: 'Requires Hermes', value: entry.requiresHermes),
      if (entry.platforms.isNotEmpty)
        GroupedRow(title: 'Platforms', value: entry.platforms.join(', ')),
    ];
    return DetailPage(
      key: const Key('catalog-detail'),
      title: entry.name,
      meta: [
        if (entry.official) 'Official',
        if (entry.maintainer.isNotEmpty) entry.maintainer,
      ].join(' · '),
      description: entry.description,
      sections: [
        ?actions,
        if (facts.isNotEmpty) GroupedSection(children: facts),
        _names('Tools', entry.providesTools),
        _names('Hooks', entry.providesHooks),
        _names('Middleware', entry.providesMiddleware),
        _names('Environment variables', entry.requiresEnv),
        if (docs != null)
          GroupedSection(
            children: [
              GroupedRow(
                key: const Key('catalog-docs-link'),
                title: 'Documentation',
                chevron: false,
                trailing: AppIcon(
                  AppIcons.openExternal,
                  size: 16,
                  color: context.hermesColors.subtleText,
                ),
                onTap: () => openLink(docs),
              ),
            ],
          ),
      ],
    );
  }

  /// A named list of what the entry provides or needs; nothing when it has
  /// none.
  static Widget _names(String header, List<String> names) => names.isEmpty
      ? const SizedBox.shrink()
      : GroupedSection(
          header: header,
          children: [for (final name in names) GroupedRow(title: name)],
        );
}
