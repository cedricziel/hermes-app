import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/disclosure_tile.dart';
import 'memory_recall.dart';

/// Reference activity in the inspector. The current protocol cannot identify
/// the recalled notes, so expansion explains that limit instead of repeating
/// the indicator or presenting a fresh search as the original recall.
class MemoryActivityCard extends StatelessWidget {
  const MemoryActivityCard({
    super.key,
    this.recalls = const [],
    this.reviewNotes = const [],
    this.earlierRecallsOmitted = false,
    this.initiallyOpen = false,
    this.onOpenMemory,
  });

  /// Chronological, oldest first. Only the latest recall is shown collapsed.
  final List<MemoryRecall> recalls;
  final List<String> reviewNotes;
  final bool earlierRecallsOmitted;
  final bool initiallyOpen;

  /// Opens the Memory screen of the chat's profile, offered under the review
  /// notes; null leaves the link out.
  final VoidCallback? onOpenMemory;

  @override
  Widget build(BuildContext context) {
    if (recalls.isEmpty && reviewNotes.isEmpty) return const SizedBox.shrink();
    final latest = recalls.lastOrNull;
    final subtle = context.hermesColors.subtleText;
    String time(MemoryRecall recall) => MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(recall.receivedAt.toLocal()));
    return DisclosureTile(
      key: const Key('memory-activity-card'),
      initiallyExpanded: initiallyOpen,
      title: Row(
        children: [
          AppIcon(AppIcons.memory, size: 20, color: subtle),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Memory & review'),
                Text(
                  latest?.summary ?? 'Background review',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: subtle),
                ),
              ],
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (latest != null) ...[
                Text(
                  'Received at ${time(latest)}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: subtle),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The agent received recalled memory as context. Hermes did not include the note titles or contents in this event.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'The same count can refer to different memories on each turn.',
                ),
              ],
              if (recalls.length > 1) ...[
                const SizedBox(height: 12),
                const Text(
                  'Earlier recalls',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final recall
                    in recalls.take(recalls.length - 1).toList().reversed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${time(recall)} · ${recall.summary}'),
                  ),
              ],
              if (earlierRecallsOmitted)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Earlier recall events omitted.'),
                ),
              if (reviewNotes.isNotEmpty) ...[
                if (latest != null) const SizedBox(height: 16),
                const Text(
                  'Latest background review',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final note in reviewNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(note),
                  ),
                if (onOpenMemory case final open?)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: open,
                      child: const Text('Memory'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
