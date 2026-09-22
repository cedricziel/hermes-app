import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// A small pill for a fact about a server: its transport, how it signs in, its
/// state.
class McpChip extends StatelessWidget {
  const McpChip(this.label, {super.key, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = context.hermesColors.warning;
    final color = warning ? warn : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: warning
            ? warn.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: warning
              ? warn.withValues(alpha: 0.4)
              : theme.colorScheme.onSurface.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
