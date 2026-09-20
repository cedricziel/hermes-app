import 'package:flutter/material.dart';

import 'installed_plugin.dart';

/// A small outlined label on a plugin row.
class PluginTag extends StatelessWidget {
  const PluginTag(
    this.text, {
    super.key,
    this.strong = false,
    this.filled = false,
    this.mono = false,
  });

  final String text;

  /// Drawn in the text colour instead of the muted one.
  final bool strong;

  /// Drawn as a solid pill.
  final bool filled;

  /// Set in a monospaced font, for a commit.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = filled
        ? scheme.onPrimary
        : strong
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : null,
        border: Border.all(
          color: filled
              ? scheme.primary
              : strong
              ? scheme.onSurface
              : scheme.outline,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}

/// A plugin's status as the chip on its row: Enabled, Disabled or Inactive.
class PluginStatusChip extends StatelessWidget {
  const PluginStatusChip(this.status, {super.key});

  final PluginStatus status;

  @override
  Widget build(BuildContext context) => PluginTag(switch (status) {
    PluginStatus.enabled => 'Enabled',
    PluginStatus.disabled => 'Disabled',
    PluginStatus.inactive => 'Inactive',
  }, filled: status == PluginStatus.enabled);
}
