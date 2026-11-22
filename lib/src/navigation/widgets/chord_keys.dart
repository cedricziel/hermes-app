import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../keyboard_shortcut_models.dart';

/// The key combinations of a command as small key caps, with "or" between
/// combinations that do the same.
class ChordKeys extends StatelessWidget {
  const ChordKeys({super.key, required this.chords});

  final List<ShortcutChord> chords;

  @override
  Widget build(BuildContext context) {
    final muted = context.hermesColors.subtleText;
    final or = context.l10n.navigationKeyboardShortcutsOr;
    return Semantics(
      label: chords.map((chord) => chord.text).join(' $or '),
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (index, chord) in chords.indexed) ...[
            if (index > 0)
              Text(
                or,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: muted),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [for (final key in chord.keys) _KeyCap(label: key)],
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
