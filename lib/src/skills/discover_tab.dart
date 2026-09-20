import 'package:flutter/material.dart';

import 'hermes_skills_hub_repository.dart';
import 'skills_hub_controller.dart';

/// Featured and official skills, or the results of a hub search, with a chip
/// per source and a trust badge on every card.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.hub, required this.onOpen});

  final SkillsHubController hub;
  final ValueChanged<HubSkill> onOpen;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final hub = widget.hub;
        switch (hub.status) {
          case HubStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case HubStatus.unsupported:
            return const _Note(
              'The connected Hermes does not support the skills hub.',
            );
          case HubStatus.failed:
            return _Note(
              'Could not load the hub',
              action: FilledButton(
                onPressed: hub.load,
                child: const Text('Retry'),
              ),
            );
          case HubStatus.ready:
            break;
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: hub.setQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search the skills hub',
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (hub.sources.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (id, label) in [
                      (SkillsHubController.allSources, 'All'),
                      for (final s in hub.sources) (s.id, s.label),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: hub.source == id,
                          onSelected: (_) => hub.setSource(id),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(child: _list(context, hub)),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, SkillsHubController hub) {
    if (hub.isSearch) {
      if (hub.searchFailed) {
        return _Note(
          'Could not search the hub',
          action: FilledButton(
            onPressed: hub.retrySearch,
            child: const Text('Retry'),
          ),
        );
      }
      if (hub.searching && hub.results.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (hub.results.isEmpty) const _Note('No skills found.'),
          for (final s in hub.results) _card(hub, s),
          if (hub.timedOut.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: Text(
                '${hub.timedOut.length} source'
                '${hub.timedOut.length == 1 ? '' : 's'} timed out',
              ),
              trailing: TextButton(
                onPressed: hub.retrySearch,
                child: const Text('Retry'),
              ),
            ),
        ],
      );
    }
    final featured = hub.featured;
    final official = hub.official;
    if (featured.isEmpty && official.isEmpty) {
      return const _Note('No skills to show.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (featured.isNotEmpty) ...[
          const _Header('Featured'),
          for (final s in featured) _card(hub, s),
        ],
        if (official.isNotEmpty) ...[
          const _Header('Official'),
          for (final s in official) _card(hub, s),
        ],
      ],
    );
  }

  Widget _card(SkillsHubController hub, HubSkill skill) {
    final installed = hub.isInstalled(skill);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('hub-${skill.identifier}'),
      onTap: () => widget.onOpen(skill),
      title: Text(
        skill.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (skill.description.isNotEmpty)
            Text(
              skill.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TrustBadge(skill.trustLevel),
              for (final tag in skill.tags.take(3))
                Text('#$tag', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
      trailing: installed
          ? Icon(Icons.check_circle_outline, color: scheme.primary)
          : const Icon(Icons.chevron_right),
    );
  }
}

class TrustBadge extends StatelessWidget {
  const TrustBadge(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (level) {
      'builtin' => ('Official', scheme.primaryContainer),
      'trusted' => ('Trusted', scheme.secondaryContainer),
      _ => ('Community', scheme.surfaceContainerHighest),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
