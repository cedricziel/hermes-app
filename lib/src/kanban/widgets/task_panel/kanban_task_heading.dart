import 'package:flutter/material.dart';

/// A section title in the task panel.
class KanbanTaskHeading extends StatelessWidget {
  const KanbanTaskHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
  );
}
