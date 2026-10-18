import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// Compact legacy background-review label. New review reports are presented
/// by MemoryActivityCard in the inspector and remain bound to their reply.
class ReviewSummaryNote extends StatelessWidget {
  const ReviewSummaryNote({super.key, required this.items});

  /// One entry per change, such as "Memory updated" or "Skill 'x' patched".
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final text = items.join(' · ');
    return Semantics(
      label: 'Background review: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AppIcon(AppIcons.memory, size: 16, color: subtle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 13, color: subtle)),
            ),
          ],
        ),
      ),
    );
  }
}
