import 'package:flutter/material.dart';

import '../../widgets/app_badge.dart';
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
    return AppBadge.filled(
      label: trustLabel(level),
      fill: switch (level) {
        'builtin' => scheme.primaryContainer,
        'trusted' => scheme.secondaryContainer,
        _ => scheme.surfaceContainerHighest,
      },
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});

  final SkillSource source;

  @override
  Widget build(BuildContext context) => AppBadge.filled(
    label: skillSourceLabel(source),
    fill: Theme.of(context).colorScheme.surfaceContainerHighest,
  );
}
