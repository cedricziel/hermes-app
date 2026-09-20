import 'package:flutter/material.dart';

import 'catalog_entry.dart';
import 'plugin_tag.dart';

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

  /// What the user can do with the entry, shown under its facts.
  final Widget? actions;

  /// The docs address as a link, or null when it is not a plain web address.
  static Uri? webAddress(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurfaceVariant;
    final docs = webAddress(entry.docsUrl);
    return SingleChildScrollView(
      key: const Key('catalog-detail'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(entry.name, style: theme.textTheme.titleLarge),
              ),
              if (entry.official) ...[
                const SizedBox(width: 8),
                const PluginTag('Official', filled: true),
              ],
            ],
          ),
          if (entry.maintainer.isNotEmpty)
            Text(
              entry.maintainer,
              style: theme.textTheme.bodySmall?.copyWith(color: subtle),
            ),
          if (entry.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(entry.description),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (entry.commit.isNotEmpty) PluginTag(entry.commit, mono: true),
              if (entry.installed) const PluginTag('Installed', filled: true),
              if (entry.installed && entry.updateAvailable)
                const PluginTag('Update available', strong: true),
            ],
          ),
          if (entry.requiresHermes.isNotEmpty)
            _Line('Requires Hermes ${entry.requiresHermes}'),
          if (entry.platforms.isNotEmpty)
            _Line('Platforms: ${entry.platforms.join(', ')}'),
          _Group('Tools', entry.providesTools),
          _Group('Hooks', entry.providesHooks),
          _Group('Middleware', entry.providesMiddleware),
          _Group('Environment variables', entry.requiresEnv),
          if (docs != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('catalog-docs-link'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Documentation'),
                onPressed: () => openLink(docs),
              ),
            ),
          ?actions,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// A named list of what an entry provides or needs; nothing when it has none.
class _Group extends StatelessWidget {
  const _Group(this.title, this.names);

  final String title;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final name in names) PluginTag(name, mono: true)],
          ),
        ],
      ),
    );
  }
}
