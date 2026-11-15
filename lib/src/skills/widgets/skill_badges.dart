import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // Official stays the strongest fill, Trusted one step above Community.
    // Trusted's pair lives here: adding secondaryContainer to the schemes
    // would recolour the profile avatars, which use it.
    final (fill, labelColor) = switch (level) {
      'builtin' => (scheme.primary, scheme.onPrimary),
      'trusted' => (
        dark ? HermesColors.zinc700 : HermesColors.zinc200,
        scheme.onSurface,
      ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return AppBadge.filled(
      label: trustLabel(level),
      fill: fill,
      labelColor: labelColor,
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
    labelColor: Theme.of(context).colorScheme.onSurface,
  );
}
