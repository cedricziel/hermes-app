import 'package:flutter/material.dart';

import '../hermes_skills_repository.dart';

String skillSourceLabel(SkillSource source) => switch (source) {
  SkillSource.hub => 'Hub',
  SkillSource.bundled => 'Bundled',
  SkillSource.agent => 'Agent',
};

/// "Official", "Trusted" or "Community".
String trustLabel(String level) => switch (level) {
  'builtin' => 'Official',
  'trusted' => 'Trusted',
  _ => 'Community',
};

class TrustBadge extends StatelessWidget {
  const TrustBadge(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (level) {
      'builtin' => scheme.primaryContainer,
      'trusted' => scheme.secondaryContainer,
      _ => scheme.surfaceContainerHighest,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        trustLabel(level),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});

  final SkillSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        skillSourceLabel(source),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
