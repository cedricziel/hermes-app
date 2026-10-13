import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../moa_progress_state.dart';

class MoaProgressCard extends StatelessWidget {
  const MoaProgressCard({
    super.key,
    required this.progress,
    this.initiallyOpen = false,
    this.onDetails,
  });
  final MoaProgress progress;
  final bool initiallyOpen;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final done = progress.done, total = progress.total;
    final counts = done != null && total != null && done >= 0 && total >= done;
    final fraction =
        done != null && total != null && done >= 0 && total > 0 && done <= total
        ? done / total
        : null;
    return DisclosureTile(
      dense: true,
      initiallyExpanded: initiallyOpen,
      onExpansionChanged: (expanded) {
        if (expanded) onDetails?.call();
      },
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advisor progress · ${progress.live ? progress.phase : 'Finished'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (counts) Text('$done / $total references'),
          if (progress.aggregator != null)
            Text(
              'Aggregator: ${progress.aggregator}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (progress.live && fraction != null)
            LinearProgressIndicator(value: fraction),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!progress.referencesAvailable)
                const Text('Reference details unavailable.')
              else if (progress.references.isEmpty)
                const Text('No reference answers received yet.'),
              if (progress.referencesAvailable)
                for (final reference in progress.references)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reference.label.isEmpty
                              ? 'Advisor reference'
                              : reference.label,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(reference.text),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
